from brownie import chain
from brownie.test import given, strategy 
from hypothesis import settings
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))


def test_set_impact_window(
  market,
  gov,
):
  # test updating _impactWindow only in setComptrollerParams func
  input_impact_window = 601

  # record initial values
  initial_static_cap = market.oiCap()
  initial_lmbda = market.lmbda()
  initial_brrrrFade = market.brrrrFade()

  market.setComptrollerParams(
    input_impact_window,
    initial_static_cap,
    initial_lmbda,
    initial_brrrrFade,
    {"from": gov}
  )

  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrrFade = market.brrrrFade()

  # test current impact window equals input value
  assert int(current_impact_window) == int(input_impact_window)

  # test other params are unchanged
  assert int(current_static_cap) == int(initial_static_cap)
  assert int(current_lmbda) == int(initial_lmbda)
  assert int(current_brrrrFade) == int(initial_brrrrFade)


def test_set_static_cap(
  market,
  gov
):
  # test updating _staticCap only in setComptrollerParams func
  input_static_cap = int(800000 * 1e19)

  initial_impact_window = market.impactWindow()
  initial_lmbda = market.lmbda()
  initial_brrrrFade = market.brrrrFade()

  market.setComptrollerParams(
    initial_impact_window,
    input_static_cap,
    initial_lmbda,
    initial_brrrrFade,
    {"from": gov}
  )

  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()

  current_lmbda = market.lmbda()
  current_brrrrFade = market.brrrrFade()

  # test current static cap equals input value
  assert int(current_static_cap) == int(input_static_cap)

  # test other params are unchanged
  assert int(current_impact_window) == int(initial_impact_window)
  assert int(current_lmbda) == int(initial_lmbda)
  assert int(current_brrrrFade) == int(initial_brrrrFade)


def test_brrrr_fade(
  market,
  gov
):
  # test updating _brrrrFade only in setComptrollerParams func
  input_brrrr_fade = 1e19

  initial_impact_window = market.impactWindow()
  initial_static_cap = market.oiCap()
  initial_lmbda = market.lmbda()

  market.setComptrollerParams(
    initial_impact_window,
    initial_static_cap,
    initial_lmbda,
    input_brrrr_fade,
    {"from": gov}
  )

  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrr_fade = market.brrrrFade()

  # test current _brrrrFade equals input value
  assert int(current_brrrr_fade) == int(input_brrrr_fade)

  # test other params are unchanged
  assert int(current_impact_window) == int(initial_impact_window)
  assert int(current_static_cap) == int(initial_static_cap)
  assert int(current_lmbda) == int(initial_lmbda)


def test_set_comptroller_params(
  market,
  gov
):
  # set all params of setComptrollerParams func
  input_impact_window = 601
  input_static_cap = int(800000 * 1e19)
  initial_lmbda = market.lmbda()
  input_brrrr_fade = 1e19

  market.setComptrollerParams(
    input_impact_window,
    input_static_cap,
    initial_lmbda,
    input_brrrr_fade,
    {"from": gov}
  )
  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrr_fade = market.brrrrFade()

  # test all variables updated
  assert int(current_impact_window) == int(input_impact_window)

  assert int(current_static_cap) == int(input_static_cap)

  assert int(current_lmbda) == int(initial_lmbda)

  assert int(current_brrrr_fade) == int(input_brrrr_fade)


def test_set_update_period_only(
  market,
  gov
):
    
  input_update_period = 110

  # grab initial _updatePeriod _compoundingPeriod values
  initial_update_period = market.updatePeriod()
  initial_compounding_period = market.compoundingPeriod()

  # set_updatePeriod only, without _compoundingPeriod
  market.setPeriods(input_update_period, initial_compounding_period, {"from": gov})

  # grab current _updatePeriod _compoundingPeriod values
  current_update_period = market.updatePeriod()
  current_compounding_period = market.compoundingPeriod()

  # test _updatePeriod for updated value
  assert int(current_update_period) == int(input_update_period)

  # test _compoundingPeriod did not change
  assert int(current_compounding_period) == int(initial_compounding_period)


def test_set_compounding_period_only(
  market,
  gov
):
    
  input_compounding_period = 660

  # grab initial _compoundingPeriod, _updatePeriod values
  initial_compounding_period = market.compoundingPeriod()
  initial_update_period = market.updatePeriod()

  # set _compoundingPeriod only, without _updatePeriod
  market.setPeriods(initial_update_period, input_compounding_period, {"from": gov})

  # grab current _compoundingPeriod, _updatePeriod values
  current_compounding_period = market.compoundingPeriod()
  current_update_period = market.updatePeriod()

  # test _compoundingPeriod updated to input value
  assert int(current_compounding_period) == int(input_compounding_period)

  # test _updatePeriod is same as initial
  assert int(current_update_period) == int(initial_update_period)


def test_set_update_and_compounding_period(
  market,
  gov
):
    
  input_update_period = 110
  input_compounding_period = 660

  # grab initial _updatePeriod, _compoundingPeriod values
  initial_update_period = market.updatePeriod()
  initial_compounding_period = market.compoundingPeriod()

  # set new _updatePeriod, _compoundingPeriod values
  market.setPeriods(input_update_period, input_compounding_period, {"from": gov})

  # grab updated _updatePeriod, _compoundingPeriod values
  current_update_period = market.updatePeriod()
  current_compounding_period = market.compoundingPeriod()

  # test _updatePeriod is updated
  assert int(current_update_period) == int(input_update_period)

  # test _compoundingPeriod is updated
  assert int(current_compounding_period) == int(input_compounding_period)


def test_set_k(
  market,
  gov
):
    
  input_k = 346888760971066

  # TODO: test for different k values via an adjust
  # grab current t0 = k value
  initial_k_value = market.k()

  # update _k value
  market.setK(input_k, {"from": gov})

  # grab updated k value
  updated_k_value = market.k()

  # test if updated k value equals new k value
  assert int(updated_k_value) == int(input_k)


def test_set_spread(
  market,
  gov,
):
  # test for when spread value is updated
  input_spread = .00573e19

  # grab initial spread value
  initial_spread = market.pbnj()

  # set new spread value
  market.setSpread(input_spread, {"from": gov})

  # grab current spread value
  current_spread = market.pbnj()

  # test current spread equals updated input value
  assert int(current_spread) == int(input_spread)


def test_set_price_frame_cap(
  market,
  gov
):
  # test updating price frame cap
  input_price_frame_cap = 5e19

  # grab initial _priceFrameCap
  initial_price_frame_cap = market.priceFrameCap()

  # set new price frame cap
  market.setPriceFrameCap(input_price_frame_cap, {"from": gov})

  # grab current price frame cap
  current_price_frame_cap = market.priceFrameCap()

  # test current price frame cap equals updated input value
  assert int(current_price_frame_cap) == int(input_price_frame_cap)


def test_set_everything(
  market,
  gov
):
  # pass in inputs into setEverything function
  input_k = 346888760971066
  input_price_frame_cap = 5e19
  input_spread = .00573e19
  input_update_period = 110
  input_compounding_period = 660
  input_impact_window = 601
  input_static_cap = int(800000 * 1e19)
  input_brrrr_fade = 1e19

  initial_lmbda = market.lmbda()

  market.setEverything(
    input_k,
    input_price_frame_cap,
    input_spread,
    input_update_period,
    input_compounding_period,
    input_impact_window,
    input_static_cap,
    initial_lmbda,
    input_brrrr_fade,
    {"from": gov}
  )

  # grab all current variables
  current_k = market.k()
  current_price_frame_cap = market.priceFrameCap()
  current_spread = market.pbnj()
  current_update_period = market.updatePeriod()
  current_compounding_period = market.compoundingPeriod()
  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrr_fade = market.brrrrFade()

  # test all current values to be updated
  assert int(current_k) == int(input_k)

  assert int(current_price_frame_cap) == int(input_price_frame_cap)

  assert int(current_spread) == int(input_spread)

  assert int(current_update_period) == int(input_update_period)

  assert int(current_compounding_period) == int(input_compounding_period)

  assert int(current_impact_window) == int(input_impact_window)

  assert int(current_static_cap) == int(input_static_cap)

  assert int(current_brrrr_fade) == int(input_brrrr_fade)

  assert int(current_lmbda) == int(initial_lmbda)