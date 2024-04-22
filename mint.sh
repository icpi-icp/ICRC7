#!/bin/bash

env=$1

mint() {
    dfx identity use icrc7-nft-owner
    nft_owner=$(dfx identity get-principal)
    dfx identity use icrc7-minting-account
    dfx canister --network=$env call icrc7 mint "(
        record{
            to=record {owner=principal \"$nft_owner\"; subaccount=null};
            metadata=vec {
                record {\"name\"; variant {Text=\"name\"}};
                record {\"url\"; variant {Text=\"url\"}};
                record {\"elements\"; variant {Map=vec {
                        record {\"element1\"; variant {Text=\"element1\"}};
                        record {\"element2\"; variant {Text=\"element2\"}}; 
                        record {\"element3\"; variant {Text=\"element3\"}}; 
                        record {\"element4\"; variant {Text=\"element4\"}}; 
                        record {\"element5\"; variant {Text=\"element5\"}}; 
                        record {\"element6\"; variant {Text=\"element6\"}}; 
                        record {\"element7\"; variant {Text=\"element7\"}};
                        }
                    }
                }
            }; 
            memo=null; 
            created_at_time=null;
            token_id=null }
    )"
}
mint
        

        