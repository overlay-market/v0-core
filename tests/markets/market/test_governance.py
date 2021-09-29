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

def test_update_funding_k(
  mothership,
  token,
  market,
  ovl_collateral,
  gov,
  bob
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
