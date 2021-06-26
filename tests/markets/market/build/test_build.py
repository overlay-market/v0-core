
import pytest

from brownie import reverts
from brownie.test import given, strategy
from collections import OrderedDict

MIN_COLLATERAL_AMOUNT = 10**4 # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000

@given(
    collateral=strategy('uint256', min_value=MIN_COLLATERAL_AMOUNT, max_value=0.00999*OI_CAP*10**TOKEN_DECIMALS),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build(token, factory, market, bob, collateral, leverage, is_long):
    oi = collateral * leverage
    oi_aggregate = market.oiLong() if is_long else market.oiShort()

    fee = factory.fee()
    fee_perc = fee / 1e4

    # adjust for build fees
    oi_adjusted = int(oi * (1 - fee_perc))
    collateral_adjusted = int(oi_adjusted / leverage)
    debt_adjusted = ( oi_adjusted - collateral_adjusted ) 

    # approve market to spend bob's ovl to build position
    token.approve(market, collateral, {"from": bob})
    # build the position
    tx = market.build(collateral, is_long, leverage, bob, {"from": bob})
    assert 'Build' in tx.events
    assert 'positionId' in tx.events['Build']
    pid = tx.events['Build']['positionId']
    assert tx.events['Build']['sender'] == bob.address
    assert tx.events['Build']['oi'] == oi_adjusted or oi_adjusted-1 
    assert tx.events['Build']['debt'] == debt_adjusted or debt_adjusted-1 

    # check shares of erc 1155 match contribution to oi
    assert market.balanceOf(bob, pid) == oi_adjusted or oi_adjusted - 1 # or oi_adjusted - 1

    # should be unchanged as build settles at T+1
    oi_aggregate_unsettled = market.oiLong() if is_long else market.oiShort()
    assert oi_aggregate_unsettled == oi_aggregate

    