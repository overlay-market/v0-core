# overlay-v1-core

V1 core smart contracts for the Overlay protocol.

## Contracts

For each feed type, we should have a factory contract that governance uses to deploy all new oracle data feeds to offer as markets, that are associated with that feed type.

Any new feed type we wish to support (e.g. Mirin, Chainlink, UniswapV3), should have a similar setup. A factory contract to deploy the market contract for each new feed and stores all the market contracts offered as a registry and the actual market contract for traders to build/unwind with.


## Requirements

To run the project you need:

- Python >=3.7.2 local development environment
- [Brownie](https://github.com/eth-brownie/brownie) local environment setup
- Set env variables for [Etherscan API](https://etherscan.io/apis) and [Infura](https://eth-brownie.readthedocs.io/en/stable/network-management.html?highlight=infura%20environment#using-infura): `ETHERSCAN_TOKEN` and `WEB3_INFURA_PROJECT_ID`
- Local Ganache environment installed


## Compile

```
brownie compile
```


## Test

```
brownie test
```
