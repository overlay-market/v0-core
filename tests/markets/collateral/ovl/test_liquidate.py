import brownie
import pytest
import datetime
from brownie.test import given, strategy

MIN_COLLATERAL = 1e14  # min amount to build
COLLATERAL = 10*1e18
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18


LIQUIDATE_GROUPINGS = [
    {
        "entry": {"timestamp": 1630074634, "price": 3209262108349973397504},
        "exit": {"timestamp": 1630663957, "price": 3974624759966388977664},
        "collateral": COLLATERAL,
        "leverage": 5,
        "is_long": True,
    },
]


def test_liquidate_success_zero_impact(ovl_collateral, token, mothership,
                                       market, alice, bob, rewards):

    # TODO: make a param passed in via hypothesis to loop through
    grouping = LIQUIDATE_GROUPINGS[0]
    collateral = grouping["collateral"]
    leverage = grouping["leverage"]
    is_long = grouping["is_long"]
    entry_time = grouping["entry"]["timestamp"]
    exit_time = grouping["exit"]["timestamp"]

    # fast forward to time we want for entry
    # TODO: brownie.chain.mine(timestamp=entry_time)

    # market constants
    mm, mm_reward = ovl_collateral.marketInfo(market)
    print('mm', mm)
    print('mm_reward', mm_reward)

    # build a position with leverage
    token.approve(ovl_collateral, collateral, {"from": bob})
    tx_build = ovl_collateral.build(
        market,
        collateral,
        leverage,
        is_long,
        {"from": bob}
    )
    pid = tx_build.events['Build']['positionId']

    print('current_price_idx', market.pricePointCurrentIndex())
    print('last price point',  market.pricePoints(
        market.pricePointCurrentIndex()-1))

    # mine the update period then settle the price
    print('market.compoundingPeriod()', market.compoundingPeriod())
    print('brownie.chain.time()', brownie.chain.time())
    print('brownie.chain.snapshot()', brownie.chain.snapshot())
    brownie.chain.mine(timedelta=market.compoundingPeriod())

    print('brownie.chain.time()', brownie.chain.time())
    print('brownie.chain.snapshot()', brownie.chain.snapshot())

    market.update({"from": rewards})

    print('brownie.chain.time()', brownie.chain.time())
    print('brownie.chain.snapshot()', brownie.chain.snapshot())

    # Get info after settlement
    (_, _, _, entry_price_idx,
        oi_shares, debt, cost, _) = ovl_collateral.positions(pid)
    oi_initial = oi_shares

    print('entry_price_idx', entry_price_idx)
    print('current_price_idx', market.pricePointCurrentIndex())
    print('last price point',  market.pricePoints(
        market.pricePointCurrentIndex()-1))

    # fast forward to time at which should get liquidated
    # TODO: brownie.chain.mine(timestamp=exit_time)

    # get market and manager state prior to liquidation
    oi_long_prior, oi_short_prior = market.oi()

    total_oi_prior = oi_long_prior if is_long else oi_short_prior
    total_oi_shares = market.oiLongShares()\
        if is_long else market.oiShortShares()

    oi = total_oi_prior * oi_shares / total_oi_shares
    value = ovl_collateral.value(pid)

    # get balances  prior
    alice_balance = token.balanceOf(alice)
    ovl_balance = token.balanceOf(ovl_collateral)
    liquidations = ovl_collateral.liquidations()

    ovl_collateral.liquidate(pid, alice, {"from": alice})

    # check oi removed from market
    oi_long, oi_short = market.oi()
    if is_long:
        assert oi_long == oi_long_prior - oi
        assert oi_short == oi_short_prior
    else:
        assert oi_long == oi_long_prior
        assert oi_short == oi_short_prior - oi

    # check loss burned by collateral manager
    loss = cost - value
    assert ovl_balance - loss == token.balanceOf(ovl_collateral)

    # check liquidation condition was actually met: value < oi(0) * mm
    assert value < oi_initial * mm

    # check reward transferred to rewarded
    reward = value * mm_reward
    assert reward + alice_balance == token.balanceOf(alice)

    # check liquidations pot increased
    assert liquidations + (value - reward) == ovl_collateral.liquidations()

    # check position is no longer able to be unwind
    with brownie.reverts("OVLV1:!shares"):
        ovl_collateral.unwind(pid, oi_shares, {"from": bob})


def test_no_unwind_after_liquidate():
    pass
