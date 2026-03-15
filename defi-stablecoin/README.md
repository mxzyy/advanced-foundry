# DeFi Stablecoin (ETHS)

A decentralized, algorithmic stablecoin system built with Foundry. The protocol allows users to deposit crypto collateral (wETH & wBTC) and mint a USD-pegged stablecoin (ETHS) against it — similar to MakerDAO's DAI, but with no governance and no fees.

## How It Works

```
User deposits wETH/wBTC as collateral
        |
        v
DSCEngine calculates collateral value via Chainlink price feeds
        |
        v
User can mint ETHS (1 ETHS = $1) up to 50% of their collateral value
        |
        v
System maintains 200% overcollateralization at all times
        |
        v
Undercollateralized positions can be liquidated (10% bonus to liquidators)
```

### Key Properties

| Property | Detail |
|---|---|
| **Peg** | 1 ETHS = 1 USD |
| **Collateral** | Exogenous (wETH & wBTC) |
| **Stability** | Algorithmic (mint & burn) |
| **Collateralization** | Minimum 200% |
| **Liquidation Bonus** | 10% |
| **Price Feeds** | Chainlink V3 Aggregator |

## Project Structure

```
.
├── src/
│   ├── Coin.sol              # ERC-20 stablecoin token (ETHS)
│   └── DSCEngine.sol          # Core engine: deposit, mint, redeem, liquidate
├── script/
│   ├── Deploy.s.sol           # Deployment script
│   └── HelperConfig.s.sol     # Network config (Sepolia / Anvil)
└── test/
    ├── Coin.t.sol             # Unit tests for ETHS token
    ├── DSCEngineTest.t.sol    # Unit tests for DSCEngine
    ├── Fuzz.t.sol             # Fuzz tests
    ├── Handler.t.sol          # Handler for invariant testing
    ├── Invariant.t.sol        # Invariant/stateful fuzz tests
    └── mocks/
        └── MockV3Aggregator.sol   # Mock Chainlink price feed
```

## Contracts

### `ETHStablecoin` (Coin.sol)
The ERC-20 token contract. Inherits `ERC20Burnable` and `Ownable` from OpenZeppelin. Minting and burning are restricted to the owner (DSCEngine), so the token supply is fully controlled by the protocol logic.

### `DSCEngine` (DSCEngine.sol)
The core protocol logic. Handles:

- **Deposit Collateral** — Lock wETH or wBTC into the protocol
- **Mint ETHS** — Mint stablecoin against deposited collateral
- **Redeem Collateral** — Withdraw collateral (health factor must stay above 1)
- **Burn ETHS** — Burn stablecoin to free up collateral
- **Liquidate** — Liquidate undercollateralized users and earn a 10% bonus
- **Health Factor** — Tracks each user's collateralization ratio to prevent insolvency

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Deploy (Local Anvil)

```shell
anvil
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast
```

### Deploy (Sepolia)

```shell
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Testing

The test suite includes:

- **Unit Tests** — Core functionality for `ETHStablecoin` and `DSCEngine`
- **Fuzz Tests** — Randomized input testing
- **Invariant Tests** — Stateful property-based testing to ensure the protocol always remains overcollateralized

```shell
# Run all tests
forge test

# Run with verbosity
forge test -vvvv

# Run coverage
forge coverage
```

## Built With

- [Foundry](https://book.getfoundry.sh/) — Ethereum development framework
- [OpenZeppelin](https://docs.openzeppelin.com/contracts/) — ERC-20, Ownable, ReentrancyGuard
- [Chainlink](https://docs.chain.link/data-feeds) — Price feed oracles

## Author

**mxzyy**
