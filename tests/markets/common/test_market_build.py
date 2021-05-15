import pytest

from brownie.test import given, strategy
from collections import OrderedDict


@given(
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build(token, factory, market, bob, leverage, is_long):
    collateral = 0.01 * market.oiCap()
    oi = collateral * leverage
    oi_aggregate = market.oiLong() if is_long else market.oiShort()

    fee, _, _, fee_resolution, _, _, _, _, _ = factory.getGlobalParams()
    fee_perc = fee / fee_resolution

    # TODO: switch to mint on debt creation model that takes a fee of oi total (so oi adjusted by oi - oi * fee)
    collateral_adjusted = collateral - fee_perc * oi
    oi_adjusted = collateral_adjusted * leverage
    debt_adjusted = collateral_adjusted * (leverage - 1)

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

    # check shares of erc 1155 match contribution to oi
    assert market.balanceOf(bob, pid) == oi_adjusted
    # check market state updated
    oi_aggregate_new = market.oiLong() if is_long else market.oiShort()
    assert oi_aggregate_new == oi_adjusted + oi_aggregate


def test_build_breach_max_leverage(token, market, bob):
    pass


def test_build_breach_cap(token, market, bob):
    pass
