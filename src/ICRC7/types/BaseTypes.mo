import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

import STMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";

module {

    // Generic value in accordance with ICRC-3
    public type Value = {
        #Nat : Nat;
        #Int : Int;
        #Blob : Blob;
        #Text : Text;
        #Array : [Value];
        #Map : [(Text, Value)];
    };

    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };
    public type Subaccount = Blob;

    public type Balance = Nat;

    public type TxIndex = Nat;

    public type StableBuffer<T> = StableBuffer.StableBuffer<T>;
    public type StableTrieMap<K, V> = STMap.StableTrieMap<K, V>;

    public type Transaction = Value;

    public type GetBlocksArgs = [{ start : Nat; length : Nat }];

    public type GetBlocksResult = {
        // Total number of blocks in the block log
        log_length : Nat;
        // Blocks found locally to the Ledger
        blocks : [{ id : Nat; block : Value }];
        // List of callbacks to fetch the blocks that are not local
        // to the Ledger, i.e. archived blocks
        archived_blocks : [{
            args : GetBlocksArgs;
            callback : query (GetBlocksArgs) -> async GetBlocksResult;
        }];
    };

    // Rosetta API
    // The type to request a range of transactions from the ledger canister
    public type GetTransactionsRequest = {
        start : TxIndex;
        length : Nat;
    };

    public type TransactionRange = {
        transactions : [Transaction];
    };

    public type QueryArchiveFn = shared query (GetTransactionsRequest) -> async TransactionRange;

    public type ArchivedTransaction = {
        // The index of the first transaction to be queried in the archive canister
        start : TxIndex;
        // The number of transactions to be queried in the archive canister
        length : Nat;

        // The callback function to query the archive canister
        callback : QueryArchiveFn;
    };

    public type GetTransactionsResponse = {
        // The number of valid transactions in the ledger and archived canisters that are in the given range
        log_length : Nat;

        // the index of the first tx in the `transactions` field
        first_index : TxIndex;

        // The transactions in the ledger canister that are in the given range
        transactions : [Transaction];

        // Pagination request for archived transactions in the given range
        archived_transactions : [ArchivedTransaction];
    };
};
