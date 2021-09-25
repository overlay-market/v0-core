import brownie
from brownie.test import given, strategy
from hypothesis import settings

MIN_COLLATERAL = 1e14  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18
FEE_RESOLUTION = 1e18


@given(
    collateral=strategy('uint256', min_value=1e18,
                        max_value=OI_CAP - 1e4),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
@settings(max_examples=1)
def test_build_success_zero_impact(ovl_collateral, token, mothership, market,
                                   bob, rewards, collateral, leverage,
                                   is_long):
    oi = collateral * leverage
    trade_fee = oi * mothership.fee() / FEE_RESOLUTION

    # get prior state of collateral manager
    fee_bucket = ovl_collateral.fees()
    ovl_balance = token.balanceOf(ovl_collateral)

    # approve collateral contract to spend bob's ovl to build position
    token.approve(ovl_collateral, collateral, {"from": bob})

    # build the position
    tx = ovl_collateral.build(
        market,
        collateral,
        leverage,
        is_long,
        {"from": bob}
    )

    assert 'Build' in tx.events
    assert 'positionId' in tx.events['Build']
    pid = tx.events['Build']['positionId']

    # fees should be sent to fee bucket in collateral manager
    assert fee_bucket + trade_fee == (ovl_collateral.fees())

    # check collateral sent to collateral manager
    assert ovl_balance + collateral == (token.balanceOf(ovl_collateral))

    # check position token issued with correct oi shares
    collateral_adjusted = collateral - trade_fee
    oi_adjusted = collateral_adjusted * leverage
    assert ovl_collateral.balanceOf(bob, pid) == oi_adjusted

    # TODO: check position attributes for PID


def test_build_when_market_not_supported(mothership, market, bob):
    pass


def test_build_breach_min_collateral(token, market, bob):
    pass


def test_build_breach_max_leverage(token, market, bob):
    pass


@given(
    oi=strategy('uint256',
                min_value=1.01*OI_CAP*10**TOKEN_DECIMALS, max_value=2**144-1),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build_breach_cap(token, ovl_collateral, market, bob,
                          oi, leverage, is_long):
    collateral = int(oi / leverage)
    token.approve(ovl_collateral, collateral, {"from": bob})
    with brownie.reverts("OVLV1:>cap"):
        ovl_collateral.build(market, collateral, leverage,
                             is_long, {"from": bob})
