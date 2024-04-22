import Result "mo:base/Result";
import Nat "mo:base/Nat";

import BaseTypes "BaseTypes";

module {

    public type Value = BaseTypes.Value;
    public type Transaction = BaseTypes.Transaction;
    public type TxIndex = BaseTypes.TxIndex;

    public type GetBlocksArgs = BaseTypes.GetBlocksArgs;
    public type GetBlocksResult = BaseTypes.GetBlocksResult;

    // Rosetta API
    // The type to request a range of transactions from the ledger canister
    public type GetTransactionsRequest = BaseTypes.GetTransactionsRequest;

    public type TransactionRange = BaseTypes.TransactionRange;

    // The Interface for the Archive canister
    public type ArchiveInterface = actor {
        // Appends the given transactions to the archive.
        // > Only the Ledger canister is allowed to call this method
        append_transactions : shared ([Transaction]) -> async Result.Result<(), Text>;

        // Returns the total number of transactions stored in the archive
        total_transactions : query () -> async Nat;

        // Returns the transaction at the given index
        get_transaction : query (TxIndex) -> async ?Transaction;

        // Returns the transactions in the given range
        get_transactions : query (GetTransactionsRequest) -> async TransactionRange;

        // Returns the number of bytes left in the archive before it is full
        // > The capacity of the archive canister is 32GB
        remaining_capacity : query () -> async Nat;
    };

    public type ICRC3Interface = actor {
        icrc3_get_blocks : query (GetBlocksArgs) -> async (GetBlocksResult);
    };

    // Interface of the ICRC token and Rosetta canister
    public type ArchiveFullInterface = ArchiveInterface and ICRC3Interface;

};
