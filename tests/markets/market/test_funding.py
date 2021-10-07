from brownie import chain
from brownie.test import given, strategy
from hypothesis import settings
from pytest import approx
from decimal import *


@given(
    compoundings=strategy('uint256', min_value=1, max_value=100),
    oi=strategy('uint256', min_value=1, max_value=10000),
    is_long=strategy('bool')
)
@settings(max_examples=20)
def test_funding_total_imbalance(
    bob,
    market,
    oi,
    ovl_collateral,
    is_long,
    mothership,
    compoundings
):

    COMPOUND_PERIOD = market.compoundingPeriod()
    FEE = mothership.fee() / 1e18
    K = market.k() / 1e18

    oi *= 1e16

    expected_oi = (oi / 1e18) - ((oi / 1e18) * FEE)

    expected_funding_factor = (1 - (2 * K)) ** compoundings

    expected_oi_after_payment = expected_oi * expected_funding_factor

    expected_funding_payment = expected_oi - expected_oi_after_payment

    tx_build = ovl_collateral.build(
        market,
        oi,
        1,
        is_long,
        {'from': bob}
    )

    oi_queued = (market.queuedOiLong()

                 if is_long else market.queuedOiShort()) / 1e18

    print('oi_queued1: ', oi_queued)
    print('oi_long1: ', market.oiLong())
    print('oi_short1: ', market.oiShort())

    assert oi_queued == approx(expected_oi), 'queued oi different to expected'

    chain.mine(timedelta=COMPOUND_PERIOD)

    print('oi_long2: ', market.oiLong())
    print('oi_short2: ', market.oiShort())

    market.update({'from': bob})

    print('oi_long3: ', market.oiLong())
    print('oi_short3: ', market.oiShort())

    oi_unqueued = (market.oiLong() if is_long else market.oiShort()) / 1e18

    assert oi_unqueued == approx(
        expected_oi), 'unequeued oi different than expected'

    chain.mine(timedelta=COMPOUND_PERIOD * compoundings)

    tx_update = market.update({'from': bob})

    funding_payment = tx_update.events['FundingPaid']['fundingPaid'] / 1e18

    print('funding_payment: ', funding_payment)

    funding_long = tx_update.events['FundingPaid']['oiLong']
    funding_short = tx_update.events['FundingPaid']['oiShort']

    print('funding_long: ', funding_long)

    print('funding_short: ', funding_short)

    if is_long:
        funding_payment = -funding_payment

    assert expected_funding_payment == approx(
        funding_payment), 'funding payment different than expected'

    oi_after_payment = (
        market.oiLong() if is_long else market.oiShort()) / 1e18

    assert oi_after_payment == approx(
        expected_oi_after_payment), 'oi after funding payment different than expected'


@given(
    compoundings=strategy('uint256', min_value=5, max_value=100),
    bob_oi=strategy('uint256', min_value=1, max_value=10000),
    alice_oi=strategy('uint256', min_value=5, max_value=10000),
    is_long=strategy('bool')
)
@settings(max_examples=20)
def test_funding_partial_imbalance(
    market,
    bob,
    alice,
    bob_oi,
    alice_oi,
    ovl_collateral,
    is_long,
    mothership,
    compoundings
):

    COMPOUND_PERIOD = market.compoundingPeriod()
    FEE = mothership.fee() / 1e18
    K = market.k() / 1e18

    bob_oi *= 1e16
    alice_oi *= 1e16

    print('bob_oi: ', bob_oi)
    print('alice_oi: ', alice_oi)
    print('COMPOUND_PERIOD: ', COMPOUND_PERIOD)
    print('FEE: ', FEE)
    print('K: ', K)

    opposite_position_side = (True
                              if is_long != True else False)

    # calculate expected values before queueing up
    bob_expected_oi = (bob_oi / 1e18) - ((bob_oi / 1e18) * FEE)

    alice_expected_oi = (alice_oi / 1e18) - ((alice_oi / 1e18) * FEE)

    expected_funding_factor = (1 - (2 * K))

    expected_funding_payment = (
        bob_expected_oi - (bob_expected_oi * expected_funding_factor)
    ) if (bob_expected_oi > alice_expected_oi) else (
        bob_expected_oi - (bob_expected_oi * expected_funding_factor)
    )

    # Bob & Alice both take opposing positions
    bob_tx_build = ovl_collateral.build(
        market,
        bob_oi,
        1,
        is_long,
        {'from': bob}
    )

    bob_oi_queued = (market.queuedOiLong()
                     if is_long else market.queuedOiShort()) / 1e18

    assert(bob_oi_queued) == approx(bob_expected_oi)

    chain.mine(timedelta=COMPOUND_PERIOD)

    print('bob built, one block passed')
    print('queue_long0: ', market.queuedOiLong())
    print('queue_short0: ', market.queuedOiShort())
    print('oi_long0: ', market.oiLong())
    print('oi_short0: ', market.oiShort())

    tx_update = market.update({'from': bob})

    alice_tx_build = ovl_collateral.build(
        market,
        alice_oi,
        1,
        opposite_position_side,
        {'from': alice}
    )

    alice_oi_queued = (market.queuedOiShort()
                       if is_long else market.queuedOiLong()) / 1e18

    assert(alice_oi_queued) == approx(alice_expected_oi)

    print('alice builds, before other periodz')
    print('queue_long1: ', market.queuedOiLong())
    print('queue_short1: ', market.queuedOiShort())
    print('oi_long1: ', market.oiLong())
    print('oi_short1: ', market.oiShort())

    chain.mine(timedelta=COMPOUND_PERIOD * compoundings)

    tx_update = market.update({'from': bob})

    print('move by amt of compounding periods')
    print('queue_long3: ', market.queuedOiLong())
    print('queue_short3: ', market.queuedOiShort())
    print('oi_long3: ', market.oiLong())
    print('oi_short3: ', market.oiShort())

    funding_payment = tx_update.events['FundingPaid']['fundingPaid'] / 1e18

    funding_long = tx_update.events['FundingPaid']['oiLong'] / 1e18
    funding_short = tx_update.events['FundingPaid']['oiShort'] / 1e18

    print('funding_long: ', funding_long)
    print('funding_short: ', funding_short)
    print('expected_funding_payment: ', expected_funding_payment)
    print('funding_payment: ', funding_payment)

    # test proper funding payments made to correct side
    assert expected_funding_payment == approx(funding_payment)

    pass
