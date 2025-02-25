# FlashMintExecutors

FlashMintExecutors are a suite of smart contracts that enable Index Coop products to be filled via the UniswapX protocol. They dynamically route orders to the appropriate FlashMint contract (for issuance or redemption).

# Deployment Addresses

| Contract | Network | Address |
|----------|---------|---------|
| FlashMintExecutor | Ethereum | [`0x7c5558d2CeB0b988f24FaEcecbb8935bDdDCaeaD`](https://etherscan.io/address/0x7c5558d2ceb0b988f24faececbb8935bdddcaead#code) |
| FlashMintExecutor | Base | [`0x83DFc282de2f17ef7cD365f485Ae549097D9aa5C`](https://basescan.org/address/0x83dfc282de2f17ef7cd365f485ae549097d9aa5c#code) |
| FlashMintExecutor | Arbitrum | [`0x848F19DF5eE44AfcB92a519370223b835Da2120D`](https://arbiscan.io/address/0x848f19df5ee44afcb92a519370223b835da2120d#code) |

# Usage

```
# install dependencies
forge install

# compile contracts
forge build

# run unit tests
forge test
```
