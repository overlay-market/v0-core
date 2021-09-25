from brownie import reverts, chain
from brownie.test import given, strategy
from hypothesis import settings


def print_events(tx):
    for i in range(len(tx.events['log'])):
        print(
            tx.events['log'][i]['k'] + ": "
            + str(tx.events['log'][i]['v'])
        )


MIN_COLLATERAL = 1e14  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18


@given(
    collateral=strategy('uint256', min_value=MIN_COLLATERAL,
                        max_value=OI_CAP - 1e4),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
@settings(max_examples=1)
def test_build(
    ovl_collateral,
    token,
    mothership,
    market,
    bob,
    rewards,
    collateral,
    leverage,
    is_long
):

    print("test build", token)

    updated = market.updated()
    updatePeriod = market.updatePeriod()
    chain.mine(timestamp=updated + updatePeriod)

    market.update({'from': bob})

    oi = collateral * leverage
    fee = mothership.fee()
    fee_perc = fee / 1e18

    # # prior token balances
    prior_balance_ovl_collateral = token.balanceOf(ovl_collateral)
    prior_balance_trader = token.balanceOf(bob)

    # prior oi state
    prior_queued_oi_long = market.queuedOiLong()
    prior_queued_oi_short = market.queuedOiShort()
    prior_oi_long = market.oiLong()
    prior_oi_short = market.oiShort()

    # prior fee state
    prior_fees = ovl_collateral.fees()

    # prior price info
    prior_price_point_idx = market.pricePointCurrentIndex()
    prior_price = market.pricePoints(prior_price_point_idx - 1)

    # adjust for build fees
    oi_adjusted = int(oi * (1 - fee_perc))
    collateral_adjusted = int(oi_adjusted / leverage)
    debt_adjusted = oi_adjusted - collateral_adjusted
    fee_adjustment = oi - oi_adjusted

    # approve collateral contract to spend bob's ovl to build position
    token.approve(ovl_collateral, collateral, {"from": bob})

    print("market", market)
    print("collateral", collateral)
    print("is long", is_long)
    print("leverage", leverage)
    print("bob", bob)
    print("ovl collateral", ovl_collateral)

    # build the position
    tx = ovl_collateral.build(
        market,
        collateral,
        leverage,
        is_long,
        {"from": bob}
    )

    print_events(tx)

    assert 'Build' in tx.events
    assert 'positionId' in tx.events['Build']
    pid = tx.events['Build']['positionId']

    print("pid", pid)

    # TODO: Fix for precision and not with +1 in rounding ...
    assert abs(tx.events['Build']['oi'] - oi_adjusted) <= 1
    assert abs(tx.events['Build']['debt'] - debt_adjusted) <= 1

    # check collateral transferred from bob's address
    expected_balance_trader = prior_balance_trader - collateral
    # mints debt to contract + additional collateral sent from trader
    expected_balance_ovl_collateral = prior_balance_ovl_collateral + collateral
    assert token.balanceOf(bob) == expected_balance_trader
    assert token.balanceOf(ovl_collateral) == expected_balance_ovl_collateral

    # # check shares of erc 1155 match contribution to oi
    # curr_shares_balance = ovl_collateral.balanceOf(bob, pid)
    # assert (
    #     curr_shares_balance == oi_adjusted
    #     or curr_shares_balance == oi_adjusted + 1
    # )

    # # check position info
    # # info = (isLong, leverage, pricePoint, oiShares, debt, cost)
    # info = ovl_collateral.positions(pid)
    # assert info[0] == market.address
    # assert info[1] == is_long
    # assert info[2] == leverage
    # assert info[3] == prior_price_point_idx
    # assert abs(info[4] - oi_adjusted) <= 1
    # assert abs(info[5] - debt_adjusted) <= 1
    # assert abs(info[6] - collateral_adjusted) <= 1

    # # oi aggregates should be unchanged as build settles at T+1
    # curr_oi_long = market.oiLong()
    # curr_oi_short = market.oiShort()
    # assert prior_oi_long == curr_oi_long
    # assert prior_oi_short == curr_oi_short

    # # queued oi aggregates should increase prior to T+1 tho
    # expected_queued_oi_long = (
    #     prior_queued_oi_long + oi_adjusted
    #     if is_long else prior_queued_oi_long
    # )
    # expected_queued_oi_short = (
    #     prior_queued_oi_short + oi_adjusted
    #     if not is_long else prior_queued_oi_short
    # )
    # curr_queued_oi_long = market.queuedOiLong()
    # curr_queued_oi_short = market.queuedOiShort()
    # assert abs(curr_queued_oi_long - expected_queued_oi_long) <= 1
    # assert abs(curr_queued_oi_short - expected_queued_oi_short) <= 1

    # # check position receives current price point index ...
    # current_price_point_idx = market.pricePointCurrentIndex()
    # assert current_price_point_idx == prior_price_point_idx

    # # ... and price hasn't settled
    # with reverts(''):
    #     market.pricePoints(current_price_point_idx)

    # assert market.pricePoints(current_price_point_idx - 1) == prior_price

    # # check fees assessed and accounted for in fee bucket
    # # +1 with or rounding catch given fee_adjustment var definition
    # expected_fees = prior_fees + fee_adjustment
    # # curr_fees = ovl_collateral.fees()
    # # assert (
    # #     curr_fees == expected_fees
    # #     or curr_fees == expected_fees - 1
    # # )


def test_build_breach_min_collateral(token, market, bob):
    pass


def test_build_breach_max_leverage(token, market, bob):
    pass


@given(
    oi=strategy('uint256',
                min_value=1.01*OI_CAP*10**TOKEN_DECIMALS, max_value=2**144-1),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build_breach_cap(token, mothership, ovl_collateral, market, bob, oi, leverage, is_long):
    collateral = int(oi / leverage)
    token.approve(ovl_collateral, collateral, {"from": bob})
    with reverts("OVLV1:collat<min"):
        ovl_collateral.build(market, collateral, is_long,
                             leverage, {"from": bob})
