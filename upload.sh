#!/bin/bash
env=$1

upload_file() {
    file_blob= blob ....
    #file id
    file_id=1
    content_type="image/png"
    dfx canister --network=$env call icrc7 commit_chunk "(record{batch_id=$file_id;chunk = record{content = $file_blob;batch_id=$file_id};content_type=\"$content_type\"})"
}

upload_file
