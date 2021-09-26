
import brownie
from brownie.test import given, strategy
from hypothesis import settings
from brownie import chain
from decimal import *

MIN_COLLATERAL = 1e14  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18
FEE_RESOLUTION = 1e18


def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))


def test_unwind(ovl_collateral, token, bob):
    pass


def test_unwind_revert_insufficient_shares(ovl_collateral, bob):

    with brownie.reverts("OVLV1:!shares"):
        ovl_collateral.unwind(
            1,
            1e18,
            {"from": bob}
        );


@given(
    collateral=strategy('uint256', min_value=1e18, max_value=OI_CAP - 1e4),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool')
    )
@settings(max_examples=1)
def test_unwind_oi_removed(
        ovl_collateral,
        mothership,
        market,
        token,
        bob,
        alice,
        collateral,
        leverage,
        is_long
        ):

    # Build
    token.approve(ovl_collateral, collateral, {"from": bob})
    tx_build = ovl_collateral.build(
        market,
        collateral,
        leverage,
        is_long,
        {"from": bob}
    )

    # Position info
    pid = tx_build.events['Build']['positionId']
    (_, _, _, price_point, oi_shares_build,
        debt_build, cost_build, p_compounding) = ovl_collateral.positions(pid)

    chain.mine(timedelta=market.updatePeriod()+1)
    oi_long, oi_short = market.oi()

    if is_long:
        assert oi_shares_build > 0
        assert oi_long > 0
        assert oi_short == 0
    else:
        assert oi_shares_build > 0
        assert oi_short > 0
        assert oi_long == 0

    # Unwind
    ovl_collateral.unwind(
        pid,
        oi_shares_build,
        {"from": bob}
    )

    (_, _, _, _, oi_shares_unwind, debt_unwind, cost_unwind, _) =\
        ovl_collateral.positions(pid)

    oi_long, oi_short = market.oi()

    assert oi_shares_unwind == 0
    assert oi_long == 0
    assert oi_short == 0

    


# warning, dependent on what the price/mocks do
def test_unwind_revert_position_was_liquidated(
        ovl_collateral,
        mothership,
        market,
        collateral,
        token,
        bob,
        alice):

    collateral = 2e18
    leverage = 1
    is_long = True

    # token.approve(ovl_collateral, collateral, {"from": bob})
    # tx_build = ovl_collateral.build(
    #     market,
    #     collateral,
    #     leverage,
    #     is_long,
    #     {"from": bob}
    # )

    # with brownie.reverts("OVLV1:!shares"):
    #     ovl_collateral.unwind(
    #         1,
    #         1e18,
    #         { "from": bob }
    #     );

    # build a position
    # liquidate a position
    # try to unwind it and get a revert

    pass


def test_unwind_from_queued_oi (ovl_collateral, bob):
    # when compounding period is larger than update period 
    # we unwind before compounding period is done
    # and expect the oi to be removed from the 
    # queued oi instead of the non queued oi

    pass


def test_that_comptroller_recorded_mint_or_burn (
    ovl_collateral, 
    mothership,
    token, 
    market, 
    bob
):

    update_period = market.updatePeriod()

    # when we unwind, seeing if there was a mint/burn, 
    # and see if the brrrrd variable has recorded it
    tx = ovl_collateral.build(
        market,
        1e18,
        1,
        True,
        { 'from': bob }
    )

    pos_id = tx.events['Build']['positionId']
    bobs_shares = tx.events['Build']['oi']

    chain.mine(timedelta=update_period*2)

    tx = ovl_collateral.unwind(
        pos_id,
        bobs_shares, 
        { "from": bob }
    )

    fee = mothership.fee()

    expected_brrrr = -(Decimal(1) - Decimal(1) * ( Decimal(fee) / Decimal(1e18) ))
    brrrrd = Decimal(market.brrrrd()) / Decimal(1e18)

    assert expected_brrrr == brrrrd



