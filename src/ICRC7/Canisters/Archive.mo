import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Option "mo:base/Option";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import ExperimentalStableMemory "mo:base/ExperimentalStableMemory";

import Itertools "mo:itertools/Iter";
import StableTrieMap "mo:StableTrieMap";

import ArchiveTypes "../types/ArchiveTypes";
import Value "../Value";
import U "../Utils";

shared ({ caller = init_caller }) actor class Archive() : async ArchiveTypes.ArchiveFullInterface = this {

    type MemoryBlock = {
        offset : Nat64;
        size : Nat;
    };

    stable let ledger_canister_id = init_caller;

    stable let KiB = 1024;
    stable let GiB = KiB ** 3;
    stable let MEMORY_PER_PAGE : Nat64 = Nat64.fromNat(64 * KiB);
    stable let MIN_PAGES : Nat64 = 32; // 2MiB == 32 * 64KiB
    stable var PAGES_TO_GROW : Nat64 = 2048; // 64MiB
    stable let MAX_MEMORY = 32 * GiB;

    stable let BUCKET_SIZE = 1000;
    stable let MAX_TRANSACTIONS_PER_REQUEST = 5000;

    stable var memory_pages : Nat64 = ExperimentalStableMemory.size();
    stable var total_memory_used : Nat64 = 0;

    stable var filled_buckets = 0;
    stable var trailing_txs = 0;

    stable let txStore = StableTrieMap.new<Nat, [MemoryBlock]>();

    public shared ({ caller }) func append_transactions(txs : [ArchiveTypes.Transaction]) : async Result.Result<(), Text> {

        if (caller != ledger_canister_id) {
            return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
        };

        let last_tx_index = get_last_tx_index();

        let filtered_txs = Array.filter<ArchiveTypes.Transaction>(txs, func tx = Option.get(Value.to_nat(Value.get_from_map_with_default(tx, "index", #Nat(0))), 0) > last_tx_index);
        var txs_iter = filtered_txs.vals();

        if (trailing_txs > 0) {
            let last_bucket = StableTrieMap.get(
                txStore,
                Nat.equal,
                U.hash,
                filled_buckets,
            );

            switch (last_bucket) {
                case (?last_bucket) {
                    let new_bucket = Iter.toArray(
                        Itertools.take(
                            Itertools.chain(
                                last_bucket.vals(),
                                Iter.map(filtered_txs.vals(), store_tx),
                            ),
                            BUCKET_SIZE,
                        )
                    );

                    if (new_bucket.size() == BUCKET_SIZE) {
                        let offset = (BUCKET_SIZE - last_bucket.size()) : Nat;

                        txs_iter := Itertools.fromArraySlice(filtered_txs, offset, filtered_txs.size());
                    } else {
                        txs_iter := Itertools.empty();
                    };

                    store_bucket(new_bucket);
                };
                case (_) {};
            };
        };

        for (chunk in Itertools.chunks(txs_iter, BUCKET_SIZE)) {
            store_bucket(Array.map(chunk, store_tx));
        };

        #ok();
    };

    func get_last_tx_index() : Int {
        if (total_txs() == 0) return -1;

        let bucket_index = if (trailing_txs > 0) filled_buckets else Nat.max(filled_buckets - 1, 0);
        let last_bucket_opt = StableTrieMap.get(
            txStore,
            Nat.equal,
            U.hash,
            bucket_index,
        );

        let last_bucket = switch (last_bucket_opt) {
            case (?last_bucket) last_bucket;
            case (null) Debug.trap("Unexpected Error: Last Bucket not found");
        };

        if (last_bucket.size() == 0) Debug.trap("Unexpected Error: Last Bucket is not filled");

        Option.get(Value.to_nat(Value.get_from_map_with_default(get_tx(last_bucket[last_bucket.size() - 1]), "index", #Nat(0))), 0);
    };

    func total_txs() : Nat {
        (filled_buckets * BUCKET_SIZE) + trailing_txs;
    };

    public query func total_transactions() : async Nat {
        total_txs();
    };

    public query func get_transaction(tx_index : ArchiveTypes.TxIndex) : async ?ArchiveTypes.Transaction {
        let bucket_key = tx_index / BUCKET_SIZE;

        let opt_bucket = StableTrieMap.get(
            txStore,
            Nat.equal,
            U.hash,
            bucket_key,
        );

        switch (opt_bucket) {
            case (?bucket) {
                let i = tx_index % BUCKET_SIZE;
                if (i < bucket.size()) {
                    ?get_tx(bucket[tx_index % BUCKET_SIZE]);
                } else {
                    null;
                };
            };
            case (_) {
                null;
            };
        };
    };

    public query func get_transactions(req : ArchiveTypes.GetTransactionsRequest) : async ArchiveTypes.TransactionRange {
        let { start; length } = req;
        var iter = Itertools.empty<MemoryBlock>();

        let end = start + length;
        let start_bucket = start / BUCKET_SIZE;
        let end_bucket = (Nat.min(end, total_txs()) / BUCKET_SIZE) + 1;

        label _loop for (i in Itertools.range(start_bucket, end_bucket)) {
            let opt_bucket = StableTrieMap.get(
                txStore,
                Nat.equal,
                U.hash,
                i,
            );

            switch (opt_bucket) {
                case (?bucket) {
                    if (i == start_bucket) {
                        iter := Itertools.fromArraySlice(bucket, start % BUCKET_SIZE, Nat.min(bucket.size(), (start % BUCKET_SIZE) +length));
                    } else if (i + 1 == end_bucket) {
                        let bucket_iter = Itertools.fromArraySlice(bucket, 0, end % BUCKET_SIZE);
                        iter := Itertools.chain(iter, bucket_iter);
                    } else {
                        iter := Itertools.chain(iter, bucket.vals());
                    };
                };
                case (_) { break _loop };
            };
        };

        let transactions = Iter.toArray(
            Iter.map(
                Itertools.take(iter, MAX_TRANSACTIONS_PER_REQUEST),
                get_tx,
            )
        );

        { transactions };
    };

    public query func remaining_capacity() : async Nat {
        MAX_MEMORY - Nat64.toNat(total_memory_used);
    };

    public query func icrc3_get_blocks(args : ArchiveTypes.GetBlocksArgs) : async ArchiveTypes.GetBlocksResult {
        var iter = Itertools.empty<MemoryBlock>();

        for ({ start; length } in args.vals()) {
            let end = start + length;
            let start_bucket = start / BUCKET_SIZE;
            let end_bucket = (Nat.min(end, total_txs()) / BUCKET_SIZE) + 1;

            label _loop for (i in Itertools.range(start_bucket, end_bucket)) {
                let opt_bucket = StableTrieMap.get(
                    txStore,
                    Nat.equal,
                    U.hash,
                    i,
                );

                switch (opt_bucket) {
                    case (?bucket) {
                        if (i == start_bucket) {
                            iter := Itertools.fromArraySlice(bucket, start % BUCKET_SIZE, Nat.min(bucket.size(), (start % BUCKET_SIZE) +length));
                        } else if (i + 1 == end_bucket) {
                            let bucket_iter = Itertools.fromArraySlice(bucket, 0, end % BUCKET_SIZE);
                            iter := Itertools.chain(iter, bucket_iter);
                        } else {
                            iter := Itertools.chain(iter, bucket.vals());
                        };
                    };
                    case (_) { break _loop };
                };
            };
        };

        let blocks = Iter.toArray(
            Iter.map(
                Itertools.take(iter, MAX_TRANSACTIONS_PER_REQUEST),
                get_tx_with_id,
            )
        );

        return {
            log_length = total_txs();
            blocks;
            archived_blocks = [];
        };
    };

    func to_blob(tx : ArchiveTypes.Transaction) : Blob {
        to_candid (tx);
    };

    func from_blob(tx : Blob) : ArchiveTypes.Transaction {
        switch (from_candid (tx) : ?ArchiveTypes.Transaction) {
            case (?tx) tx;
            case (_) Debug.trap("Could not decode tx blob");
        };
    };

    func store_tx(tx : ArchiveTypes.Transaction) : MemoryBlock {
        let blob = to_blob(tx);

        if ((memory_pages * MEMORY_PER_PAGE) - total_memory_used < (MIN_PAGES * MEMORY_PER_PAGE)) {
            ignore ExperimentalStableMemory.grow(PAGES_TO_GROW);
            memory_pages += PAGES_TO_GROW;
        };

        let offset = total_memory_used;

        ExperimentalStableMemory.storeBlob(
            offset,
            blob,
        );

        let mem_block = {
            offset;
            size = blob.size();
        };

        total_memory_used += Nat64.fromNat(blob.size());
        mem_block;
    };

    func get_tx({ offset; size } : MemoryBlock) : ArchiveTypes.Transaction {
        let blob = ExperimentalStableMemory.loadBlob(offset, size);

        let tx = from_blob(blob);
    };

    func get_tx_with_id({ offset; size } : MemoryBlock) : {
        id : Nat;
        block : ArchiveTypes.Transaction;
    } {
        let blob = ExperimentalStableMemory.loadBlob(offset, size);

        let block = from_blob(blob);
        let id : Nat = Option.get(Value.to_nat(Value.get_from_map_with_default(block, "index", #Nat(0))), 0);
        { id; block };
    };

    func store_bucket(bucket : [MemoryBlock]) {

        StableTrieMap.put(
            txStore,
            Nat.equal,
            U.hash,
            filled_buckets,
            bucket,
        );

        if (bucket.size() == BUCKET_SIZE) {
            filled_buckets += 1;
            trailing_txs := 0;
        } else {
            trailing_txs := bucket.size();
        };
    };

    public query ({ caller }) func query_cycle_balance() : async Nat {
        ExperimentalCycles.balance();
    };
};
