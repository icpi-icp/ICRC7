import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import Principal "mo:base/Principal";

import StableBuffer "mo:StableBuffer/StableBuffer";
import CertTree "mo:cert/CertTree";
import ArchiveTypes "ArchiveTypes";
import BaseTypes "BaseTypes";

module {

    // Generic value in accordance with ICRC-3
    public type Value = BaseTypes.Value;
    public type Account = BaseTypes.Account;
    public type Subaccount = BaseTypes.Subaccount;
    public type Balance = BaseTypes.Balance;
    public type TxIndex = BaseTypes.TxIndex;
    public type StableBuffer<T> = BaseTypes.StableBuffer<T>;
    public type StableTrieMap<K, V> = BaseTypes.StableTrieMap<K, V>;
    public type Transaction = BaseTypes.Transaction;

    public type EncodedAccount = Blob;

    public type SupportedStandard = {
        name : Text;
        url : Text;
    };

    public type Memo = Blob;
    public type Timestamp = Nat64;
    public type Duration = Nat64;

    public type MetaDatum = (Text, Value);
    public type MetaData = [MetaDatum];
    public type InitArgs = {
        name : Text;
        symbol : Text;
        logo : Text;
        description : Text;
        minting_account : Account;
        supply_cap : Balance;
        advanced_settings : ?AdvancedSettings;
        deploy_canister_cycle : ?Nat;
    };

    public type TokenInitArgs = {
        name : Text;
        symbol : Text;
        logo : Text;
        description : Text;
        supply_cap : Balance;
        minting_account : ?Account;
        advanced_settings : ?AdvancedSettings;
        deploy_canister_cycle : ?Nat;
    };

    public type AdvancedSettings = {
        tx_window : ?Timestamp;
        permitted_drift : ?Timestamp;
        max_query_batch_size : ?Nat;
        max_update_batch_size : ?Nat;
        default_take_value : ?Nat;
        max_take_value : ?Nat;
        max_memo_size : ?Nat;
        atomic_batch_transfers : ?Bool;
    };

    public type TxKind = {
        #mint;
        #burn;
        #transfer;
    };

    public type MintArg = {
        to : Account;
        metadata : MetaData;
        memo : ?Blob;
        created_at_time : ?Nat64;
        token_id : ?Nat;
    };

    public type TransferArg = {
        from_subaccount : ?Subaccount; // The subaccount to transfer the token from
        to : Account;
        token_id : Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type BurnArg = {
        from_subaccount : ?Subaccount;
        token_id : Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    // Arguments for a transfer operation
    public type TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        token_id : Nat;
        metadata : ?MetaData;
        memo : ?Blob;

        // The time at which the transaction was created.
        // If this is set, the canister will check for duplicate transactions and reject them.
        created_at_time : ?Nat64;
    };

    // Internal representation of a transaction request
    public type TransactionRequest = {
        kind : TxKind;
        from : Account;
        to : Account;
        token_id : Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
        encoded : {
            from : EncodedAccount;
            to : EncodedAccount;
        };
    };

    public type TransferResult = {
        #Ok : TxIndex; // Transaction index for successful transfer
        #Err : TransferError;
    };

    public type TimeError = {
        #TooOld;
        #CreatedInFuture : { ledger_time : Timestamp };
    };

    public type TransferError = TimeError or {
        #NonExistingTokenId;
        #InvalidRecipient;
        #Unauthorized;
        #Duplicate : { duplicate_of : Nat };
        #GenericError : { error_code : Nat; message : Text };
        #GenericBatchError : { error_code : Nat; message : Text };
    };

    // Interface for the ICRC token canister
    public type ICRC7Interface = actor {

        icrc7_collection_metadata : query () -> async MetaData;

        icrc7_symbol : query () -> async Text;

        icrc7_name : query () -> async Text;

        icrc7_description : query () -> async ?Text;

        icrc7_logo : query () -> async ?Text;

        icrc7_total_supply : query () -> async Nat;

        icrc7_supply_cap : query () -> async ?Nat;

        icrc7_max_query_batch_size : query () -> async ?Nat;

        icrc7_max_update_batch_size : query () -> async ?Nat;

        icrc7_default_take_value : query () -> async ?Nat;

        icrc7_max_take_value : query () -> async ?Nat;

        icrc7_max_memo_size : query () -> async ?Nat;

        icrc7_atomic_batch_transfers : query () -> async ?Bool;

        icrc7_tx_window : query () -> async ?Nat;

        icrc7_permitted_drift : query () -> async ?Nat;

        icrc7_token_metadata : query ([Nat]) -> async [?MetaData];

        icrc7_owner_of : query ([Nat]) -> async [?Account];

        icrc7_balance_of : query ([Account]) -> async [Balance];

        icrc7_tokens : query (?Nat, ?Nat) -> async [Nat];

        icrc7_tokens_of : query (Account, ?Nat, ?Nat) -> async [Nat];

        icrc7_transfer : shared ([TransferArg]) -> async ([?TransferResult]);

        icrc61_supported_standards : query () -> async [SupportedStandard];

    };

    public type GetBlocksArgs = BaseTypes.GetBlocksArgs;
    public type GetBlocksResult = BaseTypes.GetBlocksResult;

    public type GetArchivesArgs = {
        // The last archive seen by the client.
        // The Ledger will return archives coming
        // after this one if set, otherwise it
        // will return the first archives.
        from : ?Principal;
    };

    public type GetArchivesResult = [{
        // The id of the archive
        canister_id : Principal;
        // The first block in the archive
        start : Nat;
        // The last block in the archive
        end : Nat;
    }];

    public type DataCertificate = {
        // Signature of the root of the hash_tree
        certificate : Blob;
        // CBOR encoded hash_tree
        hash_tree : Blob;
    };

    public type BlockType = {
        block_type : Text;
        url : Text;
    };

    public type ICRC3Interface = actor {
        icrc3_get_archives : query (GetArchivesArgs) -> async (GetArchivesResult);
        icrc3_get_blocks : query (GetBlocksArgs) -> async (GetBlocksResult);
        icrc3_get_tip_certificate : query () -> async (?DataCertificate);
        icrc3_supported_block_types : query () -> async [BlockType];
    };

    public type AccountTokens = {
        tokens : [Nat];
    };
    public type AccountBalances = StableTrieMap<EncodedAccount, AccountTokens>;

    public type MetadataMap = StableTrieMap<Nat, MetaData>;

    public type Holders = StableTrieMap<Nat, EncodedAccount>;

    public type ArchiveData = {
        var canister : ArchiveTypes.ArchiveFullInterface;
        var stored_txs : Nat;
        var start : Nat;
        var end : Nat;
    };

    public type TokenData = {
        name : Text;
        symbol : Text;
        logo : Text;
        description : Text;
        supply_cap : Balance;
        var _minted_tokens : Balance;
        var _burned_tokens : Balance;
        minting_account : Account;
        metadata : StableBuffer<MetaDatum>;
        var max_query_batch_size : Nat;
        var max_update_batch_size : Nat;
        var default_take_value : Nat;
        var max_take_value : Nat;
        var max_memo_size : Nat;
        var atomic_batch_transfers : Bool;
        var tx_window : Nat;
        var permitted_drift : Nat;
        supported_standards : StableBuffer<SupportedStandard>;
        metadatas : MetadataMap;
        var last_token_id : Nat;
        holders : Holders;
        account_balances : AccountBalances;
        transactions : StableBuffer<Transaction>;
        var archive : ArchiveData;
        var archives : [ArchiveData];
        var file_canister_id : ?Principal;
        var last_tx : ?Transaction;
        var cert_store : CertTree.Store;
        var deploy_canister_cycle : ?Nat;
    };

    public type GetTransactionsRequest = BaseTypes.GetTransactionsRequest;
    public type TransactionRange = BaseTypes.TransactionRange;
    public type QueryArchiveFn = BaseTypes.QueryArchiveFn;
    public type ArchivedTransaction = BaseTypes.ArchivedTransaction;
    public type GetTransactionsResponse = BaseTypes.GetTransactionsResponse;

    public type RosettaInterface = actor {
        get_transactions : shared query (GetTransactionsRequest) -> async GetTransactionsResponse;
    };

    public type LedgerFullInterface = ICRC7Interface and ICRC3Interface and RosettaInterface;

};
