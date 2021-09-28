
import brownie
from brownie.test import given, strategy
from hypothesis import settings
from brownie import chain
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

def test_unwind(ovl_collateral, market, token, bob):

    pass


def test_unwind_revert_insufficient_shares(ovl_collateral, market, bob):

    with brownie.reverts("OVLV1:!shares"):
        ovl_collateral.unwind(
            1,
            1e18,
            { "from": bob }
        );



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

@given(is_long=strategy('bool'))
def test_unwind_from_queued_oi (
    ovl_collateral, 
    bob,
    token,
    market,
    is_long
):
    ''' 
    When compounding period is larger than update period we unwind before 
    compounding period is done and expect the oi to be removed from the 
    queued oi instead of the non queued oi.
    '''

    is_long = True

    update_period = market.updatePeriod()

    tx = ovl_collateral.build(market, 1e18, 1, is_long, { 'from': bob })

    pos_id = tx.events['Build']['positionId']
    pos_oi = tx.events['Build']['oi']

    pos_shares = ovl_collateral.balanceOf(bob, pos_id)

    chain.mine(timedelta=update_period+1)

    q_oi_after_update_period = market.queuedOiLong() if is_long else market.queuedOiShort()

    tx = ovl_collateral.unwind(pos_id, pos_oi, { 'from': bob })

    q_oi_after_unwind = market.queuedOiLong() if is_long else market.queuedOiShort()

    assert q_oi_after_update_period == pos_shares
    assert q_oi_after_unwind == 0


@given(
    collateral=strategy('uint256', min_value=1e16, max_value=1e24),
    leverage=strategy('uint256', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_unwind_from_active_oi(
        ovl_collateral,
        market,
        token,
        bob,
        collateral,
        leverage,
        is_long
):
    '''
    We want to unwind from the queued oi so we only mine the chain to the next
    update period, not further into the compounding period. Then we unwind and 
    verify that the queued oi at zero.
    '''

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

    ovl_collateral.unwind(pid, pshares, { 'from': bob })

    oi_after_unwind = market.oiLong() if is_long else market.oiShort()

    assert oi_before_unwind == build_oi
    assert oi_after_unwind == 0


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