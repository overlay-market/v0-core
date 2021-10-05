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
@settings(max_examples=1)
def test_funding_one_side(
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

  expected_oi = ( oi / 1e18 ) - ( ( oi / 1e18 ) * FEE )

  print("k", K)

  print("expected oi", expected_oi)

  expected_funding_factor = ( 1 - (2 * K) ) ** compoundings

  print("expected funding factor", expected_funding_factor)

  expected_oi_after_payment = expected_oi * expected_funding_factor

  expected_funding_payment = expected_oi - expected_oi_after_payment

  print("expected funding payment", expected_funding_payment)

  tx_build = ovl_collateral.build(
    market,
    oi,
    1,
    is_long,
    { 'from': bob }
  )

  print("tx build events", tx_build.events)

  oi_queued = ( market.queuedOiLong() if is_long else market.queuedOiShort() ) / 1e18

  print("oi queued", oi_queued)

  oiLong, oiShort, oiLongShares, oiShortShares, queuedOiLong, queuedOiShort = market.oi()

  print("thing", oiLong, oiShort, oiLongShares, oiShortShares, queuedOiLong, queuedOiShort )

  assert oi_queued == expected_oi, 'queued oi different to expected'

  chain.mine(timedelta=COMPOUND_PERIOD)

  update_tx = market.update({ 'from': bob })

  print("update_tx_events", update_tx.events)

  oi_unqueued = ( market.oiLong() if is_long else market.oiShort() ) / 1e18

  assert oi_unqueued == expected_oi, 'unequeued oi different than expected'

  chain.mine(timedelta=COMPOUND_PERIOD * compoundings)

  tx_update = market.update({ 'from': bob })

  funding_payment = tx_update.events['FundingPaid']['fundingPaid'] / 1e18

  if is_long: funding_payment = -funding_payment

  assert expected_funding_payment == approx(funding_payment), 'funding payment different than expected'

  oi_after_payment = ( market.oiLong() if is_long else market.oiShort() ) / 1e18

  assert oi_after_payment == approx(expected_oi_after_payment), 'oi after funding payment different than expected'