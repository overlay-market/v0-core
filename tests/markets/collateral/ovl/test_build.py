import brownie
from brownie.test import given, strategy
from hypothesis import settings

MIN_COLLATERAL = 1e14  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18
FEE_RESOLUTION = 1e18


@given(
    collateral=strategy('uint256', min_value=1e18, max_value=OI_CAP - 1e4),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool')
    )
@settings(max_examples=1)
def test_build_success_zero_impact(
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

    oi = collateral * leverage
    trade_fee = oi * mothership.fee() / FEE_RESOLUTION

    # get prior state of collateral manager
    fee_bucket = ovl_collateral.fees()
    ovl_balance = token.balanceOf(ovl_collateral)

    # get prior state of market
    queued_oi = market.queuedOiLong() if is_long else market.queuedOiShort()

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

    # check position attributes for PID
    (pos_market, pos_islong, pos_lev, _, pos_oishares,
     pos_debt, pos_cost, _) = ovl_collateral.positions(pid)

    assert pos_market == market
    assert pos_islong == is_long
    assert pos_lev == leverage
    assert pos_oishares == oi_adjusted
    assert pos_debt == (oi_adjusted - collateral_adjusted)
    assert pos_cost == collateral_adjusted

    # check oi has been queued on the market for respective side of trade
    if is_long:
        assert queued_oi + oi_adjusted == market.queuedOiLong()
    else:
        assert queued_oi + oi_adjusted == market.queuedOiShort()


def test_build_when_market_not_supported(mothership, market, bob):
    pass


@given(
    collateral=strategy('uint256', min_value=2e18, max_value=OI_CAP - 1e4),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool')
    )
@settings(max_examples=1)
def test_build_min_collateral(
    ovl_collateral, 
    token, 
    market, 
    bob,
    collateral,
    leverage,
    is_long
    ):
    
    epsilon = 1e18
    # approve collateral contract to spend bob's ovl to build position
    token.approve(ovl_collateral, collateral, {"from": bob})

    #higher than min collateral passes
    breakpoint()
    ovl_collateral.build(market, MIN_COLLATERAL+epsilon, leverage, is_long, {'from':bob})
    #lower than min collateral fails
    with brownie.reverts('OVLV1:collat<min'):
        ovl_collateral.build(market, MIN_COLLATERAL, leverage, is_long, {'from':bob})


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
