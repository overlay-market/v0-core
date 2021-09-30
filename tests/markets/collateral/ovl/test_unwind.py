import brownie
from brownie.test import given, strategy
from hypothesis import settings
from brownie import chain
from pytest import approx
from decimal import *

OI_CAP = 800000e18
MIN_COLLATERAL=1e14
FEE_RESOLUTION=1e18

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

def get_collateral(collateral, leverage, fee):
    FL = fee*leverage
    fee_offset = MIN_COLLATERAL*(FL/(FEE_RESOLUTION - FL))
    if collateral - fee_offset <= MIN_COLLATERAL:
        return int(MIN_COLLATERAL + fee_offset)
    else:
        return collateral


def test_unwind(ovl_collateral, token, bob):
    pass


def test_unwind_revert_insufficient_shares(ovl_collateral, bob):
    
    EXPECTED_ERROR_MESSAGE = "OVLV1:!shares"
    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.unwind(
            1,
            1e18,
            {"from": bob}
        );


@given(
    is_long=strategy('bool'),
    oi=strategy('uint256', min_value=1, max_value=OI_CAP/1e16),
    leverage=strategy('uint256', min_value=1, max_value=100))
def test_unwind_oi_removed(
        ovl_collateral,
        mothership,
        market,
        token,
        bob,
        alice,
        oi,
        leverage,
        is_long
        ):
    
    # Build parameters
    oi *= 1e16
    collateral = get_collateral(oi / leverage, leverage, mothership.fee())

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
    poi_build = tx_build.events['Build']['oi']

    (_, _, _, price_point, oi_shares_build,
        debt_build, cost_build, p_compounding) = ovl_collateral.positions(pid)

    chain.mine(timedelta=market.updatePeriod()+1)

    assert oi_shares_build > 0
    assert poi_build > 0
    
    # Unwind
    tx_unwind = ovl_collateral.unwind(
        pid,
        oi_shares_build,
        {"from": bob}
    )

    (_, _, _, _, oi_shares_unwind, debt_unwind, cost_unwind, _) =\
        ovl_collateral.positions(pid)

    poi_unwind = tx_unwind.events['Unwind']['oi']

    assert oi_shares_unwind == 0
    assert int(poi_unwind) == approx(int(poi_build))


# WIP
@given(
    is_long=strategy('bool'),
    oi=strategy('uint256', min_value=1, max_value=OI_CAP/1e16),
    leverage=strategy('uint256', min_value=1, max_value=100))
@settings(max_examples=1)
def test_unwind_expected_fee(
    ovl_collateral,
    mothership,
    market,
    token,
    bob,
    oi,
    leverage,
    is_long
):

    # Build parameters
    oi *= 1e16
    collateral = get_collateral(oi / leverage, leverage, mothership.fee())

    # Build
    token.approve(ovl_collateral, collateral, {"from": bob})
    tx_build = ovl_collateral.build(
        market,
        collateral,
        leverage,
        is_long,
        {"from": bob}
    )

    fees_prior = ovl_collateral.fees() / 1e18

    # Position info
    pid = tx_build.events['Build']['positionId']
    pos_shares = tx_build.events['Build']['oi']
    (_, _, _, price_point, oi_shares_pos, debt_pos, _, p_compounding) = ovl_collateral.positions(pid)

    _pos_shares = ovl_collateral.balanceOf(bob, pid)

    print("pos shares", pos_shares)
    print("_pos_shares", _pos_shares)
    print("oi_shares", oi_shares_pos)

    chain.mine(timedelta=market.updatePeriod()+1)
    build_fees = ovl_collateral.fees()
    
    ( oi, oi_shares, price_frame ) = market.positionInfo(is_long, price_point, p_compounding)

    oi /= 1e18
    debt_pos /= 1e18
    oi_shares /= 1e18
    price_frame /= 1e18
    oi_shares_pos /= 1e18


    # Fee calculation
    pos_oi = ( oi_shares_pos * oi ) / oi_shares 

    if is_long:
        val = pos_oi * price_frame 
        val = val - min(val, debt_pos)
    else:
        val = pos_oi *2
        val = val - min(val, debt_pos + pos_oi * price_frame )

    notional = val + debt_pos 

    fee = notional * ( mothership.fee() / 1e18 )

    # Unwind
    tx_unwind = ovl_collateral.unwind(
        pid,
        oi_shares_pos * 1e18,
        {"from": bob}
    )

    (_, _, _, _, oi_shares_unwind, debt_unwind, cost_unwind, _) =\
        ovl_collateral.positions(pid)

    fees_now = ovl_collateral.fees() / 1e18

    assert fee + fees_prior == approx(fees_now), "fees not expected amount"


@given(
    is_long=strategy('bool'),
    oi=strategy('uint256', min_value=1, max_value=OI_CAP/1e16),
    leverage=strategy('uint256', min_value=1, max_value=100))
def test_unwind_after_transfer(
        ovl_collateral,
        mothership,
        market,
        token,
        bob,
        alice,
        oi,
        leverage,
        is_long
        ):
    
    # Build parameters
    oi *= 1e16
    collateral = get_collateral(oi / leverage, leverage, mothership.fee())

    # Bob builds a position
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
    poi_build = tx_build.events['Build']['oi']
    
    (_, _, _, price_point, oi_shares_build,
        debt_build, cost_build, p_compounding) = ovl_collateral.positions(pid)

    chain.mine(timedelta=market.updatePeriod()+1)

    # Confirm that Bob holds a position
    assert oi_shares_build > 0
    assert poi_build > 0

    # Transfer Bob's position to Alice
    ovl_collateral.safeTransferFrom(bob, alice, pid, ovl_collateral.totalSupply(pid), 1, {"from": bob})
    
    # Bob's unwind attempt should fail
    EXPECTED_ERROR_MESSAGE = "OVLV1:!shares"
    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.unwind(
            pid,
            oi_shares_build,
            {"from": bob}
        )


# WIP
# warning, dependent on what the price/mocks do
@given(collateral=strategy('uint256'))
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

@given(
    is_long=strategy('bool'),
    oi=strategy('uint256', min_value=1, max_value=OI_CAP/1e16),
    leverage=strategy('uint256', min_value=1, max_value=100))
def test_unwind_from_queued_oi (
    ovl_collateral, 
    bob,
    token,
    mothership,
    oi,
    leverage,
    market,
    is_long
):
    ''' 
    When compounding period is larger than update period we unwind before 
    compounding period is done and expect the oi to be removed from the 
    queued oi instead of the non queued oi.
    '''

    oi *= 1e16

    collateral = get_collateral(oi / leverage, leverage, mothership.fee())

    is_long = True

    update_period = market.updatePeriod()

    tx = ovl_collateral.build(market, collateral, leverage, is_long, { 'from': bob })

    pos_id = tx.events['Build']['positionId']
    pos_oi = tx.events['Build']['oi']

    pos_shares = ovl_collateral.balanceOf(bob, pos_id)

    chain.mine(timedelta=update_period+1)

    q_oi_after_update_period = market.queuedOiLong() if is_long else market.queuedOiShort()

    tx = ovl_collateral.unwind(pos_id, pos_oi, { 'from': bob })

    q_oi_after_unwind = market.queuedOiLong() if is_long else market.queuedOiShort()

    assert q_oi_after_update_period == pos_shares
    assert approx(q_oi_after_unwind/1e18) == 0


@given(
    oi=strategy('uint256', min_value=1, max_value=OI_CAP/1e16),
    leverage=strategy('uint256', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_unwind_from_active_oi(
        ovl_collateral,
        market,
        token,
        mothership,
        bob,
        oi,
        leverage,
        is_long
):
    '''
    We want to unwind from the queued oi so we only mine the chain to the next
    update period, not further into the compounding period. Then we unwind and 
    verify that the queued oi at zero.
    '''
    oi *= 1e16

    collateral = get_collateral(oi/leverage, leverage, mothership.fee())

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
    build_oi = tx_build.events['Build']['oi']
    pshares = ovl_collateral.balanceOf(bob, pid)

    queued_oi_before = market.queuedOiLong() if is_long else market.queuedOiShort()

    chain.mine(timedelta=market.compoundingPeriod()+1)

    market.update({'from': bob})

    queued_oi_after = market.queuedOiLong() if is_long else market.queuedOiShort()

    assert queued_oi_before == build_oi
    assert queued_oi_after == 0

    oi_before_unwind = market.oiLong() if is_long else market.oiShort()

    tx = ovl_collateral.unwind(pid, pshares, { 'from': bob })

    oi_after_unwind = market.oiLong() if is_long else market.oiShort()

    assert oi_before_unwind == build_oi
    assert oi_after_unwind == 0 or 1

@given(thing=strategy('uint'))
@settings(max_examples=1)
def test_comptroller_recorded_mint_or_burn (
    ovl_collateral, 
    token, 
    market, 
    bob,
    thing
):
    '''
    When we unwind we want to see that the comptroller included however much 
    was minted or burnt from the payout from unwinding the position into its
    brrrrd storage variable.
    '''

    update_period = market.updatePeriod()

    token.approve(ovl_collateral, 1e50, { 'from': bob })

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

    burnt = 0
    minted = 0
    for _, v in enumerate(tx.events['Transfer']):
        if v['to'] == '0x0000000000000000000000000000000000000000':
            burnt = v['value']
        elif v['from'] == '0x0000000000000000000000000000000000000000':
            minted = v['value']

    brrrrd = market.brrrrd()

    if burnt > 0:
        assert brrrrd == -burnt
    else:
        assert minted == brrrrd