from brownie import chain
from brownie.test import given, strategy 
from hypothesis import settings
import pytest
import brownie
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))


def test_only_gov_can_update_market(
  market,
  token,
  bob,
  alice,
  rewards,
  feed_owner,
  fees,
  comptroller
):
  # ensure only gov can update market
  # mock inputs below
  input_k = 346888760971066
  input_price_frame_cap = 5e19
  input_spread = .00573e19
  input_update_period = 110
  input_compounding_period = 660
  input_impact_window = 601
  input_static_cap = int(800000 * 1e19)
  input_brrrr_expected = 1e19
  input_brrrr_window_macro = 1e19
  input_brrrr_window_micro = 1e19
  initial_lmbda = market.lmbda()

  EXPECTED_ERROR_MSG = 'OVLV1:!governor'

  with brownie.reverts(EXPECTED_ERROR_MSG):
      market.setComptrollerParams(
          input_impact_window,
          initial_lmbda,
          input_static_cap,
          input_brrrr_expected,
          input_brrrr_window_macro,
          input_brrrr_window_micro,
          {"from": alice})


  with brownie.reverts(EXPECTED_ERROR_MSG):
      market.setPeriods(
          input_update_period, 
          input_compounding_period,
          {"from": bob})


  with brownie.reverts(EXPECTED_ERROR_MSG):
      market.setK(
          input_k,
          {"from": feed_owner})


  with brownie.reverts(EXPECTED_ERROR_MSG):
      market.setSpread(
          input_spread,
          {"from": fees})


  with brownie.reverts(EXPECTED_ERROR_MSG):
      market.setPriceFrameCap(
          input_price_frame_cap,
          {"from": comptroller})


  with brownie.reverts(EXPECTED_ERROR_MSG):
      market.setEverything(
          input_k,
          input_price_frame_cap,
          input_spread,
          input_update_period,
          input_compounding_period,
          input_impact_window,
          input_static_cap,
          initial_lmbda,
          input_brrrr_expected,
          input_brrrr_window_macro,
          input_brrrr_window_micro,
          {"from": token })