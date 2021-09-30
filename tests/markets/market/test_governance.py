from brownie import chain
from brownie.test import given, strategy 
from hypothesis import settings
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
FEE_RESOLUTION = 1e18

def set_comptroller_params():
  pass


def set_update_period_only():
  pass


def set_compounding_period_only():
  pass


def set_both_update_compounding_period():
  pass


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
  pass


def test_set_price_frame_cap(
  market,
  gov
):
  # test updating price frame cap
  # grab initial _priceFrameCap
  pass


def test_set_everything():
  pass