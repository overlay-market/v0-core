import brownie
from brownie.test import given, strategy
from hypothesis import settings

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
def test_build(ovl_collateral, token, mothership, market, bob,
               rewards, collateral, leverage, is_long):
    oi = collateral * leverage
    fee = mothership.fee()
    fee_perc = fee / 1e18

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

    assert 'Build' in tx.events
    assert 'positionId' in tx.events['Build']
    pid = tx.events['Build']['positionId']

    print("pid", pid)


def test_build_breach_min_collateral(token, market, bob):
    pass


def test_build_breach_max_leverage(token, market, bob):
    pass


@given(
    oi=strategy('uint256',
                min_value=1.01*OI_CAP*10**TOKEN_DECIMALS, max_value=2**144-1),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build_breach_cap(token, mothership, ovl_collateral, market, bob,
                          oi, leverage, is_long):
    collateral = int(oi / leverage)
    token.approve(ovl_collateral, collateral, {"from": bob})
    with brownie.reverts("OVLV1:collat<min"):
        ovl_collateral.build(market, collateral, leverage,
                             is_long, {"from": bob})
