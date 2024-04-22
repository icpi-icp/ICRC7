## ICRC7 NFT Standard
    
This repository is implemented based on the ICRC7 standard and has been extended, and is currently implemented in the Motoko language. 

This repository first implements the current standard design of the ICRC7 NFT standard working group, so that the standard can actually run on the IC network. 

Secondly, it also implements a specific plan for unified transaction records based on the already released ICRC3 Block Log standard. 

On the basis of the above ICRC standards, this repository also takes into account the management of virtual assets (i.e. files, not limited to pictures, audio, video, etc.) for NFT usage scenarios. In addition to using blockchain content storage schemes such as IPFS for file storage, artists can also store virtual art files on the IC network, relying only on a single technology stack (IC) scheme to achieve the release management of works of art.

## Deploy

Example

    sh deploy.sh env

Tips

    The env here represents the Canister deployment environment, such as local, ic.
        
## Mint

Example

    sh mint.sh env

Tips

    The env here is consistent with the Deploy link.

## Upload File

Artists who want to manage virtual art assets through the current NFT's Canister can use the file upload function, which supports a single upload of files no larger than 2M.

Example
    
    sh upload.sh env

Tips

    The env here is consistent with the Deploy link.

    You need to read and convert files to Blob format in this shell script.

    If the uploaded file is larger than 2M, it is recommended to divide the file into multiple groups of blobs through a segmented upload scheme. After calling create_chunk multiple times, call commit_batch to submit, forming an integration of files. Before that, you need to call create_batch first to get the id of the uploaded file.

    The preview address of the file points to the address as the url of the NFT, and the casting of the NFT can be completed by calling the mint script.

    Check the id of the file storage canister
        dfx canister --network=$env call icpi7 get_file_canister

    Example of file preview address (with file id as 1 example)
        local : http://$file_canister_id.localhost:4943/1
        ic    : https://$file_canister_id.raw.icp0.io/1


## License

This repository uses the MIT License, so you can learn the specific details.

## Quotes and thanks

The implementation of this repository is inseparable from the group wisdom of the IC community. The basic standards rely on the NFT standard developed by the ICRC7 working group. I heard that it is already waiting for official confirmation. Congratulations to the working group in advance.

The coding idea draws on part of NatLabs/icrc1, the hash calculation refers to skilesare/RepIndyHash, and CertifiedData refers to nomeata/ic-certification.

Thanks to the above teams and developers for their great contributions to the IC ecology, which has also contributed to the actual emergence of this repository.

Artists may have some problems in actual use. Let's improve it together.