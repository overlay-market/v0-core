from brownie import chain
from brownie.test import given, strategy 
from hypothesis import settings
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

UPDATE_PERIOD = 101
COMPOUND_PERIOD = 601

def set_comptroller_params():
  pass


@given(
  update_period=strategy('uint256',
                         min_value = UPDATE_PERIOD,
                         max_value = UPDATE_PERIOD + 100))
@settings(max_examples=3)
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
@settings(max_examples=3)
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
@settings(max_examples=3)
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


def test_set_leverage_max(market, gov):
  # test updating for new leverage max
  # grab initial leverage max value
  initial_leverage_max = market.leverageMax()

  # set new leverage max
  new_leverage_max = 97
  market.setLeverageMax(new_leverage_max, {"from": gov})

  updated_leverage_max = market.leverageMax()

  # test if updated leverage max = new one
  assert int(updated_leverage_max) == int(new_leverage_max)


def test_set_k(
  market,
  gov,
):
    # TODO: test for different k values via an adjust
    # grab current t0 = k value
    initial_k_value = market.k()

    # update _k value
    new_k_value = 343454218783269
    market.setK(new_k_value, {"from": gov})

    # grab updated t1 = _k value
    updated_k_value = market.k()

    # test if t1 = _k value
    assert int(updated_k_value) == int(new_k_value)


def test_set_spread(
  mothership,
  token,
  market,
  ovl_collateral,
  gov
):
  # test for when spread value is updated
  # grab initial spread value
  initial_spread = market.pbnj()
  print('initial_spread: ', initial_spread)

  pass


def test_set_price_frame_cap(
  market,
  gov
):
  # test updating price frame cap
  # grab initial _priceFrameCap
  initial_price_frame_cap = market.priceFrameCap()
  print('initial priceFrameCap: ', initial_price_frame_cap)
  pass



def test_set_everything():
  pass