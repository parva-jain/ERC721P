# ERC721 with permits

This repo contains the implementation of ERC721 with an additional functionality that is permits for NFTs. The permits enables the transfer of token in a single transaction without the need of approval transaction. This is inspired by the [EIP2612](https://eips.ethereum.org/EIPS/eip-2612) which allows user to transfer fungible tokens(ERC 20) using signed message(follows [EIP712](https://eips.ethereum.org/EIPS/eip-712)) without the need of prior approval transaction.

This implementation of Permits links the nonce to the tokenId instead of the owner. This way, it is possible for a same account to create several usable permits at the same time, for different tokens. With each transfer of NFT, the nonce value increments to make sure the permitted account cannot furthur transfer it.

Apart form general functions of ERC 721 standard like __mint_,  __burn_, _transferFrom_ etc, it have function for creating a permit using signature and helper functions to build signature. The __transfer_ function works as same as that of reference implementation but here, it increments the nonce linked to a tokenId every time it is transfered. The description for functions are provided as comments in the code.

## Steps to deploy contracts locally and run tests:

- Clone the repo and open it on any code editor.
- Install the dependencies. On terminal run `npm install`
- Compile the contracts, run `npx hardhat compile`
- Deploy the contracts locally, run `npx hardhat run scripts/sample-script.js`
- For running tests, run `npx hardhat test`


