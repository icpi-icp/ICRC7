#!/bin/bash

env=$1

deploy(){

  if [ "$env" == "local" ]; then
        echo "local"
        dfx stop
        dfx start --background
  fi

  dfx identity new icrc7-minting-account
  dfx identity new icrc7-nft-owner
  dfx identity use icrc7-minting-account
  minting_account=$(dfx identity get-principal)

  #deploy_canister_cycle is a cycle number parameter used when creating a child canister inside the ledger. If it is not explicitly specified, the default value is used: 1.86T
  dfx deploy --network=$env icrc7 --argument="( record {                     
      name = \"$name\";                         
      symbol = \"$symbol\";    
      logo = \"$logo\";  
      description = \"$description\";                     
      supply_cap = 10;                       
      minting_account = opt record {owner = principal \"$minting_account\"; subaccount = null;};                                 
      advanced_settings = null;
      deploy_canister_cycle = null;                               
  })"
}


deploy
