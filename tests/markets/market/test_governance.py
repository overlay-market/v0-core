from brownie import chain
from brownie.test import given, strategy 
from hypothesis import settings
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

UPDATE_PERIOD = 100 * 1.01
COMPOUND_PERIOD = 600 * 1.01
LEVERAGE_MAX = 100 * .99
K = 343454218783234 * 1.01
PRICE_FRAME_CAP = 5e18 * 1.01
SPREAD = .00573e18 * 1.01
IMPACT_WINDOW = 600 * 1.01
BRRRR_FADE = 1e18 * 1.01
STATIC_CAP = 800000 * 1e18 * 1.01
LMBDA = 0.1

@given(
  impact_window=strategy('uint256',
                         min_value=IMPACT_WINDOW,
                         max_value=IMPACT_WINDOW * 1.05))
@settings(max_examples = 3)
def test_set_impact_window(
  market,
  gov,
  impact_window
):
  # test updating _impactWindow only in setComptrollerParams func
  initial_impact_window = market.impactWindow()
  initial_static_cap = market.oiCap()
  initial_lmbda = market.lmbda()
  initial_brrrrFade = market.brrrrFade()

  market.setComptrollerParams(
    impact_window,
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
  assert int(current_impact_window) == int(impact_window)

  # test other params are unchanged
  assert int(current_static_cap) == int(initial_static_cap)
  assert int(current_lmbda) == int(initial_lmbda)
  assert int(current_brrrrFade) == int(initial_brrrrFade)


@given(
  static_cap=strategy('uint256',
                      min_value=STATIC_CAP,
                      max_value=STATIC_CAP * 1.05))
@settings(max_examples = 3)
def test_set_static_cap(
  market,
  gov,
  static_cap
):
  # test updating _staticCap only in setComptrollerParams func
  initial_impact_window = market.impactWindow()
  initial_lmbda = market.lmbda()
  initial_brrrrFade = market.brrrrFade()

  market.setComptrollerParams(
    initial_impact_window,
    static_cap,
    initial_lmbda,
    initial_brrrrFade,
    {"from": gov}
  )

  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrrFade = market.brrrrFade()

  # test current static cap equals input value
  assert int(current_static_cap) == int(static_cap)

  # test other params are unchanged
  assert int(current_impact_window) == int(initial_impact_window)
  assert int(current_lmbda) == int(initial_lmbda)
  assert int(current_brrrrFade) == int(initial_brrrrFade)


@given(
  lmbda=strategy('uint256',
                 min_value=LMBDA,
                 max_value=1))
@settings(max_examples = 3)
def test_set_lmbda(
  market,
  gov,
  lmbda
):
  # test updating _lmbda only in setComptrollerParams func
  initial_impact_window = market.impactWindow()
  initial_static_cap = market.oiCap()
  initial_brrrrFade = market.brrrrFade()

  market.setComptrollerParams(
    initial_impact_window,
    initial_static_cap,
    lmbda,
    initial_brrrrFade,
    {"from": gov}
  )

  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrrFade = market.brrrrFade()

  # test current _lmbda equals input value
  assert int(current_lmbda) == int(lmbda)

  # test other params are unchanged
  assert int(current_impact_window) == int(initial_impact_window)
  assert int(current_static_cap) == int(initial_static_cap)
  assert int(current_brrrrFade) == int(initial_brrrrFade)


@given(
  brrrr_fade=strategy('uint256',
                      min_value=BRRRR_FADE,
                      max_value=BRRRR_FADE * 1.05))
@settings(max_examples = 3)
def test_brrrr_fade(
  market,
  gov,
  brrrr_fade
):
  # test updating _brrrrFade only in setComptrollerParams func
  initial_impact_window = market.impactWindow()
  initial_static_cap = market.oiCap()
  initial_lmbda = market.lmbda()

  market.setComptrollerParams(
    initial_impact_window,
    initial_static_cap,
    initial_lmbda,
    brrrr_fade,
    {"from": gov}
  )

  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrr_fade = market.brrrrFade()

  # test current _brrrrFade equals input value
  assert int(current_brrrr_fade) == int(brrrr_fade)

  # test other params are unchanged
  assert int(current_impact_window) == int(initial_impact_window)
  assert int(current_static_cap) == int(initial_static_cap)
  assert int(current_lmbda) == int(initial_lmbda)


@given(
  impact_window=strategy('uint256',
                         min_value=IMPACT_WINDOW,
                         max_value=IMPACT_WINDOW * 1.05),
  static_cap=strategy('uint256',
                      min_value=STATIC_CAP,
                      max_value=STATIC_CAP * 1.05),
  lmbda=strategy('uint256',
                 min_value=LMBDA,
                 max_value=1),
  brrrr_fade=strategy('uint256',
                      min_value=BRRRR_FADE,
                      max_value=BRRRR_FADE * 1.05))
@settings(max_examples = 3)
def test_set_comptroller_params(
  market,
  gov,
  impact_window,
  static_cap,
  lmbda,
  brrrr_fade
):
  # set all params of setComptrollerParams func
  market.setComptrollerParams(
    impact_window,
    static_cap,
    lmbda,
    brrrr_fade,
    {"from": gov}
  )
  current_impact_window = market.impactWindow()
  current_static_cap = market.oiCap()
  current_lmbda = market.lmbda()
  current_brrrr_fade = market.brrrrFade()

  # test all variables updated
  assert int(current_impact_window) == int(impact_window)

  assert int(current_static_cap) == int(static_cap)

  assert int(current_lmbda) == int(lmbda)

  assert int(current_brrrr_fade) == int(brrrr_fade)

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
@settings(max_examples = 3)
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