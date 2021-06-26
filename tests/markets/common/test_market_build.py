from brownie import reverts
from brownie.test import given, strategy
from collections import OrderedDict


MIN_COLLATERAL_AMOUNT = 10**4  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
FEE_RESOLUTION = 1e4


@given(
    collateral=strategy('uint256', min_value=MIN_COLLATERAL_AMOUNT, max_value=0.00999*OI_CAP*10**TOKEN_DECIMALS),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build(token, factory, market, bob, collateral, leverage, is_long):
    oi = collateral * leverage
    fee = factory.fee()
    fee_perc = fee / FEE_RESOLUTION

    # prior bob token balance
    prior_balance = token.balanceOf(bob)

    # prior oi state
    prior_queued_oi_long = market.queuedOiLong()
    prior_queued_oi_short = market.queuedOiShort()
    prior_oi_long = market.oiLong()
    prior_oi_short = market.oiShort()

    # adjust for build fees
    oi_adjusted = int(oi * (1 - fee_perc))
    collateral_adjusted = int(oi_adjusted / leverage)
    debt_adjusted = oi_adjusted - collateral_adjusted

    # approve market to spend bob's ovl to build position
    token.approve(market, collateral, {"from": bob})
    # build the position
    tx = market.build(collateral, is_long, leverage, bob, {"from": bob})
    assert 'Build' in tx.events
    assert 'positionId' in tx.events['Build']
    pid = tx.events['Build']['positionId']

    assert tx.events['Build'] == OrderedDict({
        'sender': bob.address,
        'positionId': pid,
        'oi': oi_adjusted,
        'debt': debt_adjusted,
    })

    # check collateral transferred from bob's address
    expected_balance = prior_balance - collateral
    assert token.balanceOf(bob) == expected_balance

    # check shares of erc 1155 match contribution to oi
    assert market.balanceOf(bob, pid) == oi_adjusted or oi_adjusted - 1

    # oi aggregates should be unchanged as build settles at T+1
    curr_oi_long = market.oiLong()
    curr_oi_short = market.oiShort()
    assert prior_oi_long == curr_oi_long
    assert prior_oi_short == curr_oi_short

    # queued oi aggregates should increase prior to T+1 tho
    expected_queued_oi_long = prior_queued_oi_long + oi_adjusted if is_long else prior_queued_oi_long
    expected_queued_oi_short = prior_queued_oi_short + oi_adjusted if not is_long else prior_queued_oi_short
    curr_queued_oi_long = market.queuedOiLong()
    curr_queued_oi_short = market.queuedOiShort()
    assert curr_queued_oi_long == expected_queued_oi_long
    assert curr_queued_oi_short == expected_queued_oi_short

    # TODO: check fees, position attributes, etc. ..


def test_build_breach_min_collateral(token, market, bob):
    pass


def test_build_breach_max_leverage(token, market, bob):
    pass


@given(
    oi=strategy('uint256', min_value=1.01*OI_CAP*10**TOKEN_DECIMALS, max_value=2**144-1),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build_breach_cap(token, factory, market, bob, oi, leverage, is_long):
    collateral = int(oi / leverage)
    token.approve(market, collateral, {"from": bob})
    with reverts("OverlayV1: breached oi cap"):
        market.build(collateral, is_long, leverage, bob, {"from": bob})
