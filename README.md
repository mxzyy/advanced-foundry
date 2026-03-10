# Advanced Foundry

A collection of Solidity smart contracts built while following the [Advanced Foundry](https://updraft.cyfrin.io/) course from Cyfrin Updraft by Patrick Collins. Each subproject explores a different area of smart contract development, from token standards to decentralized finance.

## Table of Contents

- [ERC-20 Token](#erc-20-token)
- [ERC-721 NFT](#erc-721-nft)
- [Dynamic ERC-721 NFT](#dynamic-erc-721-nft)
- [DeFi Stablecoin](#defi-stablecoin)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Acknowledgments](#acknowledgments)

## ERC-20 Token

A minimal ERC-20 token implementation using OpenZeppelin.

**Key Contracts:**

- **`Token`** (`erc-20/src/Token.sol`) — Extends `ERC20` from OpenZeppelin. Mints an initial supply of 1,000,000 tokens to the deployer on construction. Name and symbol are passed as constructor arguments.
- **`DeployTokenScript`** (`erc-20/script/Deploy.s.sol`) — Foundry deployment script that deploys the token with the name "Token" and symbol "TK".

**Tests** cover deployment verification, initial supply validation, transfers, and allowance/approval mechanics.

## ERC-721 NFT

A basic NFT contract with URI storage for per-token metadata.

**Key Contracts:**

- **`NFT`** (`erc-721/src/NFT.sol`) — Extends `ERC721URIStorage`. Provides a `mint` function that accepts a recipient address and a token URI (e.g., an IPFS link), auto-increments the token ID, and mints the NFT with associated metadata.
- **`DeployNFT`** (`erc-721/script/Deploy.s.sol`) — Deploys the NFT contract with the name "MyNFT" and symbol "MNFT".

**Tests** verify minting, ownership assignment, and correct token URI storage.

## Dynamic ERC-721 NFT

An NFT contract where token metadata can be updated after minting.

**Key Contracts:**

- **`DynamicNFT`** (`dynamic-erc-721/src/DNFT.sol`) — Extends `ERC721URIStorage`. Separates minting and metadata assignment into two distinct functions: `mint` creates the token, and `setTokenURI` sets or updates its metadata URI. This allows the NFT's metadata to change over time.

**Notable Patterns:**

- Decoupled minting and metadata — demonstrates the concept of dynamic/evolving NFTs where on-chain or off-chain conditions can trigger metadata updates.

**Tests** cover deployment, minting with URI assignment, and updating the token URI to a new value.

## DeFi Stablecoin

The most substantial subproject — a decentralized, algorithmically stable, exogenously collateralized stablecoin system. Loosely modeled after MakerDAO's DAI.

**Key Contracts:**

- **`ETHStablecoin`** (`defi-stablecoin/src/Coin.sol`) — The ERC-20 stablecoin token (symbol: ETHS), pegged 1:1 to USD. Extends `ERC20Burnable` and `Ownable`. Only the owner (the DSCEngine) can mint and burn tokens. Includes input validation with custom errors.
- **`DSCEngine`** (`defi-stablecoin/src/DSCEngine.sol`) — The core protocol engine that manages all stablecoin logic:
  - **Collateral Management** — Users deposit wETH or wBTC as collateral via `depositCollateral`.
  - **Minting & Burning** — Users mint ETHS against their collateral (`mintDsc`) and burn it to free collateral (`burnDsc`). A convenience function `depositCollateralAndMintDsc` handles both in one transaction.
  - **Health Factor** — Tracks each user's collateralization ratio. The system enforces 200% overcollateralization (liquidation threshold of 50%). Users whose health factor drops below 1 are eligible for liquidation.
  - **Liquidation** — Third parties can liquidate undercollateralized positions via `liquidate`, receiving a 10% bonus on the collateral seized.
  - **Price Feeds** — Uses Chainlink `AggregatorV3Interface` to fetch real-time USD prices for collateral tokens.
- **`HelperConfig`** (`defi-stablecoin/script/HelperConfig.s.sol`) — Network-aware configuration that provides Sepolia addresses for production or deploys mock price feeds and ERC-20 tokens for local Anvil testing.
- **`MockV3Aggregator`** (`defi-stablecoin/test/mocks/MockV3Aggregator.sol`) — A mock Chainlink price feed used in tests, allowing price manipulation to simulate market conditions (e.g., testing liquidation scenarios).
- **`DeployScript`** (`defi-stablecoin/script/Deploy.s.sol`) — Deploys both the stablecoin and engine, then transfers token ownership to the engine.

**Notable Patterns:**

- Reentrancy protection via OpenZeppelin's `ReentrancyGuard`
- CEI (Checks-Effects-Interactions) pattern throughout
- Health factor-based liquidation with bonus incentives
- Multi-collateral support (wETH + wBTC) with Chainlink price oracles
- Network-conditional deployment (Sepolia vs. local Anvil)

**Tests** are comprehensive, covering constructor validation, price feed calculations, collateral deposits, minting/burning, redemption, health factor math, liquidation (both valid and invalid attempts), and view function correctness.

## Tech Stack

- **[Foundry](https://book.getfoundry.sh/)** — Build, test, and deploy framework (`forge`, `cast`, `anvil`)
- **Solidity** `^0.8.20` / `^0.8.26`
- **[OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)** — ERC-20, ERC-721, ERC20Burnable, Ownable, ReentrancyGuard, ERC20Mock
- **[Chainlink](https://docs.chain.link/)** — `AggregatorV3Interface` for price feeds

## Getting Started

Each subproject is a standalone Foundry project. Navigate into a subproject directory to build and test:

```bash
# Build
cd erc-20        # or erc-721, dynamic-erc-721, defi-stablecoin
forge build

# Run tests
forge test

# Run tests with verbose output
forge test -vvv
```

## Acknowledgments

This repository was built while following the **[Cyfrin Updraft Advanced Foundry](https://updraft.cyfrin.io/)** course by **Patrick Collins**. Full credit to Patrick and the Cyfrin team for the course material and project design.
