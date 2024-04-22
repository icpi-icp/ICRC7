module {
    public type HeaderField = (Text, Text);

    public type Chunk = {
        batch_id : Nat;
        content : [Nat8];
    };

    public type HttpRequest = {
        url : Text;
        method : Text;
        body : [Nat8];
        headers : [HeaderField];
    };

    public type HttpResponse = {
        body : [Nat8];
        headers : [HeaderField];
        status_code : Nat16;
        streaming_strategy : ?StreamingStrategy;
    };

    public type StreamingStrategy = {
        #Callback : {
            token : StreamingCallbackToken;
            callback : shared () -> async ();
        };
    };

    public type StreamingCallbackToken = {
        key : Text;
        index : Nat;
        content_encoding : Text;
    };

    public type StreamingCallbackHttpResponse = {
        body : [Nat8];
        token : ?StreamingCallbackToken;
    };

    public type AssetEncoding = {
        modified : Int;
        content_chunks : [[Nat8]];
        total_length : Nat;
        certified : Bool;
    };

    public type Asset = {
        encoding : AssetEncoding;
        content_type : Text;
    };

    public type AssetEncodingBlob = {
        modified : Int;
        content_chunks : [Blob];
        total_length : Nat;
        certified : Bool;
    };

    public type AssetBlob = {
        encoding : AssetEncodingBlob;
        content_type : Text;
    };

    public type CommitBatchArg = {
        batch_id : Nat;
        content_type : Text;
        chunk_ids : [Nat];
    };

    public type FileInterface = actor {
        create_batch : shared () -> async {batch_id : Nat};
        create_chunk : shared (Chunk) -> async {chunk_id : Nat};
        commit_batch : shared (CommitBatchArg) -> async ();
        http_request : query (HttpRequest) -> async HttpResponse; 
    }
}