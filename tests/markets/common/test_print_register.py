import pytest
from functools import reduce

from brownie import\
    chain,\
    interface,\
    UniswapV3Listener
from brownie.test import given, strategy
from collections import OrderedDict
from hypothesis import settings

import time

MIN_COLLATERAL_AMOUNT = 10**4  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
FEE_RESOLUTION = 1e4

def test_sanity(print_shim):

    cardinality = print_shim.cardinality()
    cardinality_next = print_shim.cardinalityNext()
    index = print_shim.index()

    assert cardinality == 1
    assert cardinality_next == 1
    assert index == 0


def test_expand_cardinality_next(print_shim):

    prior_index = print_shim.index()
    prior_cardinality = print_shim.cardinality()
    prior_cardinality_next = print_shim.cardinalityNext()

    print_shim.expand(prior_cardinality_next + 1)

    next_cardinality = print_shim.cardinality()
    next_cardinality_next = print_shim.cardinalityNext()
    next_index = print_shim.index()

    assert next_cardinality_next == prior_cardinality_next + 1
    assert next_cardinality == prior_cardinality
    assert next_index == prior_index

    print_shim.simulatePrint(1e18)

    printed = print_shim.printed()

    assert printed == 1e18

    current_cardinality = print_shim.cardinality()
    current_cardinality_next = print_shim.cardinalityNext()
    current_index = print_shim.index()

    assert current_cardinality == 2
    assert current_cardinality_next == 2
    assert current_index == 1

def test_one_window_no_rolling(print_shim):

    prior_cardinality_next = print_shim.cardinalityNext()
    print_shim.expand(prior_cardinality_next + 10)
    window = print_shim.printWindow()

    print_shim.simulatePrint(10e18)
    print_shim.simulatePrint(11e18)
    print_shim.simulatePrint(12e18)
    print_shim.simulatePrint(13e18)
    print_shim.simulatePrint(14e18)

    chain.mine(window - 4)

    assert print_shim.printedInWindow() == 60e18


def test_one_window_rolling(print_shim):

    print_shim.expand(15)


    cardinalities = []
    indexes = []
    nums = []
    blocks = []
    vals = [ x * 1e18 for x in range(1,20) ]
    for v in vals:
        print_shim.simulatePrint(v)
        nums.append(print_shim.blocknumber())
        cardinalities.append(print_shim.cardinality())
        indexes.append(print_shim.index())
        blocks.append(chain[-1].number)


    block_start = chain[-1].number
    summed = reduce(lambda x,y:x+y, vals[9:])


    printed = print_shim.printedInWindow.call()
    tx = print_shim.printedInWindow()
    printed_waiting = print_shim.printed()
    
    block_end = chain[-1].number

    print("nums", nums)
    print("indexes", indexes)
    print("cardinalities", cardinalities)
    print("vals", vals[9:])
    print("blocks", blocks)
    print("block", 
        "\n start", block_start,
        "\n end", block_end
    )

    print("summed", summed)
    print("printed", printed)
    print("printed waiting", printed_waiting)
    print(tx.events)



