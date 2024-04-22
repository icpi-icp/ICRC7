import Bool "mo:base/Bool";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Nat "mo:base/Nat";
import ICRC7 "..";

shared ({ caller = ledger_owner }) actor class Token(
    init_args : ICRC7.TokenInitArgs
) : async ICRC7.LedgerFullInterface = this {

    let icrc7_args : ICRC7.InitArgs = {
        init_args with minting_account = Option.get(
            init_args.minting_account,
            {
                owner = ledger_owner;
                subaccount = null;
            },
        );
    };

    stable let token = ICRC7.init(icrc7_args);

    /**
        Functions for the ICRC7 token standard
     */
    public query func icrc7_collection_metadata() : async ICRC7.MetaData {
        ICRC7.metadata(token);
    };

    public query func icrc7_name() : async Text {
        ICRC7.name(token);
    };

    public query func icrc7_symbol() : async Text {
        ICRC7.symbol(token);
    };

    public query func icrc7_description() : async ?Text {
        ICRC7.description(token);
    };

    public query func icrc7_logo() : async ?Text {
        ICRC7.logo(token);
    };

    public query func icrc7_minting_account() : async ?ICRC7.Account {
        ?ICRC7.minting_account(token);
    };

    public query func icrc7_total_supply() : async Nat {
        ICRC7.total_supply(token);
    };

    public query func icrc7_supply_cap() : async ?Nat {
        ?ICRC7.supply_cap(token);
    };

    public query func icrc7_max_query_batch_size() : async ?Nat {
        ?ICRC7.max_query_batch_size(token);
    };

    public query func icrc7_max_update_batch_size() : async ?Nat {
        ?ICRC7.max_update_batch_size(token);
    };

    public query func icrc7_default_take_value() : async ?Nat {
        ?ICRC7.default_take_value(token);
    };

    public query func icrc7_max_take_value() : async ?Nat {
        ?ICRC7.max_take_value(token);
    };

    public query func icrc7_max_memo_size() : async ?Nat {
        ?ICRC7.max_memo_size(token);
    };

    public query func icrc7_atomic_batch_transfers() : async ?Bool {
        ?ICRC7.atomic_batch_transfers(token);
    };

    public query func icrc7_tx_window() : async ?Nat {
        ?ICRC7.tx_window(token);
    };

    public query func icrc7_permitted_drift() : async ?Nat {
        ?ICRC7.permitted_drift(token);
    };

    public query func icrc7_token_metadata(token_ids : [Nat]) : async [?ICRC7.MetaData] {
        ICRC7.token_metadata(token, token_ids);
    };

    public query func icrc7_owner_of(token_ids : [Nat]) : async [?ICRC7.Account] {
        ICRC7.owner_of(token, token_ids);
    };

    public query func icrc7_balance_of(accounts : [ICRC7.Account]) : async [ICRC7.Balance] {
        ICRC7.balance_of(token, accounts);
    };

    public query func icrc7_tokens(prev : ?Nat, take : ?Nat) : async [Nat] {
        ICRC7.tokens(token, prev, take);
    };
    public query func icrc7_tokens_of(owner : ICRC7.Account, prev : ?Nat, take : ?Nat) : async [Nat] {
        ICRC7.tokens_of(token, owner, prev, take);
    };

    public query func icrc61_supported_standards() : async [ICRC7.SupportedStandard] {
        ICRC7.supported_standards(token);
    };

    public query func get_transactions(req : ICRC7.GetTransactionsRequest) : async ICRC7.GetTransactionsResponse {
        ICRC7.get_transactions(token, req);
    };

    public shared func get_file_canister() : async Principal {
        await ICRC7.get_file_canister(token);
    };

    public query func icrc3_get_archives(args : ICRC7.GetArchivesArgs) : async ICRC7.GetArchivesResult {
        ICRC7.get_archives(token, args);
    };

    public query func icrc3_get_blocks(args : ICRC7.GetBlocksArgs) : async ICRC7.GetBlocksResult {
        ICRC7.get_blocks(token, args);
    };

    public query func icrc3_get_tip_certificate() : async ?ICRC7.DataCertificate {
        ICRC7.get_tip_certificate(token);
    };

    public query func icrc3_supported_block_types() : async [ICRC7.BlockType] {
        ICRC7.supported_block_types();
    };

    public shared ({ caller }) func icrc7_transfer(args : [ICRC7.TransferArg]) : async [?ICRC7.TransferResult] {
        await* ICRC7.transfer(token, args, caller);
    };

    public shared ({ caller }) func mint(args : ICRC7.MintArg) : async [?ICRC7.TransferResult] {
        await* ICRC7.mint(token, args, caller);
    };

    public shared ({ caller }) func burn(args : ICRC7.BurnArg) : async [?ICRC7.TransferResult] {
        await* ICRC7.burn(token, args, caller);
    };

    public shared ({ caller }) func create_batch() : async { batch_id : Nat } {
        await* ICRC7.create_batch(token, caller);
    };

    public shared ({ caller }) func create_chunk(chunk : ICRC7.Chunk) : async {
        chunk_id : Nat;
    } {
        await* ICRC7.create_chunk(token, chunk, caller);
    };

    public shared ({ caller }) func commit_chunk({
        batch_id : Nat;
        chunk : ICRC7.Chunk;
        content_type : Text;
    }) : async () {
        await* ICRC7.commit_chunk(token, { batch_id; chunk; content_type }, caller);
    };

    public shared ({ caller }) func commit_batch(
        { batch_id : Nat; chunk_ids : [Nat]; content_type : Text } : ICRC7.CommitBatchArg
    ) : async () {
        await* ICRC7.commit_batch(token, { batch_id; chunk_ids; content_type }, caller);
    };

    public query ({ caller }) func query_cycle_balance() : async Nat {
        ExperimentalCycles.balance();
    };
};
