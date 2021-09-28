import brownie
import datetime
import pytest
from brownie.test import given, strategy

MIN_COLLATERAL = 1e14  # min amount to build
COLLATERAL = 10*1e18
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18


POSITIONS = [
    {
        "entry": {"timestamp": 1630074634, "price": 3209262108349973397504},
        "exit": {"timestamp": 1630663957, "price": 3974624759966388977664},
        "collateral": COLLATERAL,
        "leverage": 5,
        "is_long": True,
    },
]


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_success_zero_impact(ovl_collateral, token, mothership,
                                       market, alice, bob, rewards,
                                       position):

    # TODO: make a param passed in via hypothesis to loop through
    collateral = position["collateral"]
    leverage = position["leverage"]
    is_long = position["is_long"]
    entry_time = position["entry"]["timestamp"]
    exit_time = position["exit"]["timestamp"]

    # fast forward to time we want for entry
    # TODO: timestamp=entry_time
    brownie.chain.mine(timedelta=10*market.compoundingPeriod())

    # market constants
    maintenance_margin, maintenance_margin_reward = ovl_collateral.marketInfo(
        market)

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

    # Get info after settlement
    (_, _, _, entry_price_idx,
        oi, debt, cost, _) = ovl_collateral.positions(pid)

    print('entry_price_idx', entry_price_idx)
    print('current_price_idx', market.pricePointCurrentIndex())
    print('last price point',  market.pricePoints(
        market.pricePointCurrentIndex()-1))

    # fast forward to time at which should get liquidated
    # TODO: timestamp=exit_time
    brownie.chain.mine(timedelta=10*market.compoundingPeriod())

    # get market and manager state prior to liquidation
    oi_long_prior, oi_short_prior = market.oi()
    value = ovl_collateral.value(pid)

    # get balances  prior
    alice_balance = token.balanceOf(alice)
    ovl_balance = token.balanceOf(ovl_collateral)
    liquidations = ovl_collateral.liquidations()

    # check liquidation condition was actually met: value < oi(0) * mm
    assert value < oi * maintenance_margin
    ovl_collateral.liquidate(pid, alice, {"from": alice})

    # check oi removed from market
    oi_long, oi_short = market.oi()
    if is_long:
        assert pytest.approx(oi_long) == int(oi_long_prior - oi)
        assert pytest.approx(oi_short) == int(oi_short_prior)
    else:
        assert pytest.approx(oi_long) == int(oi_long_prior)
        assert pytest.approx(oi_short) == int(oi_short_prior - oi)

    # check loss burned by collateral manager
    loss = cost - value
    assert int(ovl_balance - loss)\
        == pytest.approx(token.balanceOf(ovl_collateral))

    # check reward transferred to rewarded
    reward = value * maintenance_margin_reward
    assert int(reward + alice_balance) == pytest.approx(token.balanceOf(alice))

    # check liquidations pot increased
    assert int(liquidations + (value - reward))\
        == pytest.approx(ovl_collateral.liquidations())

    # check position is no longer able to be unwind
    with brownie.reverts("OVLV1:!shares"):
        ovl_collateral.unwind(pid, oi, {"from": bob})


def test_no_unwind_after_liquidate():
    pass
