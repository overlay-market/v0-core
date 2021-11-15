# Protocol Overview

Overlay is a protocol that allows users to trade nearly any data stream without the need for traditional counterparties.

The Overlay mechanism allows traders to enter positions by staking Overlay's native token (OVL) as collateral in long or short positions on various data streams offered by the protocol. Data streams are obtained via manipulation-resistant oracles. When a trader exits that same position later, the protocol dynamically mints/burns OVL based on their net profit/loss for the trade to compensate them.

An example: Bob thinks the floor price on PUNK NFTs is not sustainable and will likely go down in ETH terms. He wishes to short the floor. As a trader, Bob enters a short position on the associated Overlay market for the PUNK/ETH floor price feed:

- Bob stakes 100 OVL short at an entry price of 80 ETH for the PUNK/ETH floor

- The PUNK/ETH floor then drops 10 ETH (-12.5%) to 70 ETH over the next week

- Bob unwinds the position to take profit: Overlay mints 12.5 OVL for the PnL and returns a total of 112.5 OVL to Bob for the trade.

If the PUNK floor had gone up 12.5% to 90 ETH, Overlay would burn 12.5 OVL from Bob's stake and return 87.5 OVL back to him.

Overlay V1 Core has three different economic mechanisms to manage the risk associated with excessive inflation of the OVL token supply:

1. Open interest caps: limit the amount of position size a market can take on at any given time

2. Payoff caps: limit the maximum change in price the protocol is willing to honor for any one trade on a market

3. Funding rates: overweight open interest side on a market pays the underweight open interest side to incentivize a drawdown in imbalance over time

To deter front-running the oracle, the protocol adds:

- Bid/ask spread to the price fetched from the oracle feed

- Market impact fee charged on the size of the position entered into

Initial data streams to be offered as markets on Overlay will be Uniswap V3 price feeds (TWAPs).


# Mathematical Models

Updated whitepaper with underlying math can found [here](https://drive.google.com/file/d/1I8uGHwMBg8bPJ4eYrG-5U_WNIDN73TyN/view?usp=sharing).

It is most concerned with addressing the question of how to set risk parameters for each market. In particular, setting governance variables in the general `OverlayMarket.sol` contract for:

- `k`: funding constant
- `pbnj`: bid/ask static spread
- `lmbda`: market impact
- `staticCap`: open interest cap
- `priceFrameCap`: payoff cap
- `brrrrdExpected`: expected worst-case inflation rate

Original whitepaper outlining the vision for the protocol is [here](https://drive.google.com/file/d/1Jhpah-KPvX1C9bxPKxiorxsXmgT8LuMd/view?usp=sharing).


## Profit and Loss

OVL acts as the settlement currency of the system, with all PnL, value, and notional calculations made in OVL terms.

The value of a position that the collateral manager needs to return at unwind is

```
V = OI - D +/- OI * ( priceFrame - 1 )
```

where

- `OI` is the current open interest associated with the position. This can change in time due to funding payments.
- `D` is the debt associated with the position. This is static.
- `priceFrame` is the ratio of the exit price divided by the entry price

The PnL for a position that the collateral manager needs to either mint or burn at unwind is

```
PnL = V - C
```

where `C` is the initial collateral deposited, adjusted for trading fees and market impact.

If `pos.isLong = true`:

```
priceFrame = min(exitPrice / entryPrice, priceFrameCap)
```

- `+/- = +`
- `exitPrice = pricePoint.bid`
- `entryPrice = pricePoint.ask`

and if `pos.isLong = false`:

```
priceFrame = exitPrice / entryPrice
```

- `+/- = -`
- `exitPrice = pricePoint.ask`
- `entryPrice = pricePoint.bid`


### Fees

Market impact and trading fees are charged on the notional amount of the position.

#### build

On `build()`, notional amount on which fees are charged is `collateral * leverage`. Market impact and trading fees adjust the collateral amount backing a position

```
collateralAdjusted = collateral - impactFee - tradeFee
```

Open interest and debt associated with the position then use the adjusted collateral amount

```
oiAdjusted = collateralAdjusted * leverage;
debtAdjusted = oiAdjusted - collateralAdjusted;
```

for position attributes.

#### unwind

On `unwind()`, notional amount on which trading fees are charged is

```
NO = V + D
```

where
- `V` is the value of the position
- `D` is the debt

Value returned on unwind is adjusted only for trading fees (no impact on unwind):

```
valueAdjusted = V - NO * feeRate
```


## Funding and Open Interest

Funding is used to incentivize a drawdown in open interest imbalance over time as the protocol effectively takes on the profit liability associated with an imbalance in open interest.

### Funding Payments

If a `compoundingPeriod` has passed and a call to `update()` on an Overlay market is made, funding is paid from the overweight open interest side of the market to the underweight open interest side:

```
fundingPayment = k * (oiLong - oiShort)
oiLong -= fundingPayment
oiShort += fundingPayment
```

where the payment is made directly between aggregate open interest amounts on a market. If `fundingPayment > 0`, longs pay shorts. If `fundingPayment < 0`, shorts pay longs.

`oiLong` is the total open interest for all outstanding positions on a market on the long side. `oiShort` is the total open interest for all outstanding positions on a market on the short side.

### Shares of Open Interest

Each position tracks its share of the aggregate open interest amounts `(oiLong, oiShort)` through `Position.Info.oiShares`:

```
struct Info {
    address market; // the market for the position
    bool isLong; // whether long or short
    uint leverage; // discrete initial leverage amount
    uint pricePoint; // pricePointIndex
    uint256 oiShares; // shares of total open interest on long/short side, depending on isLong value
    uint256 debt; // total debt associated with this position
    uint256 cost; // total amount of collateral initially locked; effectively, cost to enter position
}
```

The market contract tracks the total of how many open interest shares are currently outstanding through `oiLongShares` and `oiShortShares` in `OverlayV1OI.sol`.

The open interest associated with a full position can then be calculated as

```
oiForLongPosition = oiLong * posLong.oiShares / oiLongShares
oiForShortPosition = oiShort * posShort.oiShares / oiShortShares
```

Traders own shares of the position itself through the ERC-1155 issued by the collateral manager.


## Pricing

For each block in which a call to `update()` of the Overlay markets on UniswapV3 pools is made, the Overlay market contract fetches two TWAPs: one at a shorter averaging window `microWindow` and one at a longer averaging window `macroWindow`.

The `macroWindow` TWAP provides security against spot manipulation after the trader has entered an Overlay position. The `microWindow` TWAP provides security against front-running of the longer TWAP, given the time-weighted average price lags spot by about the same amount of time as the averaging period.

Typical values for the averaging windows would be `macroWindow = 1 hr` and `microWindow = 10 min`.

### Bid-Ask Spread

The trader gets the worst price possible between the two TWAPs. A further static spread is applied to the worse of these two prices to protect against the time lag between the `microWindow` and the "true" spot price.

Bid and ask prices received by traders are

```
bid = min(macroPrice, microPrice) * e**(-pbnj)
ask = max(macroPrice, microPrice) * e**(pbnj)
```

where `pbnj` is the static spread calibrated to cover a majority of likely jumps to occur within the `microWindow`.

Longs get the ask on entry and the bid on exit. Shorts get the bid on entry and the ask on exit.

### Market Impact

A further market impact fee (i.e. slippage) is burned from the position's staked collateral to protect against front-running the time lag between the `microWindow` and spot when the static spread is not enough to cover a very large jump. Market impact limits the damage by charging on position size proposed. It also protects the system from being significantly exploited by traders who may have more information than the Overlay market has.

The market impact fee burned is

```
impactFee = OI * ( 1 - e**(-lmbda * pressure) )
```

where `pressure` is the fraction of the open interest cap that has been recently entered into by positions over the last `impactWindow = microWindow` rolling window

```
pressure = sum_{i} OI_i / oiCap
```

for all positions `i` built between `t = now - impactWindow` and `t = now`. Pressure is calculated using the `impactRollers` rolling accumulator snapshots.


## Open Interest Caps

Open interest caps are used to limit the total exposure the protocol takes on for each market at any given time.

Whenever a new position is built, the market contract through `addOi()` checks whether the additional open interest from the trade, adjusted for impact and fees, will push the aggregate open interest value for the side of the trade above the cap:

```
function addOi(
    bool _isLong,
    uint256 _openInterest,
    uint256 _oiCap
) internal {

    if (_isLong) {

        oiLongShares += _openInterest;

        uint _oiLong = __oiLong__ + _openInterest;

        require(_oiLong <= _oiCap, "OVLV1:>cap");

        __oiLong__ = _oiLong;

    } else {

        oiShortShares += _openInterest;

        uint _oiShort = __oiShort__ + _openInterest;

        require(_oiShort <= _oiCap, "OVLV1:>cap");

        __oiShort__ = _oiShort;

    }

}
```

If so, the build reverts.

### Dynamic Cap

The absolute maximum open interest the market can accept on either the long `oiLong` or short `oiShort` side is dictated by the static governance parameter `staticCap`.

In the event the system has printed more in the recent past than expected, the open interest cap dynamically lowers to take on less new risk in the near future.

The open interest cap is adjusted downward by

```
dynamicCap = staticCap * ( 2 - brrrrdRealized / brrrrdExpected )
```

when `brrrrdRealized > brrrrdExpected`, with a floor at `dynamicCap = 0`.

`brrrrdExpected` is the governance parameter specifying the expected amount of printing over a rolling window `brrrrdWindowMacro`. `brrrrdRealized` is the realized amount printed less burns over the last rolling window

```
brrrrdRealized = sum_{i} brrrrd_i - antiBrrrrd_i
```

for all mints or burns `i` between `t = now - brrrrdWindowMacro` and `t = now`. Realized amount printed in the past is calculated using the `brrrrdRollers` rolling accumulator snapshots.

`intake()` in the comptroller contract registers either a mint `brrrrd` or a burn `antiBrrrrd` on unwind, as well as the impact fee burned on build.


### Depth

Uni V3 and Balancer V2 have a unique manipulation attack vector that we protect against through market impact and open interest caps. A trader could front-run themselves by swapping e.g. DAI => ETH => OVL through the spot pool and immediately using the resulting OVL received as collateral for a long position on the ETH/DAI Overlay market.

Market impact makes this attack unprofitable in all cases if the open interest cap is low enough, so that slippage on the Overlay market is high enough -- lower `oiCap` means higher pressure for same amount of `oi`. To prevent this attack, the open interest cap should be bounded by

```
oiCap <= lmbda * x / 2
```

for Uniswap V3, where `x` is the OVL value of the `token0` reserves in the spot pool. For Balancer V2, where the weights are not necessary the same (`wo != wi`), the constraint is replaced by ``oiCap <= lmbda * x * wo / (wi + wo)`` for `wo <= wi`.

This adjustment is implemented at the `OverlayV1UniswapV3Market.sol` level through a function called `depth()`.


## Liquidations

Positions become liquidatable when the value of the position is less than its initial open interest times a maintenance margin factor

```
V < MM * OI_0
```

This is to protect against positions going negative in value. Any contract or user can call a collateral manager's `liquidate()` function for a position that is liquidatable. Upon liquidation, the liquidator receives a portion of the remaining value as a reward

```
reward = V * MMR;
```

A portion of the remaining value less rewards is burned to account for times when liquidators don't liquidate a negative value position in time -- the `pos.value()` function has a floor of zero so it will never result in negative values. The rest is taken as a fee by the protocol.
