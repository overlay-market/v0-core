# Overlay V1 Core Module System

The module system has two key components:

1. Collaterals Module
2. Markets Module

### Collaterals Module

Collaterals Module consists of collateral managers specializing in different types of collateral. Trader interactions with the system occur through collateral managers.

Each manager has external functions:
- `build()`
- `unwind()`
- `liquidate()`

Currently, we have an OVL Collateral Manager that accepts OVL: collateral/OverlayV1OVLCollateral.sol


##### OverlayV1OVLCollateral.sol:

`build(address _market, uint256 _collateral, uint256 _leverage, bool _isLong):`

- Auth calls `IOverlayV1Market(_market).enterOI()` which queues open interest on market contract, adjusted for trading and impact fees
- Transfers OVL collateral amount to manager from msg.sender
- Returns ERC1155 position token for user's share of the position

`unwind(uint256 _positionId, uint256 _shares):`

- Auth calls `IOverlayV1Market(_market).exitData()` which returns open interest occupied by position & change in price since entry
- Calculates current value of position being unwound given `_shares` less fees
- Mints `PnL = value - cost` in OVL to collateral manager if PnL > 0 or burns PnL if < 0 from collateral manager
- Transfers value to msg.sender
- Auth calls `IOverlayV1Market(_market).exitOI()` which removes open interest from market contract
- Burns ERC1155 position token shares

`liquidate(uint256 _positionId):`

- Auth calls `IOverlayV1Market(_market).exitData()` which returns open interest occupied by position & change in price since entry
- Checks if position value is less than initial open interest times maintenance margin
- Auth calls `IOverlayV1Market(_market).exitOI()` which removes open interest from market contract
- Zeroes the position's shares of total open interest on long or short side
- Burns `loss = cost - value` in OVL from collateral manager
- Transfers reward to liquidator


### Markets Module


Markets module consists of markets on different data streams.

Each market tracks:

- Total open interest outstanding on long and short sides: `OverlayV1OI.__oiLong__` and `OverlayV1OI.__oiShort__`
- Accumulator snapshots for how much of the open interest cap has been entered into: `OverlayV1Comptroller.impactRollers`
- Accumulator snapshots for how much OVL has been printed: `OverlayV1Comptroller.brrrrdRollers`
- Historical prices fetched from the oracle: `OverlayV1PricePoint._pricePoints`
- Collateral managers approved by governance to add/remove open interest: `OverlayV1Governance.isCollateral`

Each market has external functions accessible only by approved collateral managers:
- `enterOI()`
- `exitData()`
- `exitOI()`

Currently, we have Overlay markets on Uniswap V3 oracles: OverlayV1UniswapV3Market.sol which implements markets/OverlayV1Market.sol


##### OverlayV1Market.sol:


`enterOI(bool _isLong, uint256 _collateral, uint256 _leverage):`

- Internal calls OverlayV1UniswapV3Market.entryUpdate() which fetches and stores a new price from the oracle and applies funding to the open interest
- Internal calls OverlayV1Comptroller.intake() which calculates and records the market impact
- Internal calls OverlayV1OI.queueOi() to add the adjusted open interest to the market


`exitData(bool _isLong, uint256 _pricePoint, uint256 _compounding):`

- Internal calls OverlayV1UniswapV3Market.exitUpdate() which fetches current and last settlement prices from the oracle and applies funding
- Returns total open interest on side of trade and ratio between exit and entry prices


`exitOI(bool _isLong, bool _fromQueued, uint _oi, uint _oiShares, uint _brrrr, uint _antiBrrrr):`

- Internal calls OverlayV1Comptroller.brrrr() which records the amount of OVL minted or burned for trade
- Removes open interest from the long or short side



##### OverlayV1Comptroller.sol:

intake():


brrrr():




##### OverlayV1OI.sol:

updateFunding():

queueOi():

updateOi():



##### OverlayV1PricePoint.sol:

setPricePoint():



##### OverlayV1UniswapV3Market.sol:

price():

depth():

entryUpdate():

exitUpdate():






### Nuances:

Queued open interest:

- Queued open interest (__queuedOiLong__, __queuedOiShort__) is open interest that is not yet eligible for funding. It is transferred over to (__oiLong__, __oiShort__) after the last compoundingPeriod has passed through updateOi()


Price updates:
