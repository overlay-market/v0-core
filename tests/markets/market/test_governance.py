from brownie import chain
from brownie.test import given, strategy 
from hypothesis import settings
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

UPDATE_PERIOD = 101
COMPOUND_PERIOD = 601
LEVERAGE_MAX = 99
K = 343454218783234
PRICE_FRAME_CAP = 5e18 * 1.01
SPREAD = .00573e18 * 1.01

def test_set_impact_window():
  pass


def test_set_static_cap():
  pass


def test_set_lmbda():
  pass


def test_brrrr_fade():
  pass


def test_set_comptroller_params():
  pass


@given(
  update_period=strategy('uint256',
                         min_value = UPDATE_PERIOD,
                         max_value = UPDATE_PERIOD + 100))
@settings(max_examples = 3)
def test_set_update_period_only(
  market,
  gov,
  update_period
):
  # grab initial _updatePeriod _compoundingPeriod values
  initial_update_period = market.updatePeriod()
  initial_compounding_period = market.compoundingPeriod()

  # set_updatePeriod only, without _compoundingPeriod
  market.setPeriods(update_period, initial_compounding_period, {"from": gov})

  # grab current _updatePeriod _compoundingPeriod values
  current_update_period = market.updatePeriod()
  current_compounding_period = market.compoundingPeriod()

  # test _updatePeriod for updated value
  assert int(current_update_period) == int(update_period)

  # test _compoundingPeriod did not change
  assert int(current_compounding_period) == int(initial_compounding_period)


@given(
  compounding_period=strategy('uint256',
                              min_value = COMPOUND_PERIOD,
                              max_value = COMPOUND_PERIOD + 100))
@settings(max_examples = 3)
def test_set_compounding_period_only(
  market,
  gov,
  compounding_period
):
  # grab initial _compoundingPeriod, _updatePeriod values
  initial_compounding_period = market.compoundingPeriod()
  initial_update_period = market.updatePeriod()

  # set _compoundingPeriod only, without _updatePeriod
  market.setPeriods(initial_update_period, compounding_period, {"from": gov})

  # grab current _compoundingPeriod, _updatePeriod values
  current_compounding_period = market.compoundingPeriod()
  current_update_period = market.updatePeriod()

  # test _compoundingPeriod updated to input value
  assert int(current_compounding_period) == int(compounding_period)

  # test _updatePeriod is same as initial
  assert int(current_update_period) == int(initial_update_period)


@given(
  update_period=strategy('uint256',
                          min_value = UPDATE_PERIOD,
                          max_value = UPDATE_PERIOD + 100),
  compounding_period=strategy('uint256',
                              min_value = COMPOUND_PERIOD,
                              max_value = COMPOUND_PERIOD + 100))
@settings(max_examples = 3)
def test_set_update_and_compounding_period(
  market,
  gov,
  update_period,
  compounding_period
):
  # grab initial _updatePeriod, _compoundingPeriod values
  initial_update_period = market.updatePeriod()
  initial_compounding_period = market.compoundingPeriod()

  # set new _updatePeriod, _compoundingPeriod values
  market.setPeriods(update_period, compounding_period, {"from": gov})

  # grab updated _updatePeriod, _compoundingPeriod values
  current_update_period = market.updatePeriod()
  current_compounding_period = market.compoundingPeriod()

  # test _updatePeriod is updated
  assert int(current_update_period) == int(update_period)

  # test _compoundingPeriod is updated
  assert int(current_compounding_period) == int(compounding_period)


@given(
  leverage_max=strategy('uint256',
                        min_value = 1,
                        max_value = LEVERAGE_MAX))
@settings(max_examples = 3)
def test_set_leverage_max(
  market, 
  gov,
  leverage_max
):
  # test updating for new leverage max
  # grab initial leverage max value
  initial_leverage_max = market.leverageMax()

  # set new leverage max
  market.setLeverageMax(leverage_max, {"from": gov})

  updated_leverage_max = market.leverageMax()

  # test if updated leverage max = new one
  assert int(updated_leverage_max) == int(leverage_max)

@given(
  k=strategy('uint256',
             min_value = K,
             max_value = K * 1.05))
@settings(max_examples = 3)
def test_set_k(
  market,
  gov,
  k
):
  # TODO: test for different k values via an adjust
  # grab current t0 = k value
  initial_k_value = market.k()

  # update _k value
  market.setK(k, {"from": gov})

  # grab updated k value
  updated_k_value = market.k()

  # test if updated k value equals new k value
  assert int(updated_k_value) == int(k)


@given(
  spread=strategy('uint256',
                  min_value = SPREAD,
                  max_value = SPREAD * 1.5))
@settings(max_examples = 3)
def test_set_spread(
  market,
  gov,
  spread
):
  # test for when spread value is updated
  # grab initial spread value
  initial_spread = market.pbnj()

  # set new spread value
  market.setSpread(spread, {"from": gov})

  # grab current spread value
  current_spread = market.pbnj()

  # test current spread equals updated input value
  assert int(current_spread) == int(spread)


@given(
  price_frame_cap=strategy('uint256',
                           min_value = PRICE_FRAME_CAP,
                           max_value = PRICE_FRAME_CAP * 1.05))
@settings(max_example = 3)
def test_set_price_frame_cap(
  market,
  gov,
  price_frame_cap
):
  # test updating price frame cap
  # grab initial _priceFrameCap
  initial_price_frame_cap = market.priceFrameCap()

  # set new price frame cap
  market.setPriceFrameCap(price_frame_cap, {"from": gov})

  # grab current price frame cap
  current_price_frame_cap = market.priceFrameCap()

  # test current price frame cap equals updated input value
  assert int(current_price_frame_cap) == int(price_frame_cap)


def test_set_everything(
  k=strategy('uint256',
             min_value = K,
             max_value = K * 1.05),
  leverage_max=strategy('uint256',
                        min_value = 1,
                        max_value = LEVERAGE_MAX),
  price_frame_cap=strategy('uint256',
                           min_value = PRICE_FRAME_CAP,
                           max_value = PRICE_FRAME_CAP * 1.05),
  spread=strategy('uint256',
                  min_value = SPREAD,
                  max_value = SPREAD * 1.5),
  update_period=strategy('uint256',
                          min_value = UPDATE_PERIOD,
                          max_value = UPDATE_PERIOD + 100),
  compounding_period=strategy('uint256',
                              min_value = COMPOUND_PERIOD,
                              max_value = COMPOUND_PERIOD + 100),
):
  pass