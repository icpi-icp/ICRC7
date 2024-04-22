import TokenTypes "types/TokenTypes";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";

module {
    public func get_from_map(value : TokenTypes.Value, key : Text) : ?TokenTypes.Value {
        switch (value) {
            case (#Map(map_value)) {
                get_from_array(map_value, key);
            };
            case (_) {
                return null;
            };
        };
    };

    public func get_from_map_with_default(value : TokenTypes.Value, key : Text, default_value : TokenTypes.Value) : TokenTypes.Value {
        switch (value) {
            case (#Map(map_value)) {
                let result = get_from_array(map_value, key);
                switch (result) {
                    case (?result_value) {
                        return result_value;
                    };
                    case (_) {
                        return default_value;
                    };
                };
            };
            case (_) {
                return default_value;
            };
        };
    };

    public func get_from_array(value : [(Text, TokenTypes.Value)], key : Text) : ?TokenTypes.Value {
        switch (Array.find<(Text, TokenTypes.Value)>(value, func(x, y) = x == key)) {
            case (?(key, result)) {
                return ?result;
            };
            case (_) {
                return null;
            };
        };
    };

    public func to_nat(value : TokenTypes.Value) : ?Nat {
        switch (value) {
            case (#Nat(nat_value)) {
                ?nat_value;
            };
            case (_) {
                return null;
            };
        };
    };

    public func to_nat64(value : TokenTypes.Value) : ?Nat64 {
        switch (value) {
            case (#Nat(nat_value)) {
                ?Nat64.fromNat(nat_value);
            };
            case (_) {
                return null;
            };
        };
    };

    public func to_int(value : TokenTypes.Value) : ?Int {
        switch (value) {
            case (#Int(int_value)) {
                ?int_value;
            };
            case (_) {
                return null;
            };
        };
    };

    public func to_blob(value : TokenTypes.Value) : ?Blob {
        switch (value) {
            case (#Blob(blob_value)) {
                ?blob_value;
            };
            case (_) {
                return null;
            };
        };
    };

    public func to_text(value : TokenTypes.Value) : ?Text {
        switch (value) {
            case (#Text(text_value)) {
                ?text_value;
            };
            case (_) {
                return null;
            };
        };
    };
};
