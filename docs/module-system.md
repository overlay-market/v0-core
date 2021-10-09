# Overlay V1 Core Module System

The module system has two key components:

1. Collaterals Module
2. Markets Module

### Collaterals Module

Collaterals Module consists of collateral managers specializing in different types of collateral. Trader interactions with the system occur through collateral managers. Collateral managers are given mint and burn permissions on the OVL token by the mothership contract.

Each manager has external functions:

- `build()`
- `unwind()`
- `liquidate()`

Currently, we have an OVL Collateral Manager that accepts OVL: collateral/OverlayV1OVLCollateral.sol


##### OverlayV1OVLCollateral.sol:

`build(address _market, uint256 _collateral, uint256 _leverage, bool _isLong):`

- Auth calls `IOverlayV1Market(_market).enterOI()` which queues open interest on the market contract, adjusted for trading and impact fees
- Transfers OVL collateral amount to manager from `msg.sender`
- Returns ERC1155 position token for user's share of the position

`unwind(uint256 _positionId, uint256 _shares):`

- Auth calls `IOverlayV1Market(_market).exitData()` view which returns open interest occupied by position & change in price since entry
- Calculates current value less fees of position being unwound given ERC1155 `_shares`
- Mints `PnL = value - cost` in OVL to collateral manager if PnL > 0 or burns if PnL < 0 from collateral manager
- Transfers value to `msg.sender`
- Auth calls `IOverlayV1Market(_market).exitOI()` which removes open interest from market contract
- Burns ERC1155 position token shares

`liquidate(uint256 _positionId):`

- Auth calls `IOverlayV1Market(_market).exitData()` view which returns open interest occupied by position & change in price since entry
- Checks if position value is less than initial open interest times maintenance margin
- Auth calls `IOverlayV1Market(_market).exitOI()` which removes open interest from market contract
- Zeroes the position's share of total open interest on long or short side
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

- Internal calls `OverlayV1UniswapV3Market.entryUpdate()` which fetches and stores a new price from the oracle and applies funding to the open interest
- Internal calls `OverlayV1Comptroller.intake()` which calculates and records the market impact
- Internal calls `OverlayV1OI.queueOi()` to add the adjusted open interest to the market


`exitData(bool _isLong, uint256 _pricePoint, uint256 _compounding):`

- Internal calls `OverlayV1UniswapV3Market.exitUpdate()` which fetches current and last settlement prices from the oracle and applies funding
- Returns total open interest on side of trade and ratio between exit and entry prices


`exitOI(bool _isLong, bool _fromQueued, uint _oi, uint _oiShares, uint _brrrr, uint _antiBrrrr):`

- Internal calls `OverlayV1Comptroller.brrrr()` which records the amount of OVL minted or burned for trade
- Removes open interest from the long or short side


##### OverlayV1Comptroller.sol:

`intake(bool _isLong, uint _oi):`

- Records in accumulator snapshots `impactRollers` the amount of open interest cap occupied by the trade: `oi / oiCap()`
- Calculates market impact fee `_oi * (1 - e**(-lmbda * (impactRollers[now] - impactRollers[now-impactWindow])))` in OVL burned from collateral manager
- Internal calls `brrrr()` to record the impact fee that will be burned

`brrrr(uint _brrrr, _antiBrrrr):`

- Records in accumulator snapshots `brrrrdRollers` an amount of OVL minted `_brrrr` or burned `_antiBrrrr`

`oiCap():`

- Returns the current dynamic cap on open interest for the market, if less than constraint from `OverlayV1UniswapV3Market.depth()`: `staticCap * min(1, 2 - (brrrrdRollers[now] - brrrrdRollers[now-brrrrdWindowMacro]) / brrrrdExpected)`


##### OverlayV1OI.sol:

`updateFunding(uint _epochs):`

- Internal calls `payFunding()` which pays funding between `__oiLong__` and `__oiShort__`: open interest imbalance is drawn down by `(1-2*k)**(epochs)`
- Internal calls `updateOi()` which transfers queued open interest into `__oiLong__` and `__oiShort__` since now eligible for funding

`queueOi(bool _isLong, uint256 _oi, uint256 _oiCap):`

- Add open interest to either `__queuedOiLong__` or `__queuedOiShort__`
- Checks current open interest cap has not been exceeded: `_oiLong__ + __queuedOiLong__ <= _oiCap` or `_oiShort__ + __queuedOiShort__ <= _oiCap`


##### OverlayV1PricePoint.sol:

`setPricePointCurrent(PricePoint memory _pricePoint):`

- Stores a new historical price in the `_pricePoints` array. Price points include bid and ask values used for entry and exit: `PricePoint{ uint bid; uint ask; uint price }`. Longs receive the ask on entry, bid on exit. Shorts receive the bid on entry, ask on exit.

`insertSpread(uint _microPrice, uint _macroPrice)`

- Calculates bid and ask values given shorter and longer TWAP values fetched from the oracle
- Applies the static spread `pbnj` to bid `e**(-pbnj)` and ask `e**(pbnj)`


##### OverlayV1UniswapV3Market.sol:

`price():`

`depth():`

`entryUpdate():`

`exitUpdate():`



### Nuances:

Queued open interest:

- Queued open interest (`__queuedOiLong__`, `__queuedOiShort__`) is open interest that is not yet eligible for funding. It is transferred over to (`__oiLong__`, `__oiShort__`) after the last `compoundingPeriod` has passed through an internal call to `updateOi()`


Price updates:
