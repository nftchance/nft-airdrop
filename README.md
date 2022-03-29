# Mimetic Airdrops (For ERC-721 and ERC-1155s)

* Note: This code is unaudited and a work of a midnight conversation. If you are going to copy-paste, please take a second to consider the implications of every single line of code.

![Mimetic Airdrops](https://imgur.com/1jcUknw.png)

## Foreword

This token was written in reference to an exploration into different methods of delivering NFT airdrops. There will always be more room for improvement. This repository serves as a proof of concept for Mimetic Airdrops. With Mimetic Airdrops, the owner of a Parent token does not need to technically mint the Child to have full access to the "owner" functions.

You can find the full article releasing the details here: Link to be added once published.

Mimetic Airdrops combine the thinking of three different concepts that are relatively new to the NFT industry.

1. Mimetic Metadata
2. Phantom Minting
3. EIP-2309

EIP-2309 is the secret key here as it allows for Sequential Transferring of an ERC-721s without breaking the standard. The implementation of Mimetic Airdrops is not just limited to 721s, however. ERC-1155s can be used in place as well, and you can find an implementation of both plus tests that will let you get moving.

Please note, every person and project will need to make changes to fit their situation best. While this is a concept that can be copy-pasted, copy-pasting this code will be far more complicated than average without full awareness and understanding of what is taking place in the 721 or 1155 token backend that you've chosen to use.

For so long, airdrops have come at the cost of the existing holders, whether through an incredibly capital-efficient method or the forced cost that comes with minting and all the following actions.

![Ownership Breakdown of Mimetic Airdrops](https://imgur.com/aqRZfsi.png)

With Mimetic Airdrops, the Parent is the default owner of the Child. However, when the Child moves out of the house (is transferred), the actual owner is written to storage for the first time, which is the value that will be used moving forward. With this enabled ownership, Parent owners can utilize all functionalities of the newly deployed contract without having to run a single qualifying transaction. With this, if the Child has not been minted and the Parent is sold, the Child goes to the new owner of the Parent.

Essentially, with Mimetic Metadata, we stop printing new tokens and instead pack the metadata within the same token. All within the control of the holder and project owner without a single massive downside beyond the project creators no longer releasing an asinine amount of tokens into their ecosystem.

## Implementation Documentation

This contract is set up to prevent the need for unlimited token minting.

### When deploying

To deploy a Mimetic Airdrop, the only real difference in the token outside of the ERC implementation is the passing of the "Mirror" contract. The mirror is the contract that will be used for default ownership. Beyond that, the implementations of Mimetic Metadata have only been changed to adopt the standard of their underlying token.

### Force migrating tokens

When the contract is deployed, the creator needs to initialize the current ownership state by emitting the needed Transfer events. The project creator handles all of that, which means the holder does not need to do anything unless they want to. Now, there are certain cases where it makes sense for the holder to mint, and that would be:

* If the new contract has many functions to be called, that need to check the ownership. Having to check the proxy every time for this will make it slightly more expensive per call by approximately $1.

* If a Parent would like to sell their Child when it is sold, the token automatically completes the minting experience during the transfer to the new owner. This all happens in the backend without any holder having to do anything special or unique that they may not be used to.

With this understood, when we are ready to allow forced migration from a direct function call and not a transfer, toggle the state of migration.

## Running The Project

Running the tests for the project is very simple. Combined with the in-contract documentation, you should have everything you need to get rolling. Finally, you, too, can create a genuinely non-dilutive NFT collection.

1. Copy example.env to .env and enter values.
2. Use shell commands below:

```shell
yarn install
npx hardhat test
```

In this test, we are utilizing both 721s and 1155s so that you have the base needed to hit the ground running. Speed has been sacrificed to maintain readability and digestibility. This repository has not been set up for speed; again, this is a repository for illustration purposes of what a better future indeed looks like.

## Author Note

This contract is beyond experimental. Honestly, there is a lot going on here. If you are not familiar with [Mimetic Metadata](https://github.com/nftchance/nft-nondilutive), I first recommend checking that out. Though, inside these contracts, every function has been documented so that you can follow along as usual! Airdrops do not have to be a cost-heavy experience for project creators or holders. Project creators just have to care enough to think about the entire situation at hand.