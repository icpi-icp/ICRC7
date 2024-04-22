import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import EC "mo:base/ExperimentalCycles";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Text "mo:base/Text";
import CertifiedData "mo:base/CertifiedData";
import ExperimentalCycles "mo:base/ExperimentalCycles";

import StableTrieMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";

import RepIndy "mo:rep-indy-hash";
import CertTree "mo:cert/CertTree";
import MTree "mo:cert/MerkleTree";

import Value "Value";
import Utils "Utils";
import Account "Account";
import Transfer "Transfer";
import IC0Utils "IC0Utils";
import TokenTypes "types/TokenTypes";
import FileTypes "types/FileTypes";
import File "Canisters/File";
import Archive "Canisters/Archive";

/// The ICRC7 class with all the functions for creating an
/// ICRC7 token on the Internet Computer
module {
    let { SB } = Utils;

    public type Value = TokenTypes.Value;

    public type Account = TokenTypes.Account;
    public type AccountBalances = TokenTypes.AccountBalances;

    public type Balance = TokenTypes.Balance;
    public type TransferArg = TokenTypes.TransferArg;
    public type MintArg = TokenTypes.MintArg;
    public type BurnArg = TokenTypes.BurnArg;

    public type SupportedStandard = TokenTypes.SupportedStandard;

    public type InitArgs = TokenTypes.InitArgs;
    public type TokenInitArgs = TokenTypes.TokenInitArgs;
    public type TokenData = TokenTypes.TokenData;
    public type MetaDatum = TokenTypes.MetaDatum;
    public type MetaData = TokenTypes.MetaData;
    public type TxIndex = TokenTypes.TxIndex;

    public type LedgerFullInterface = TokenTypes.LedgerFullInterface;

    public type GetTransactionsRequest = TokenTypes.GetTransactionsRequest;
    public type GetTransactionsResponse = TokenTypes.GetTransactionsResponse;
    public type ArchivedTransaction = TokenTypes.ArchivedTransaction;
    public type GetArchivesArgs = TokenTypes.GetArchivesArgs;
    public type GetArchivesResult = TokenTypes.GetArchivesResult;
    public type GetBlocksArgs = TokenTypes.GetBlocksArgs;
    public type GetBlocksResult = TokenTypes.GetBlocksResult;
    public type DataCertificate = TokenTypes.DataCertificate;
    public type BlockType = TokenTypes.BlockType;

    public type TransferResult = TokenTypes.TransferResult;

    public type Chunk = FileTypes.Chunk;
    public type CommitBatchArg = FileTypes.CommitBatchArg;
    public type HttpRequest = FileTypes.HttpRequest;
    public type HttpResponse = FileTypes.HttpResponse;

    public let MAX_TRANSACTIONS_IN_LEDGER = 2000;
    public let MAX_TRANSACTIONS_IN_ARCHIVE = 1000000;
    public let DEPLOY_CANISTER_CYCLE = 1_860_000_000_000;

    /// Initialize a new ICRC-7 token
    public func init(args : TokenTypes.InitArgs) : TokenTypes.TokenData {
        let {
            name;
            symbol;
            logo;
            description;
            minting_account;
            supply_cap;
            advanced_settings;
            deploy_canister_cycle;
        } = args;

        var _burned_tokens = 0;
        var _minted_tokens = 0;
        var permitted_drift = 60_000_000_000;
        var tx_window = 86_400_000_000_000;
        var max_query_batch_size = 1000;
        var max_update_batch_size = 1000;
        var default_take_value = 1000;
        var max_take_value = 1000;
        var max_memo_size = 32;
        var atomic_batch_transfers = false;

        switch (advanced_settings) {
            case (?settings) {
                permitted_drift := Nat64.toNat(Option.get(settings.permitted_drift, 60_000_000_000 : Nat64));
                tx_window := Nat64.toNat(Option.get(settings.tx_window, 86_400_000_000_000 : Nat64));
                max_query_batch_size := Option.get(settings.max_query_batch_size, 1000);
                max_update_batch_size := Option.get(settings.max_update_batch_size, 1000);
                default_take_value := Option.get(settings.default_take_value, 1000);
                max_take_value := Option.get(settings.max_take_value, 1000);
                max_memo_size := Option.get(settings.max_memo_size, 32);
                atomic_batch_transfers := Option.get(settings.atomic_batch_transfers, false);
            };
            case (null) {};
        };

        if (not Account.validate(minting_account)) {
            Debug.trap("minting_account is invalid");
        };

        let account_balances : TokenTypes.AccountBalances = StableTrieMap.new();
        let metadatas : TokenTypes.MetadataMap = StableTrieMap.new();
        let holders : TokenTypes.Holders = StableTrieMap.new();
        var archive : TokenTypes.ArchiveData = {
            var canister = actor ("aaaaa-aa");
            var stored_txs = 0;
            var start = 0;
            var end = 0;
        };

        {
            name = name;
            symbol = symbol;
            logo = logo;
            description = description;
            supply_cap;
            var _minted_tokens = _minted_tokens;
            var _burned_tokens = _burned_tokens;
            minting_account;
            metadata = Utils.init_metadata(args);
            var max_query_batch_size;
            var max_update_batch_size;
            var default_take_value;
            var max_take_value;
            var max_memo_size;
            var atomic_batch_transfers;
            var tx_window;
            var permitted_drift;

            supported_standards = Utils.init_standards();
            metadatas;
            var last_token_id = 0;
            holders;
            account_balances;
            transactions = SB.initPresized(MAX_TRANSACTIONS_IN_LEDGER);
            var archive;
            var archives = [];
            var file_canister_id = null;
            var last_tx = null;
            var cert_store = CertTree.newStore();
            var deploy_canister_cycle;
        };
    };

    /// Retrieve the name of the token
    public func name(token : TokenTypes.TokenData) : Text {
        token.name;
    };

    /// Retrieve the symbol of the token
    public func symbol(token : TokenTypes.TokenData) : Text {
        token.symbol;
    };

    public func description(token : TokenTypes.TokenData) : ?Text {
        ?token.description;
    };

    public func logo(token : TokenTypes.TokenData) : ?Text {
        ?token.logo;
    };

    public func supply_cap(token : TokenTypes.TokenData) : TokenTypes.Balance {
        token.supply_cap;
    };

    /// Returns the total supply of circulating tokens
    public func total_supply(token : TokenTypes.TokenData) : TokenTypes.Balance {
        token._minted_tokens - token._burned_tokens;
    };

    /// Returns the total supply of minted tokens
    public func minted_supply(token : TokenTypes.TokenData) : TokenTypes.Balance {
        token._minted_tokens;
    };

    /// Returns the total supply of burned tokens
    public func burned_supply(token : TokenTypes.TokenData) : TokenTypes.Balance {
        token._burned_tokens;
    };

    public func minting_account(token : TokenTypes.TokenData) : TokenTypes.Account {
        token.minting_account;
    };

    /// Retrieve all the metadata of the token
    public func metadata(token : TokenTypes.TokenData) : [TokenTypes.MetaDatum] {
        SB.toArray(token.metadata);
    };

    public func max_query_batch_size(token : TokenTypes.TokenData) : Nat {
        token.max_query_batch_size;
    };
    public func max_update_batch_size(token : TokenTypes.TokenData) : Nat {
        token.max_update_batch_size;
    };
    public func default_take_value(token : TokenTypes.TokenData) : Nat {
        token.default_take_value;
    };
    public func max_take_value(token : TokenTypes.TokenData) : Nat {
        token.max_take_value;
    };
    public func max_memo_size(token : TokenTypes.TokenData) : Nat {
        token.max_memo_size;
    };
    public func atomic_batch_transfers(token : TokenTypes.TokenData) : Bool {
        token.atomic_batch_transfers;
    };
    public func tx_window(token : TokenTypes.TokenData) : Nat {
        token.tx_window;
    };
    public func permitted_drift(token : TokenTypes.TokenData) : Nat {
        token.permitted_drift;
    };

    /// Returns an array of standards supported by this token
    public func supported_standards(token : TokenTypes.TokenData) : [TokenTypes.SupportedStandard] {
        SB.toArray(token.supported_standards);
    };

    public func token_metadata(token : TokenTypes.TokenData, token_ids : [Nat]) : [?TokenTypes.MetaData] {
        let buffer = Buffer.Buffer<?TokenTypes.MetaData>(token_ids.size());
        for (token_id in token_ids.vals()) {
            let metadata = Utils.get_metadata(token.metadatas, token_id);
            buffer.add(metadata);
        };
        Buffer.toArray(buffer);
    };

    public func owner_of(token : TokenTypes.TokenData, token_ids : [Nat]) : [?TokenTypes.Account] {
        let buffer = Buffer.Buffer<?TokenTypes.Account>(token_ids.size());
        for (token_id in token_ids.vals()) {
            let account = Utils.get_owner(token.holders, token_id);
            buffer.add(account);
        };
        Buffer.toArray(buffer);
    };

    /// Retrieve the balance of a given account
    public func balance_of({ account_balances } : TokenTypes.TokenData, accounts : [TokenTypes.Account]) : [TokenTypes.Balance] {
        let buffer = Buffer.Buffer<Balance>(accounts.size());
        for (account in accounts.vals()) {
            let encoded_account = Account.encode(account);
            let balance = Utils.get_balance(account_balances, encoded_account);
            buffer.add(balance.tokens.size());
        };
        Buffer.toArray(buffer);
    };

    public func tokens(token : TokenTypes.TokenData, prev : ?Nat, take : ?Nat) : [Nat] {
        let _prev = Option.get(prev, 0);
        var _take = Option.get(take, token.default_take_value);
        let metadata_size = StableTrieMap.size(token.metadatas);
        if (metadata_size < _take) {
            _take := metadata_size;
        };
        if (_take > token.max_take_value) {
            _take := token.max_take_value;
        };
        var token_id_array = Iter.toArray(StableTrieMap.keys(token.metadatas));

        token_id_array := Array.sort(token_id_array, Nat.compare);

        Array.subArray(token_id_array, _prev, _take);
    };

    public func tokens_of(token : TokenTypes.TokenData, owner : TokenTypes.Account, prev : ?Nat, take : ?Nat) : [Nat] {
        let _prev = Option.get(prev, 0);
        var _take = Option.get(take, token.default_take_value);

        let request_owner = Account.encode(owner);

        let owner_tokens = Array.filter<(Nat, TokenTypes.EncodedAccount)>(
            Iter.toArray(StableTrieMap.entries(token.holders)),
            func(token_id, encoded_account) = encoded_account == request_owner,
        );
        let buffer = Buffer.Buffer<Nat>(owner_tokens.size());
        if (owner_tokens.size() < _take) {
            _take := owner_tokens.size();
        };
        if (_take > token.max_take_value) {
            _take := token.max_take_value;
        };
        for ((token_id, encoded_account) in owner_tokens.vals()) {
            buffer.add(token_id);
        };
        let token_id_array = Array.sort(Buffer.toArray(buffer), Nat.compare);
        Array.subArray(token_id_array, _prev, _take);
    };

    public func transfer(
        token : TokenTypes.TokenData,
        args : [TokenTypes.TransferArg],
        caller : Principal,
    ) : async* [?TokenTypes.TransferResult] {
        let buffer = Buffer.Buffer<TokenTypes.TransferArgs>(args.size());
        for (arg in args.vals()) {
            let transfer_args : TokenTypes.TransferArgs = {
                arg with metadata = null;
            };
            buffer.add(transfer_args);
        };
        await* transfer_to(token, Buffer.toArray(buffer), caller);
    };

    /// Helper function to mint tokens with minimum args
    public func mint(token : TokenTypes.TokenData, args : TokenTypes.MintArg, caller : Principal) : async* [?TokenTypes.TransferResult] {

        if (caller != token.minting_account.owner) {
            throw Error.reject("Unauthorized: Only the minting_account can mint tokens.");
        };

        var _token_id = 0;

        switch (args.token_id) {
            case (?token_id) {
                _token_id := token_id;
            };
            case (_) {
                _token_id := token.last_token_id + 1;
            };
        };

        let transfer_args : TokenTypes.TransferArgs = {
            args with from_subaccount = token.minting_account.subaccount;
            token_id = _token_id;
            metadata = ?args.metadata;
        };

        if (token.supply_cap < transfer_args.token_id) {
            throw Error.reject("Warning: Token supply cap reached.");
        };

        await* transfer_to(token, [transfer_args], caller);
    };

    /// Helper function to burn tokens with minimum args
    public func burn(token : TokenTypes.TokenData, args : TokenTypes.BurnArg, caller : Principal) : async* [?TokenTypes.TransferResult] {

        let transfer_args : TokenTypes.TransferArgs = {
            args with to = token.minting_account;
            metadata = null;
        };

        await* transfer_to(token, [transfer_args], caller);
    };

    /// Transfers tokens from one account to another account (minting and burning included)
    private func transfer_to(
        token : TokenTypes.TokenData,
        args : [TokenTypes.TransferArgs],
        caller : Principal,
    ) : async* [?TokenTypes.TransferResult] {
        let buffer = Buffer.Buffer<Value>(args.size());
        let result_buffer = Buffer.Buffer<?TokenTypes.TransferResult>(args.size());
        var index_increment = 0;
        label arg_iter for (arg in args.vals()) {
            let from = {
                owner = caller;
                subaccount = arg.from_subaccount;
            };

            let tx_kind = if (from == token.minting_account) {
                #mint;
            } else if (arg.to == token.minting_account) {
                #burn;
            } else {
                #transfer;
            };

            let tx_req = Utils.create_transfer_req(arg, caller, tx_kind);

            switch (Transfer.validate_request(token, tx_req)) {
                case (#err(errorType)) {
                    result_buffer.add(? #Err(errorType));
                    if (token.atomic_batch_transfers) {
                        throw Error.reject("Batch processing exception");
                    };
                    continue arg_iter;
                };
                case (#ok(_)) {};
            };

            let { encoded; token_id } = tx_req;

            // process transaction
            switch (tx_req.kind) {
                case (#mint) {
                    Utils.mint_balance(token, encoded.to, token_id, arg.metadata);
                };
                case (#burn) {
                    Utils.burn_balance(token, encoded.from, token_id);
                };
                case (#transfer) {
                    Utils.transfer_balance(token, tx_req);
                };
            };
            // store transaction
            let index = total_transactions(token) + index_increment;
            index_increment += 1;
            var latest_hash = Blob.fromArray([]);
            if (index > 0) {
                let parent_tx = Option.get(token.last_tx, #Blob(Blob.fromArray([])));
                latest_hash := Blob.fromArray(RepIndy.hash_val(parent_tx));
            };
            let tx = Utils.req_to_value(tx_req, index, token);
            buffer.add(tx);
            token.last_tx := ?tx;
            result_buffer.add(? #Ok(index));

            let cert_store = CertTree.Ops(token.cert_store);
            cert_store.put([Text.encodeUtf8("last_block_index")], encodeBigEndian(index));
            cert_store.put([Text.encodeUtf8("last_block_hash")], latest_hash);
            cert_store.setCertifiedData();
        };

        for (tx in buffer.vals()) {
            SB.add(token.transactions, tx);
        };

        // transfer transaction to archive if necessary
        await* update_canister(token);

        Buffer.toArray(result_buffer);
    };

    private func encodeBigEndian(nat : Nat) : Blob {
        var tempNat = nat;
        var bitCount = 0;
        while (tempNat > 0) {
            bitCount += 1;
            tempNat /= 2;
        };
        let byteCount = (bitCount + 7) / 8;
        let buffer = Buffer.Buffer<Nat8>(byteCount);
        // var buffer = Vec.init<Nat8>(byteCount, 0);
        for (i in Iter.range(0, byteCount -1)) {
            let byteValue = Nat.div(nat, Nat.pow(256, i)) % 256;
            buffer.add(Nat8.fromNat(byteValue));
        };
        return Blob.fromArray(Array.reverse(Buffer.toArray(buffer)));
    };

    public func total_transactions(token : TokenTypes.TokenData) : Nat {
        let { transactions } = token;
        var txs_size = 0;
        for (archive in token.archives.vals()) {
            txs_size += archive.stored_txs;
        };
        txs_size + token.archive.stored_txs + SB.size(transactions);
    };

    public func get_transaction(token : TokenTypes.TokenData, tx_index : TokenTypes.TxIndex) : async* ?TokenTypes.Value {
        if (tx_index < token.archive.stored_txs) {
            let tmp_archives = Array.append(token.archives, [token.archive]);
            for (archive in tmp_archives.vals()) {
                if (tx_index >= archive.start and tx_index <= archive.end) {
                    return await token.archive.canister.get_transaction(tx_index);
                };
            };
            return null;
        } else {
            let local_tx_index = (tx_index - token.archive.stored_txs) : Nat;
            SB.getOpt(token.transactions, local_tx_index);
        };
    };

    public func get_transactions(token : TokenTypes.TokenData, req : TokenTypes.GetTransactionsRequest) : TokenTypes.GetTransactionsResponse {
        let { transactions } = token;

        var first_index = 0;
        if (SB.size(transactions) != 0) {
            first_index := Option.get(Value.to_nat(Value.get_from_map_with_default(SB.slice(transactions, 0, 1)[0], "index", #Nat(0))), 0);
        };

        let req_end = req.start + req.length;

        var txs_in_canister : [TokenTypes.Value] = [];

        if (req_end > first_index) {
            let tx_start_index = (Nat.max(req.start, total_transactions(token) - SB.size(transactions)) - (total_transactions(token) - SB.size(transactions))) : Nat;
            txs_in_canister := SB.slice(transactions, tx_start_index, tx_start_index + req.length);
        };
        var req_length = req.length;
        if (req.length > txs_in_canister.size()) {
            req_length := req.length - txs_in_canister.size();
        };

        let archive_txs = Buffer.Buffer<TokenTypes.ArchivedTransaction>(token.archives.size());
        let tmp_archives = Array.append(token.archives, [token.archive]);
        var first_archive = true;
        var tmp_archives_length = 0;
        for (archive in tmp_archives.vals()) {
            var start = 0;
            var end = 0;
            if (tmp_archives_length < req_length) {
                if (first_archive) {
                    if (req.start <= archive.end) {
                        start := req.start - archive.start;
                        end := Nat.min(archive.end - archive.start + 1, req_length - tmp_archives_length) - start;
                        first_archive := false;
                    };
                } else {
                    if (req.start < archive.start or req_length <= archive.end) {
                        end := Nat.min(archive.end - archive.start + 1, req_length - tmp_archives_length) - start;
                    };
                };
                tmp_archives_length += end;
                if (start != 0 or end != 0) {
                    let callback = archive.canister.get_transactions;
                    archive_txs.add({ start; length = end; callback });
                };
            };
        };
        {
            log_length = total_transactions(token);
            first_index;
            transactions = txs_in_canister;
            archived_transactions = Buffer.toArray(archive_txs);
        };

    };

    public func get_blocks(token : TokenTypes.TokenData, req : TokenTypes.GetBlocksArgs) : TokenTypes.GetBlocksResult {
        let { transactions } = token;
        var first_index = 0;
        if (SB.size(transactions) != 0) {
            first_index := Option.get(Value.to_nat(Value.get_from_map_with_default(SB.slice(transactions, 0, 1)[0], "index", #Nat(0))), 0);
        };

        let archive_txs = Buffer.Buffer<{ args : GetBlocksArgs; callback : query (GetBlocksArgs) -> async GetBlocksResult }>(token.archives.size());
        let ledger_txs = Buffer.Buffer<{ id : Nat; block : Value }>(0);
        for (request in req.vals()) {
            let req_end = request.start + request.length;
            var txs_in_canister : [TokenTypes.Value] = [];

            if (req_end > first_index) {
                let tx_start_index = (Nat.max(request.start, total_transactions(token) - SB.size(transactions)) - (total_transactions(token) - SB.size(transactions))) : Nat;
                txs_in_canister := SB.slice(transactions, tx_start_index, tx_start_index + request.length);
                for (tx in txs_in_canister.vals()) {
                    let id : Nat = Option.get(Value.to_nat(Value.get_from_map_with_default(tx, "index", #Nat(0))), 0);
                    ledger_txs.add({ id; block = tx });
                };
            };

            var req_length = request.length - txs_in_canister.size();
            let tmp_archives = Array.append(token.archives, [token.archive]);
            var first_archive = true;
            var tmp_archives_length = 0;
            for (archive in tmp_archives.vals()) {
                var start = 0;
                var end = 0;
                if (tmp_archives_length < req_length) {
                    if (first_archive) {
                        if (request.start <= archive.end) {
                            start := request.start - archive.start;
                            end := Nat.min(archive.end - archive.start + 1, req_length - tmp_archives_length) - start;
                            first_archive := false;
                        };
                    } else {
                        if (request.start < archive.start or req_length <= archive.end) {
                            end := Nat.min(archive.end - archive.start + 1, req_length - tmp_archives_length) - start;
                        };
                    };
                    tmp_archives_length += end;
                    if (start != 0 or end != 0) {
                        let callback = archive.canister.icrc3_get_blocks;
                        archive_txs.add({
                            args = [{ start; length = end }];
                            callback;
                        });
                    };
                };
            };
        };

        {
            log_length = total_transactions(token);
            blocks = Buffer.toArray(ledger_txs);
            archived_blocks = Buffer.toArray(archive_txs);
        };

    };

    public func get_tip_certificate(token : TokenTypes.TokenData) : ?TokenTypes.DataCertificate {
        let ct = CertTree.Ops(token.cert_store);
        let blockWitness = ct.reveal([Text.encodeUtf8("last_block_index")]);
        let hashWitness = ct.reveal([Text.encodeUtf8("last_block_hash")]);
        let merge = MTree.merge(blockWitness, hashWitness);
        let witness = ct.encodeWitness(merge);
        return ?{
            certificate = switch (CertifiedData.getCertificate()) {
                case (null) {
                    return null;
                };
                case (?val) val;
            };
            hash_tree = witness;
        };
    };

    public func get_file_canister(token : TokenTypes.TokenData) : async Principal {
        await get_file_canister_id(token);
    };

    public func get_archives(token : TokenTypes.TokenData, args : TokenTypes.GetArchivesArgs) : TokenTypes.GetArchivesResult {
        let buffer = Buffer.Buffer<{ canister_id : Principal; start : Nat; end : Nat }>(token.archives.size());
        var archive_from_some_one = Option.isSome(args.from);
        let archives = Array.append(token.archives, [token.archive]);
        var allow_return = false;
        if (not archive_from_some_one) {
            allow_return := true;
        };
        for (archive in archives.vals()) {
            let archive_id = Principal.fromActor(archive.canister);
            if (archive_from_some_one and archive_id == Option.unwrap(args.from)) {
                allow_return := true;
            };
            if (allow_return) {
                buffer.add({
                    canister_id = archive_id;
                    start = archive.start;
                    end = archive.end;
                });
            };
        };
        return Buffer.toArray(buffer);
    };

    public func supported_block_types() : [TokenTypes.BlockType] {
        return [
            {
                block_type = "7mint";
                url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md";
            },
            {
                block_type = "7burn";
                url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md";
            },
            {
                block_type = "7xfer";
                url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md";
            },
        ];
    };

    public func create_batch(token : TokenTypes.TokenData, caller : Principal) : async* {
        batch_id : Nat;
    } {
        if (caller != token.minting_account.owner) {
            throw Error.reject("Unauthorized: Only the minting_account can upload files.");
        };
        let file_canister_id : Principal = await get_file_canister_id(token);
        let file_canister = actor (Principal.toText(file_canister_id)) : actor {
            create_batch : shared () -> async { batch_id : Nat };
        };
        return await file_canister.create_batch();
    };

    public func create_chunk(token : TokenTypes.TokenData, chunk : Chunk, caller : Principal) : async* {
        chunk_id : Nat;
    } {
        if (caller != token.minting_account.owner) {
            throw Error.reject("Unauthorized: Only the minting_account can upload files.");
        };
        let file_canister_id : Principal = await get_file_canister_id(token);
        let file_canister = actor (Principal.toText(file_canister_id)) : actor {
            create_chunk : shared (Chunk) -> async { chunk_id : Nat };
        };
        return await file_canister.create_chunk(chunk);
    };

    public func commit_chunk(
        token : TokenTypes.TokenData,
        {
            batch_id : Nat;
            chunk : Chunk;
            content_type : Text;
        },
        caller : Principal,
    ) : async* () {
        if (caller != token.minting_account.owner) {
            throw Error.reject("Unauthorized: Only the minting_account can upload files.");
        };
        let file_canister_id : Principal = await get_file_canister_id(token);
        let file_canister = actor (Principal.toText(file_canister_id)) : actor {
            commit_chunk : shared ({
                batch_id : Nat;
                chunk : Chunk;
                content_type : Text;
            }) -> async ();
        };
        return await file_canister.commit_chunk({
            batch_id;
            chunk;
            content_type;
        });
    };

    public func commit_batch(
        token : TokenTypes.TokenData,
        { batch_id : Nat; chunk_ids : [Nat]; content_type : Text } : CommitBatchArg,
        caller : Principal,
    ) : async* () {
        if (caller != token.minting_account.owner) {
            throw Error.reject("Unauthorized: Only the minting_account can upload files.");
        };
        let file_canister_id : Principal = await get_file_canister_id(token);
        let file_canister = actor (Principal.toText(file_canister_id)) : actor {
            commit_batch : shared (CommitBatchArg) -> async ();
        };
        await file_canister.commit_batch({ batch_id; chunk_ids; content_type });
    };

    private func get_file_canister_id(token : TokenTypes.TokenData) : async Principal {
        if (Option.isSome(token.file_canister_id)) {
            return Option.get(token.file_canister_id, Principal.fromText("aaaaa-aa"));
        };
        return await deploy_file_canister(token);
    };

    private func deploy_file_canister(token : TokenTypes.TokenData) : async Principal {
        let cycles_balance = ExperimentalCycles.balance();
        var deploy_file_cycles = Option.get(token.deploy_canister_cycle, DEPLOY_CANISTER_CYCLE);
        if (deploy_file_cycles < DEPLOY_CANISTER_CYCLE) {
            deploy_file_cycles := DEPLOY_CANISTER_CYCLE;
        };
        if (cycles_balance < deploy_file_cycles) {
            throw Error.reject("Cycle: Insufficient cycles balance");
        };
        ExperimentalCycles.add<system>(deploy_file_cycles);
        let file_canister = await File.File();
        let file_canister_id = Principal.fromActor(file_canister);
        token.file_canister_id := ?file_canister_id;
        let ledger_controllers = await get_canister_controllers(file_canister_id);
        await IC0Utils.update_settings_identity_controllers(
            file_canister_id,
            ledger_controllers,
        );
        return file_canister_id;
    };

    func update_canister(token : TokenTypes.TokenData) : async* () {
        let txs_size = SB.size(token.transactions);

        if (txs_size >= MAX_TRANSACTIONS_IN_LEDGER) {
            await* append_transactions(token);
        };
    };

    func append_transactions(token : TokenTypes.TokenData) : async* () {
        let { transactions } = token;

        if (Principal.equal(Principal.fromActor(token.archive.canister), Principal.fromText("aaaaa-aa")) or token.archive.stored_txs >= MAX_TRANSACTIONS_IN_ARCHIVE) {
            let cycles_balance = EC.balance();
            var deploy_archive_cycles = Option.get(token.deploy_canister_cycle, DEPLOY_CANISTER_CYCLE);
            if (deploy_archive_cycles < DEPLOY_CANISTER_CYCLE) {
                deploy_archive_cycles := DEPLOY_CANISTER_CYCLE;
            };
            if (cycles_balance < deploy_archive_cycles) {
                throw Error.reject("Cycle: Insufficient cycles balance");
            };
            EC.add<system>(deploy_archive_cycles);
            var new_archive : TokenTypes.ArchiveData = {
                var canister = await Archive.Archive();
                var stored_txs = 0;
                var start = 0;
                var end = 0;
            };
            let ledger_controllers = await get_canister_controllers(Principal.fromActor(new_archive.canister));
            await IC0Utils.update_settings_identity_controllers(
                Principal.fromActor(new_archive.canister),
                ledger_controllers,
            );
            if (Principal.equal(Principal.fromActor(token.archive.canister), Principal.fromText("aaaaa-aa"))) {
                token.archives := [];
            } else {
                token.archives := Array.append(token.archives, [token.archive]);
                new_archive.start := token.archive.end + 1;
            };
            token.archive := new_archive;
        };

        let res = await token.archive.canister.append_transactions(
            SB.toArray(transactions)
        );

        switch (res) {
            case (#ok(_)) {
                token.archive.stored_txs += SB.size(transactions);
                SB.clear(transactions);
                token.archive.end := total_transactions(token) - 1;
            };
            case (#err(_)) {};
        };
    };

    private func get_canister_controllers(canister_id : Principal) : async [Principal] {
        let controllers = await IC0Utils.getControllers(canister_id);
        if (controllers.size() == 0) { [] } else {
            await IC0Utils.getControllers(controllers.get(0));
        };
    };
};
