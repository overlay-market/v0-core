import math 
import random

from brownie import reverts, chain
from brownie.test import given, strategy 
from hypothesis import settings
from decimal import *

def print_events(tx):
    for i in range(len(tx.events['log'])):
        print(
            tx.events['log'][i]['k'] + ": " 
            + str(tx.events['log'][i]['v'])
        )

def test_cap_correct_eth_quote_in_ovl ():
    pass

def test_cap_to_half_because_print ():
    pass

def test_cap_correct_brrrr_fade_positive ():
    pass

def test_cap_above_static_cap_because_burn ():
    pass

def test_cap_correct_brrrr_fade_negative ():
    pass

def test_cap_constraint_on_liquidity_vanish ():
    pass

def test_cap_constraint_on_ovl_depreciation ():
    pass

def test_cap_no_constraint_on_liquidity_vanish_because_ovl_appreciation ():
    pass

def test_cap_no_constraint_on_ovl_depreciation_because_liquidity_influx ():
    pass

def test_cap_to_zero_because_liquidity_and_brrrr ():
    pass

def test_cap_above_static_cap_because_burn ():
    pass

