import pytest

from brownie import reverts
from brownie.test import given, strategy
from collections import OrderedDict

MIN_COLLATERAL_AMOUNT = 10**4 # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000

@given(
    oi=strategy('uint256', min_value=1.01*OI_CAP*10**TOKEN_DECIMALS, max_value=2**144-1),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build_breach_cap(token, factory, market, bob, oi, leverage, is_long):
    collateral = int(oi / leverage)
    token.approve(market, collateral, {"from": bob})
    with reverts("OverlayV1: breached oi cap"):
        market.build(collateral, is_long, leverage, bob, {"from": bob})
