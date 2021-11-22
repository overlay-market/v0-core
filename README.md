# overlay-v1-core

V1 core smart contracts for the Overlay protocol.


## Modules

See [docs/module-system.md](docs/module-system.md) for a detailed explanation of module interactions. Module system diagram in [docs/module-system.pdf](docs/module-system.pdf). Module math in [docs/module-math.md](docs/module-math.md).

V1 Core relies on four modules:

- Collaterals Module
- Markets Module
- OVL Module
- Mothership Module


### Collaterals Module

Collaterals module consists of collateral managers specializing in different types of collateral. Trader interactions with the system occur through collateral managers.

Traders deposit collateral to the specific collateral manager supporting their collateral type. The collateral manager subsequently enters open interest on the market the trader wishes to enter a position on. On exit, collateral managers remove open interest from the market and return collateral to the trader, adjusting for PnL associated with the position. Positions are issued as shares of an ERC1155 by the collateral manager.

Collateral managers are given mint and burn permissions on the OVL token and the ability to enter/exit open interest on markets by the mothership contract.


### Markets Module

Markets module consists of markets on different data streams. Traders do not interact directly with the market contract. Only collateral managers are permitted to interact with market contracts, in order to enter or exit open interest on a market.

Each market tracks:

- Total open interest outstanding on long and short sides
- Accumulator snapshots for how much of the open interest cap has been entered into in the past
- Accumulator snapshots for how much OVL has been printed in the past
- Historical prices fetched from the oracle
- Collateral managers approved by governance to add/remove open interest


### OVL Module

OVL module consists of an ERC20 token with permissioned mint and burn functions. Upon initialization, collateral managers are given permission to mint and burn OVL to compensate traders for their PnL on market positions.


### Mothership Module

Mothership module consists of a mothership contract through which governance can add or remove markets and collateral managers. Access control roles for governance to tune per-market risk parameters are also defined on the mothership contract.



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
