import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import ExperimentalCycles "mo:base/ExperimentalCycles";

import FileTypes "../types/FileTypes";
import IC0Utils "../IC0Utils";

shared ({ caller = ledger_canister_id }) actor class File() = this {

    private type HeaderField = FileTypes.HeaderField;
    private type HttpRequest = FileTypes.HttpRequest;
    private type HttpResponse = FileTypes.HttpResponse;

    private type StreamingStrategy = FileTypes.StreamingStrategy;
    private type StreamingCallbackToken = FileTypes.StreamingCallbackToken;

    private type Chunk = FileTypes.Chunk;
    private type AssetEncodingBlob = FileTypes.AssetEncodingBlob;
    private type AssetBlob = FileTypes.AssetBlob;

    public type StreamingCallbackHttpResponse = FileTypes.StreamingCallbackHttpResponse;

    private stable var MAX_FILE_SIZE : Nat = 2097152*5;  //10M

    private stable var nextBatchID : Nat = 0;
    private stable var nextChunkID : Nat = 0;

    private var chunksEntries : [(Nat, Chunk)] = [];
    private var chunks : HashMap.HashMap<Nat, Chunk> = HashMap.fromIter<Nat, Chunk>(
        chunksEntries.vals(),
        0,
        Nat.equal,
        Hash.hash,
    );

    private stable var assetsEntriesBlob : [(Text, AssetBlob)] = [];
    private var assetsBlob : HashMap.HashMap<Text, AssetBlob> = HashMap.fromIter<Text, AssetBlob>(
        assetsEntriesBlob.vals(),
        0,
        Text.equal,
        Text.hash,
    );

    public query func http_request(request : HttpRequest) : async HttpResponse {
        if (request.method == "GET") {
            let split : Iter.Iter<Text> = Text.split(request.url, #char '?');
            var key : Text = Iter.toArray(split)[0];
            var fileCanisterId : Text = Principal.toText(Principal.fromActor(this));

            let asset : ?AssetBlob = assetsBlob.get(key);

            switch (asset) {
                case (?{ content_type : Text; encoding : AssetEncodingBlob }) {
                    return {
                        body = Blob.toArray(encoding.content_chunks[0]);
                        headers = [
                            ("Content-Type", content_type),
                            ("accept-ranges", "bytes"),
                            ("cache-control", "private, max-age=0"),
                        ];
                        status_code = 200;
                        streaming_strategy = create_strategy(
                            key,
                            fileCanisterId,
                            0,
                            encoding,
                        );
                    };
                };
                case null {};
            };
        };
        return {
            body = Blob.toArray(Text.encodeUtf8("Resources not found"));
            headers = [];
            status_code = 403;
            streaming_strategy = null;
        };
    };

    private func create_strategy(
        key : Text,
        fileCanisterId : Text,
        index : Nat,
        encoding : AssetEncodingBlob,
    ) : ?StreamingStrategy {
        switch (create_token(key, index, encoding)) {
            case (null) { null };
            case (?token) {
                let canister = actor (fileCanisterId) : actor {
                    http_request_streaming_callback : shared () -> async ();
                };
                return ? #Callback({
                    token;
                    callback = canister.http_request_streaming_callback;
                });
            };
        };
    };

    public query func http_request_streaming_callback(st : StreamingCallbackToken) : async StreamingCallbackHttpResponse {
        switch (assetsBlob.get(st.key)) {
            case (null) throw Error.reject("Key not found: " # st.key);
            case (?asset) {
                return {
                    token = create_token(st.key, st.index, asset.encoding);
                    body = Blob.toArray(asset.encoding.content_chunks[st.index]);
                };
            };
        };
    };

    private func create_token(
        key : Text,
        chunk_index : Nat,
        encoding : AssetEncodingBlob,
    ) : ?StreamingCallbackToken {
        if (chunk_index + 1 >= encoding.content_chunks.size()) {
            null;
        } else {
            ?{
                key;
                index = chunk_index + 1;
                content_encoding = "gzip";
            };
        };
    };

    public shared (msg) func create_batch() : async { batch_id : Nat } {
        assert (msg.caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),msg.caller)));
        nextBatchID := nextBatchID + 1;
        var batch_id : Nat = nextBatchID;
        return { batch_id };
    };

    public shared (msg) func create_chunk(chunk : Chunk) : async {
        chunk_id : Nat;
    } {
        assert (msg.caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),msg.caller)));
        nextChunkID := nextChunkID + 1;
        chunks.put(nextChunkID, chunk);
        var chunk_id : Nat = nextChunkID;
        return { chunk_id };
    };

    public shared (msg) func clear_chunk() : async (Bool) {
        assert (msg.caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),msg.caller)));
        chunks := HashMap.HashMap<Nat, Chunk>(1, Nat.equal, Hash.hash);
        return true;
    };

    public shared (msg) func max_file_size(size : Nat) : async Result.Result<Text, Text> {
        assert (msg.caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),msg.caller)));
        MAX_FILE_SIZE := size;
        return #ok("Success");
    };

    public query func chunk_size() : async (Nat) {
        return chunks.size();
    };

    public shared (msg) func commit_chunk({
        batch_id : Nat;
        chunk : Chunk;
        content_type : Text;
    }) : async () {
        assert (msg.caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),msg.caller)));
        
        var content_chunks_list = Buffer.Buffer<Blob>(0);
        var total_length = chunk.content.size();
        content_chunks_list.add(Blob.fromArray(chunk.content));

        var content_chunks : [Blob] = Buffer.toArray(content_chunks_list);

        assert (content_chunks.size() > 0);
        assert (total_length <= MAX_FILE_SIZE);

        assetsBlob.put(
            Text.concat("/", Nat.toText(batch_id)),
            {
                content_type = content_type;
                encoding = {
                    modified = Time.now();
                    content_chunks;
                    certified = false;
                    total_length;
                };
            },
        );
        nextBatchID := batch_id;
    };

    public shared (msg) func commit_batch(
        { batch_id : Nat; chunk_ids : [Nat]; content_type : Text } : {
            batch_id : Nat;
            content_type : Text;
            chunk_ids : [Nat];
        }
    ) : async () {

        assert (msg.caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),msg.caller)));

        var content_chunks_list = Buffer.Buffer<Blob>(0);
        var total_length = 0;
        for (chunk_id in chunk_ids.vals()) {
            let chunk : ?Chunk = chunks.get(chunk_id);

            switch (chunk) {
                case (?{ content }) {
                    total_length += content.size();
                    content_chunks_list.add(Blob.fromArray(content));
                };
                case null {};
            };
            let removed = chunks.remove(chunk_id);
        };

        var content_chunks : [Blob] = Buffer.toArray(content_chunks_list);

        assert (content_chunks.size() > 0);
        assert (total_length <= MAX_FILE_SIZE);

        assetsBlob.put(
            Text.concat("/", Nat.toText(batch_id)),
            {
                content_type = content_type;
                encoding = {
                    modified = Time.now();
                    content_chunks;
                    certified = false;
                    total_length;
                };
            },
        );
    };

    public shared ({caller}) func check_file_id() : async [Text]{
        assert (caller == ledger_canister_id or (await IC0Utils.isController(Principal.fromActor(this),caller)));
        Iter.toArray<Text>(assetsBlob.keys());
    };

    public query ({ caller }) func query_cycle_balance() : async Nat {
        ExperimentalCycles.balance();
    };

    //State functions
    system func preupgrade() {
        assetsEntriesBlob := Iter.toArray(assetsBlob.entries());
    };
    system func postupgrade() {
        assetsEntriesBlob := [];
    };
};
