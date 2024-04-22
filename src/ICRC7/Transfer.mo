import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Time "mo:base/Time";

import Itertools "mo:itertools/Iter";

import Account "Account";

import TokenTypes "types/TokenTypes";
import Utils "Utils";
import Value "Value";

module {
    let { SB } = Utils;

    /// Checks if a transfer request is valid
    public func validate_request(
        token : TokenTypes.TokenData,
        tx_req : TokenTypes.TransactionRequest,
    ) : Result.Result<(), TokenTypes.TransferError> {

        if (tx_req.from == tx_req.to) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "The sender cannot have the same account as the recipient.";
                })
            );
        };

        if (not Account.validate(tx_req.from)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for sender. " # debug_show (tx_req.from);
                })
            );
        };

        if (not Account.validate(tx_req.to)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Invalid account entered for recipient " # debug_show (tx_req.to);
                })
            );
        };

        if (not validate_memo(tx_req.memo)) {
            return #err(
                #GenericError({
                    error_code = 0;
                    message = "Memo must not be more than 32 bytes";
                })
            );
        };

        switch (tx_req.kind) {
            case (#transfer) {
                let balance : TokenTypes.AccountTokens = Utils.get_balance(
                    token.account_balances,
                    tx_req.encoded.from,
                );
                let existing = Array.find<Nat>(balance.tokens, func x = x == tx_req.token_id);
                if (not Option.isSome(existing)) {
                    return #err(#NonExistingTokenId);
                };
            };

            case (#mint) {
                if (token.supply_cap < (token._minted_tokens + 1)) {
                    return #err(
                        #GenericError({
                            error_code = 0;
                            message = "Cannot mint more than " # Nat.toText(token._minted_tokens) # " tokens";
                        })
                    );
                };
            };
            case (#burn) {
                if (tx_req.to == token.minting_account) {
                    return #err(
                        #InvalidRecipient
                    );
                };

                let balance : TokenTypes.AccountTokens = Utils.get_balance(
                    token.account_balances,
                    tx_req.encoded.from,
                );
                let existing = Array.find<Nat>(balance.tokens, func x = x == tx_req.token_id);
                if (not Option.isSome(existing)) {
                    return #err(#NonExistingTokenId);
                };
            };
        };

        switch (tx_req.created_at_time) {
            case (null) {};
            case (?created_at_time) {

                if (is_too_old(token, created_at_time)) {
                    return #err(#TooOld);
                };

                if (is_in_future(token, created_at_time)) {
                    return #err(
                        #CreatedInFuture {
                            ledger_time = Nat64.fromNat(Int.abs(Time.now()));
                        }
                    );
                };

                switch (deduplicate(token, tx_req)) {
                    case (#err(tx_index)) {
                        return #err(
                            #Duplicate {
                                duplicate_of = tx_index;
                            }
                        );
                    };
                    case (_) {};
                };
            };
        };

        #ok();
    };

    /// Checks if a transaction memo is valid
    public func validate_memo(memo : ?TokenTypes.Memo) : Bool {
        switch (memo) {
            case (?bytes) {
                bytes.size() <= 32;
            };
            case (_) true;
        };
    };

    /// Checks if the `created_at_time` of a transfer request is before the accepted time range
    public func is_too_old(token : TokenTypes.TokenData, created_at_time : Nat64) : Bool {
        let lower_bound = Time.now() - token.tx_window - token.permitted_drift;
        Nat64.toNat(created_at_time) < lower_bound;
    };

    /// Checks if the `created_at_time` of a transfer request has not been reached yet relative to the canister's time.
    public func is_in_future(token : TokenTypes.TokenData, created_at_time : Nat64) : Bool {
        let upper_bound = Time.now() + token.permitted_drift;
        Nat64.toNat(created_at_time) > upper_bound;
    };

    /// Checks if there is a duplicate transaction that matches the transfer request in the main canister.
    ///
    /// If a duplicate is found, the function returns an error (`#err`) with the duplicate transaction's index.
    public func deduplicate(token : TokenTypes.TokenData, tx_req : TokenTypes.TransactionRequest) : Result.Result<(), Nat> {
        // only deduplicates if created_at_time is set
        if (tx_req.created_at_time == null) {
            return #ok();
        };

        let { transactions = txs } = token;

        var phantom_txs_size = 0;
        let phantom_txs = SB._clearedElemsToIter(txs);
        let current_txs = SB.vals(txs);

        let last_2000_txs = if (token.archive.stored_txs > 0) {
            phantom_txs_size := SB.capacity(txs) - SB.size(txs);
            Itertools.chain(phantom_txs, current_txs);
        } else {
            current_txs;
        };

        var tx_id = 0;
        label for_loop for ((i, tx) in Itertools.enumerate(last_2000_txs)) {
            let is_duplicate = switch (tx) {
                case (#Map(tx_array)) {
                    let (btype, btype_value) = Option.get(Array.find<(Text, TokenTypes.Value)>(tx_array, func(x, y) = x == "btype"), (null, null));
                    let (ts, ts_value) = Option.get(Array.find<(Text, TokenTypes.Value)>(tx_array, func(x, y) = x == "ts"), (null, null));
                    let tx_value = Value.get_from_array(tx_array, "tx");
                    let index_value = Value.get_from_array(tx_array, "index");
                    switch (index_value) {
                        case (?index_value) {
                            tx_id := Option.get(Value.to_nat(index_value), 0);
                        };
                        case (_) {
                            Debug.print("index_value is null");
                        };
                    };
                    switch (tx_value) {
                        case (?tx_value) {
                            let tx_ts_value = Value.to_nat64(Value.get_from_map_with_default(tx_value, "ts", #Nat(0)));
                            let tx_tid_value = Value.get_from_map(tx_value, "tid");
                            let tx_memo_value = Value.get_from_map(tx_value, "memo");
                            let tx_from_value = Value.get_from_map(tx_value, "from");
                            let tx_to_value = Value.get_from_map_with_default(tx_value, "to", #Blob("\00\00\00"));

                            let is_duplicate = switch (tx_req.kind) {
                                case (#mint) {
                                    if (btype_value == "7mint") {
                                        ignore do ? {
                                            if (is_too_old(token, tx_ts_value!)) {
                                                break for_loop;
                                            };
                                        };
                                        Account.encode(tx_req.to) == tx_to_value and tx_req.token_id == tx_tid_value and tx_req.memo == tx_memo_value and tx_req.created_at_time == tx_ts_value;
                                    } else (
                                        false
                                    );
                                };
                                case (#burn) {
                                    if (btype_value == "7burn") {
                                        ignore do ? {
                                            if (is_too_old(token, tx_ts_value!)) {
                                                break for_loop;
                                            };
                                        };
                                        Account.encode(tx_req.from) == tx_from_value and tx_req.token_id == tx_tid_value and tx_req.memo == tx_memo_value and tx_req.created_at_time == tx_ts_value;
                                    } else {
                                        false;
                                    };
                                };
                                case (#transfer) {
                                    if (btype_value == "7xfer") {
                                        ignore do ? {
                                            if (is_too_old(token, tx_ts_value!)) {
                                                break for_loop;
                                            };
                                        };
                                        Account.encode(tx_req.to) == tx_to_value and Account.encode(tx_req.from) == tx_from_value and tx_req.token_id == tx_tid_value and tx_req.memo == tx_memo_value and tx_req.created_at_time == tx_ts_value;
                                    } else {
                                        false;
                                    };
                                };
                            };
                        };
                        case (_) {
                            false;
                        };
                    };
                };
                case (_) {
                    false;
                };
            };
            if (is_duplicate) { return #err(tx_id) };
        };

        #ok();
    };
};
