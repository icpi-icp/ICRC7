import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Option "mo:base/Option";

import RepIndy "mo:rep-indy-hash";
import Itertools "mo:itertools/Iter";
import STMap "mo:StableTrieMap";
import StableBuffer "mo:StableBuffer/StableBuffer";

import Account "Account";
import TokenTypes "types/TokenTypes";

module {
    // Creates a Stable Buffer with the default metadata and returns it.
    public func init_metadata(args : TokenTypes.InitArgs) : StableBuffer.StableBuffer<TokenTypes.MetaDatum> {
        let metadata = SB.initPresized<TokenTypes.MetaDatum>(5);
        SB.add(metadata, ("icrc7:name", #Text(args.name)));
        SB.add(metadata, ("icrc7:symbol", #Text(args.symbol)));
        SB.add(metadata, ("icrc7:description", #Text(args.description)));
        SB.add(metadata, ("icrc7:logo", #Text(args.logo)));
        SB.add(metadata, ("icrc7:supply_cap", #Nat(args.supply_cap)));
        metadata;
    };

    public let default_standard : TokenTypes.SupportedStandard = {
        name = "ICRC-7";
        url = "https://github.com/dfinity/ICRC/tree/main/ICRCs/ICRC-7";
    };

    // Creates a Stable Buffer with the default supported standards and returns it.
    public func init_standards() : StableBuffer.StableBuffer<TokenTypes.SupportedStandard> {
        let standards = SB.initPresized<TokenTypes.SupportedStandard>(4);
        SB.add(standards, default_standard);
        SB.add(
            standards,
            {
                name = "ICRC-3";
                url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
            },
        );
        standards;
    };

    // Returns the default subaccount for cases where a user does
    // not specify it.
    public func default_subaccount() : TokenTypes.Subaccount {
        Blob.fromArray(
            Array.tabulate(32, func(_ : Nat) : Nat8 { 0 })
        );
    };

    public func account_to_array_value(account : TokenTypes.Account) : TokenTypes.Value{
        let buffer = Buffer.Buffer<TokenTypes.Value>(2);
        buffer.add(#Blob(Principal.toBlob(account.owner)));
        switch(account.subaccount){
            case(?subaccount){
                buffer.add(#Blob(subaccount));
            };
            case(_){

            };
        };
        #Array(Buffer.toArray(buffer));
    };

    // this is a local copy of deprecated Hash.hashNat8 (redefined to suppress the warning)
    func hashNat8(key : [Nat32]) : Hash.Hash {
        var hash : Nat32 = 0;
        for (natOfKey in key.vals()) {
            hash := hash +% natOfKey;
            hash := hash +% hash << 10;
            hash := hash ^ (hash >> 6);
        };
        hash := hash +% hash << 3;
        hash := hash ^ (hash >> 11);
        hash := hash +% hash << 15;
        return hash;
    };

    // Computes a hash from the least significant 32-bits of `n`, ignoring other bits.
    public func hash(n : Nat) : Hash.Hash {
        let j = Nat32.fromNat(n);
        hashNat8([
            j & (255 << 0),
            j & (255 << 8),
            j & (255 << 16),
            j & (255 << 24),
        ]);
    };

    // Formats the different operation arguements into
    // a `TransactionRequest`, an internal type to access fields easier.
    public func create_transfer_req(
        args : TokenTypes.TransferArg,
        owner : Principal,
        tx_kind : TokenTypes.TxKind,
    ) : TokenTypes.TransactionRequest {

        let from = {
            owner;
            subaccount = args.from_subaccount;
        };

        let encoded = {
            from = Account.encode(from);
            to = Account.encode(args.to);
        };

        switch (tx_kind) {
            case (#mint) {
                {
                    args with kind = #mint;
                    fee = null;
                    from;
                    encoded;
                };
            };
            case (#burn) {
                {
                    args with kind = #burn;
                    fee = null;
                    from;
                    encoded;
                };
            };
            case (#transfer) {
                {
                    args with kind = #transfer;
                    from;
                    encoded;
                };
            };
        };
    };

    // Transforms the transaction kind from `variant` to `Text`
    public func kind_to_text(kind : TokenTypes.TxKind) : Text {
        switch (kind) {
            case (#mint) "7mint";
            case (#burn) "7burn";
            case (#transfer) "7xfer";
        };
    };

    // Formats the tx request into a finalised transaction
    public func req_to_value(tx_req : TokenTypes.TransactionRequest, index : Nat, token : TokenTypes.TokenData) : TokenTypes.Value {
        let buffer = Buffer.Buffer<(Text, TokenTypes.Value)>(5);
        let btype = kind_to_text(tx_req.kind);
        if (index > 0) {
            let parent_tx = Option.get(token.last_tx, #Blob(Blob.fromArray([])));
            buffer.add("phash", #Blob(Blob.fromArray(RepIndy.hash_val(parent_tx))));
        };
        buffer.add("btype", #Text(btype));
        buffer.add("ts", #Nat(Int.abs(Time.now())));
        buffer.add("index", #Nat(index));

        let tx_buffer = Buffer.Buffer<(Text, TokenTypes.Value)>(5);
        tx_buffer.add("tid", #Nat(tx_req.token_id));
        let _from_account = Account.decode(tx_req.encoded.from);
        switch(_from_account){
            case(?from_account){
                tx_buffer.add("from", account_to_array_value(from_account));
            };
            case(_){

            };
        };
        let _to_account = Account.decode(tx_req.encoded.to);
        switch(_to_account){
            case(?to_account){
                tx_buffer.add("to", account_to_array_value(to_account));
            };
            case(_){

            };
        };
        switch (tx_req.kind) {
            case (#mint) {
                let _token_metadta = get_metadata(token.metadatas,tx_req.token_id);
                switch(_token_metadta){
                    case(?token_metadata){
                        tx_buffer.add("icrc7:token_metadata", #Map(token_metadata));
                    };
                    case(_){
                        tx_buffer.add("icrc7:token_metadata", #Map([]));
                    };
                };
            };
            case (_) {};
        };

        switch (tx_req.kind) {
            case (#burn) {};
            case (_) {};
        };

        switch (tx_req.kind) {
            case (#transfer) {};
            case (_) {};
        };

        switch (tx_req.memo) {
            case (?memo) {
                tx_buffer.add("memo", #Blob(memo));
            };
            case (_) {};
        };

        switch (tx_req.created_at_time) {
            case (?created_at_time) {
                tx_buffer.add("memo", #Nat(Nat64.toNat(created_at_time)));
            };
            case (_) {};
        };

        buffer.add("tx", #Map(Buffer.toArray(tx_buffer)));

        #Map(Buffer.toArray(buffer));
    };

    public func div_ceil(n : Nat, d : Nat) : Nat {
        (n + d - 1) / d;
    };

    public func get_metadata(metadatas : TokenTypes.MetadataMap, token_id : Nat) : ?TokenTypes.MetaData {
        let res = STMap.get(
            metadatas,
            Nat.equal,
            hash,
            token_id,
        );

        switch (res) {
            case (?metadata) {
                ?metadata;
            };
            case (_) { null };
        };
    };

    public func get_owner(owners : TokenTypes.Holders, token_id : Nat) : ?TokenTypes.Account {
        let _owner = STMap.get(
            owners,
            Nat.equal,
            hash,
            token_id,
        );
        switch (_owner) {
            case (?owner) {
                let encoded_account = owner;
                Account.decode(encoded_account);
            };
            case (_) {
                null;
            };
        };
    };

    /// Retrieves the balance of an account
    public func get_balance(accounts : TokenTypes.AccountBalances, encoded_account : TokenTypes.EncodedAccount) : TokenTypes.AccountTokens {
        let res = STMap.get(
            accounts,
            Blob.equal,
            Blob.hash,
            encoded_account,
        );

        switch (res) {
            case (?balance) {
                balance;
            };
            case (_) { { tokens = [] } };
        };
    };

    /// Updates the balance of an account
    public func update_balance(
        accounts : TokenTypes.AccountBalances,
        encoded_account : TokenTypes.EncodedAccount,
        update : (TokenTypes.AccountTokens) -> TokenTypes.AccountTokens,
    ) {
        let prev_balance = get_balance(accounts, encoded_account);
        let updated_balance = update(prev_balance);

        if (updated_balance != prev_balance) {
            STMap.put(
                accounts,
                Blob.equal,
                Blob.hash,
                encoded_account,
                updated_balance,
            );
        };
    };

    // Transfers tokens from the sender to the
    // recipient in the tx request
    public func transfer_balance(
        token : TokenTypes.TokenData,
        tx_req : TokenTypes.TransactionRequest,
    ) {
        let { encoded; token_id } = tx_req;

        update_balance(
            token.account_balances,
            encoded.from,
            func(balance) {
                {
                    tokens = Array.filter<Nat>(balance.tokens, func x = x != token_id);
                };
            },
        );

        update_balance(
            token.account_balances,
            encoded.to,
            func(balance) {
                { tokens = Array.append<Nat>(balance.tokens, [token_id]) };
            },
        );

        STMap.put(
            token.holders,
            Nat.equal,
            hash,
            token_id,
            encoded.to,
        );

        //replace metadata
        let _metadata = get_metadata(token.metadatas, token_id);
        switch (_metadata) {
            case (?metadata) {
                let new_metadata = Array.filter<TokenTypes.MetaDatum>(metadata, func(key, value) = key != "owner");
                let buffer = Buffer.fromArray<TokenTypes.MetaDatum>(new_metadata);

                let owner_encoded = Account.decode(encoded.to);
                switch (owner_encoded) {
                    case (?owner_encoded_account) {
                        buffer.add("owner", #Text(Principal.toText(owner_encoded_account.owner)));
                    };
                    case (_) {
                        
                    };
                };

                STMap.put(token.metadatas, Nat.equal, hash, token_id, Buffer.toArray(buffer));
            };
            case (_) {

            };
        };

    };

    public func mint_balance(
        token : TokenTypes.TokenData,
        to_encoded_account : TokenTypes.EncodedAccount,
        token_id : Nat,
        input_metadata : ?[TokenTypes.MetaDatum],
    ) {
        //  metadatas
        let buffer = Buffer.Buffer<TokenTypes.MetaDatum>(0);
        buffer.add("id", #Nat(token_id));
        buffer.add("minter", #Text(Principal.toText(token.minting_account.owner)));
        buffer.add("mint_time", #Nat(Int.abs(Time.now())));
        let owner_encoded = Account.decode(to_encoded_account);
        switch (owner_encoded) {
            case (?owner_encoded_account) {
                buffer.add("owner", #Text(Principal.toText(owner_encoded_account.owner)));
            };
            case (_) {
                buffer.add("owner", #Text(Principal.toText(token.minting_account.owner)));
            };
        };

        let metadata = switch (input_metadata) {
            case (?input_metadata) {
                let input_buffer = Buffer.fromArray<TokenTypes.MetaDatum>(input_metadata);
                buffer.append(input_buffer);
                Buffer.toArray(buffer);
            };
            case (_) {
                Buffer.toArray(buffer);
            };
        };
        STMap.put(
            token.metadatas,
            Nat.equal,
            hash,
            token_id,
            metadata,
        );
        STMap.put(
            token.holders,
            Nat.equal,
            hash,
            token_id,
            to_encoded_account,
        );

        //account_balances
        update_balance(
            token.account_balances,
            to_encoded_account,
            func(balance) {
                { tokens = Array.append<Nat>(balance.tokens, [token_id]) };
            },
        );

        if(token.last_token_id < token_id){
            token.last_token_id := token_id;
        };
        token._minted_tokens += 1;
    };

    public func burn_balance(
        token : TokenTypes.TokenData,
        from_encoded_account : TokenTypes.EncodedAccount,
        token_id : Nat,
    ) {
        //delete from
        update_balance(
            token.account_balances,
            from_encoded_account,
            func(balance) {
                {
                    tokens = Array.filter<Nat>(balance.tokens, func x = x != token_id);
                };
            },
        );
        //add to aaaaa-aaa
        let to_principal = Account.encode({
            owner = Principal.fromText("aaaaa-aaa");
            subaccount = null;
        });
        update_balance(
            token.account_balances,
            to_principal,
            func(balance) {
                { tokens = Array.append<Nat>(balance.tokens, [token_id]) };
            },
        );
        STMap.put(
            token.holders,
            Nat.equal,
            hash,
            token_id,
            to_principal,
        );

        let _metadata = get_metadata(token.metadatas, token_id);
        switch (_metadata) {
            case (?metadata) {
                let new_metadata = Array.filter<TokenTypes.MetaDatum>(metadata, func(key, value) = key != "owner");
                let buffer = Buffer.fromArray<TokenTypes.MetaDatum>(new_metadata);
                buffer.add("owner", #Text("aaaaa-aaa"));
                STMap.put(token.metadatas, Nat.equal, hash, token_id, Buffer.toArray(buffer));
            };
            case (_) {

            };
        };

        token._burned_tokens += 1;
    };

    // Stable Buffer Module with some additional functions
    public let SB = {
        StableBuffer with slice = func<A>(buffer : TokenTypes.StableBuffer<A>, start : Nat, end : Nat) : [A] {
            let size = SB.size(buffer);
            if (start >= size) {
                return [];
            };

            let slice_len = (Nat.min(end, size) - start) : Nat;

            Array.tabulate(
                slice_len,
                func(i : Nat) : A {
                    SB.get(buffer, i + start);
                },
            );
        };

        toIterFromSlice = func<A>(buffer : TokenTypes.StableBuffer<A>, start : Nat, end : Nat) : Iter.Iter<A> {
            if (start >= SB.size(buffer)) {
                return Itertools.empty();
            };

            Iter.map(
                Itertools.range(start, Nat.min(SB.size(buffer), end)),
                func(i : Nat) : A {
                    SB.get(buffer, i);
                },
            );
        };

        appendArray = func<A>(buffer : TokenTypes.StableBuffer<A>, array : [A]) {
            for (elem in array.vals()) {
                SB.add(buffer, elem);
            };
        };

        getLast = func<A>(buffer : TokenTypes.StableBuffer<A>) : ?A {
            let size = SB.size(buffer);

            if (size > 0) {
                SB.getOpt(buffer, (size - 1) : Nat);
            } else {
                null;
            };
        };

        capacity = func<A>(buffer : TokenTypes.StableBuffer<A>) : Nat {
            buffer.elems.size();
        };

        _clearedElemsToIter = func<A>(buffer : TokenTypes.StableBuffer<A>) : Iter.Iter<A> {
            Iter.map(
                Itertools.range(buffer.count, buffer.elems.size()),
                func(i : Nat) : A {
                    buffer.elems[i];
                },
            );
        };
    };
};
