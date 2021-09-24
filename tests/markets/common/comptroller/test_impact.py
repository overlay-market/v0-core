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


def test_sanity(comptroller):

    cardinality = comptroller.cardinality()
    cardinality_next = comptroller.cardinalityNext()
    index = comptroller.index()

    assert cardinality == 1
    assert cardinality_next == 1
    assert index == 0

def test_expand_cardinality_next(comptroller):

    prior_index = comptroller.index()
    prior_cardinality = comptroller.cardinality()
    prior_cardinality_next = comptroller.cardinalityNext()

    comptroller.expand(prior_cardinality_next + 1)

    next_index = comptroller.index() 
    next_cardinality = comptroller.cardinality()
    next_cardinality_next = comptroller.cardinalityNext()

    assert next_index == prior_index
    assert next_cardinality == prior_cardinality
    assert next_cardinality_next == prior_cardinality_next + 1

def test_impact(comptroller):

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    chain.mine(timedelta=1200)
    print("time now", chain[-1].timestamp)

    comptroller.expand(50)

    index = comptroller.index()
    cardinality = comptroller.cardinality()
    cardinality_n = comptroller.cardinalityNext()

    print("index", index)
    print("cardinality", cardinality)
    print("cardinalityNext", cardinality_n)

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    tx = comptroller.impact([True],[1e18])

    print_events(tx)

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    tx = comptroller.impact([True],[1e18])

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    print_events(tx)

    tx = comptroller.impact([True],[1e18])

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    print_events(tx)

def test_impact_cardinality_one_one_per_block_overwrites_roller(comptroller):

    tx = comptroller.brrrr([1e18])
    assert comptroller.rollers(0)[0] == chain[-1].timestamp

    chain.mine(timedelta=10)

    tx = comptroller.impact([True],[1e18])

    roller = comptroller.rollers(0)
    assert roller[0] == chain[-1].timestamp
    assert roller[1] == 2e18

def test_impact_cardinality_one_many_per_block_overwrites_roller(comptroller):

    tx = comptroller.impact([True,True],[1e18,1e18])

    print(comptroller.rollers(0))
    print(comptroller.rollers(1))

    chain.mine(timedelta=10)

    tx = comptroller.impact([True,True,True],[1e18,1e18,1e18])

    roller = comptroller.rollers(0)
    assert roller[0] == chain[-1].timestamp
    assert roller[1] == 5e18

def test_impact_cardinality_two_increments_cardinality_once(comptroller):

    comptroller.expand(2)

    assert comptroller.cardinalityNext() == 2

    tx = comptroller.impact([True], [1e18])

    roller = comptroller.rollers(1)

    assert roller[0] == chain[-1].timestamp
    assert roller[1] == 1e18

    assert comptroller.index() == 1
    assert comptroller.cardinality() == 2

def test_roller_cardinality_two_rolls_index_rolls_over_to_0_with_single_rolls(comptroller):

    comptroller.expand(2)

    chain.mine(timedelta=10)

    assert comptroller.cardinalityNext() == 2

    tx = comptroller.impact([True],[1e18])

    chain.mine(timedelta=10)

    print(comptroller.rollers(0))
    print(comptroller.rollers(1))

    assert comptroller.index() == 1
    assert comptroller.cardinality() == 2

    tx = comptroller.impact([True],[1e18])

    print(comptroller.rollers(0))
    print(comptroller.rollers(1))

    assert comptroller.index() == 0

    roller = comptroller.rollers(0)
    assert roller[0] == chain[-1].timestamp
    assert roller[1] == 2e18

    # tx = comptroller.brrrr([1e18])

def test_roller_cardinality_increments_to_5_with_single_rolls(comptroller):

    comptroller.expand(5)
    chain.mine(timedelta=10)

    tx = comptroller.impact([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impact([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impact([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impact([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impact([True],[1e18])

    assert comptroller.cardinality() == 5
    assert comptroller.index() == 0

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] == 5e18
    assert comptroller.rollers(1)[1] == 1e18
    assert comptroller.rollers(2)[1] == 2e18
    assert comptroller.rollers(3)[1] == 3e18
    assert comptroller.rollers(4)[1] == 4e18
    assert comptroller.rollers(5)[0] == 0

def test_roller_cardinality_increments_to_5_with_many_rolls(comptroller):

    comptroller.expand(5)
    chain.mine(timedelta=10)

    tx = comptroller.impact(
        [True,True,True,True ]
        [1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impact(
        [True,True,True]
        [1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impact(
        [True,True,True,True]
        [1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impact(
        [True,True,True,True,True]
        [1e18, 1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impact(
        [True,True,True,True,True,True]
        [1e18, 1e18, 1e18, 1e18, 1e18, 1e18]
    )

    assert comptroller.cardinality() == 5
    assert comptroller.index() == 0

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] == 22e18
    assert comptroller.rollers(1)[1] == 4e18
    assert comptroller.rollers(2)[1] == 7e18
    assert comptroller.rollers(3)[1] == 11e18
    assert comptroller.rollers(4)[1] == 16e18
    assert comptroller.rollers(5)[0] == 0

def test_roller_cardinality_two_index_rolls_over(comptroller):

    comptroller.expand(2)

    chain.mine(timedelta=10)

    tx = comptroller.brrrr([True,True],[1e18, 1e18])

    chain.mine(timedelta=10)

    tx = comptroller.brrrr([True,True],[1e18, 1e18])

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] == 4e18
    assert comptroller.rollers(1)[1] == 2e18

    chain.mine(timedelta=10)

    tx = comptroller.brrrr(
        [True,True,True,True,True,True]
        [1e18,1e18,1e18,1e18,1e18,1e18]
    )

    assert comptroller.rollers(1)[0] == chain[-1].timestamp
    assert comptroller.rollers(1)[1] == 10e18

    chain.mine(timedelta=10)
    tx = comptroller.brrrr([True,True,True],[2e18, 5e18, 3e18])

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] == 20e18


@given(timediff=strategy('uint', min_value=1, max_value=100))
@settings(max_examples=100)
def test_scry_interpolated_roller(comptroller, timediff):

    comptroller.expand(3)

    window = comptroller.impactWindow()

    chain.mine(timedelta=window+timediff)
    time0 = chain[-1].timestamp
    print("TIME 0", time0)

    tx = comptroller.impact([True],[1e18])

    print_events(tx)
    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")

    chain.mine(timedelta=(window/4))
    time1 = chain[-1].timestamp
    print("TIME 1", time1)

    tx = comptroller.impact([True],[1e18])
    print_events(tx)
    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")

    ( rollerNow, rollerThen ) = comptroller.viewScry(window)
    # tx = comptroller.viewScry(window)
    # print_events(tx)
    print('interpolated roller', rollerThen[1])

    print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    timeDiff = roller1[0] - roller0[0]
    brrrrDiff = roller1[1] - roller0[1]
    target = chain[-1].timestamp - window

    ratio = ( target - roller0[0]) / timeDiff
    remove = brrrrDiff * ratio
    extra = roller2[1] - roller1[1]
    expected = (extra + (roller1[1] - (remove)))

    print("roller0", roller0)
    print("roller1", roller1)
    print("roller2", roller2)
    print("time0", time0)
    print("time1", time1)
    print("ratio", ratio)
    print("remove", remove)
    print("extra", extra)
    print("expected", expected)


def test_brrrr_one_time_one_block(comptroller):

    tx = comptroller.brrrr([1e18])
    brrrr = comptroller.viewBrrrr(0)
    assert brrrr == 1e18

@given(
    entry=strategy('uint256', min_value=1, max_value=1e6),
    rand=strategy('int', min_value=100, max_value=1000))
@settings(max_examples=20)
def test_impact_pressure(comptroller, entry, rand):

    comptroller.expand(10)
    chain.mine(timedelta=10)

    entry *= 1e18
    rand = float(rand) / 100
    cap = entry * rand

    comptroller.set_TEST_CAP(cap)

    cap = comptroller.TEST_CAP()

    _lambda = comptroller.viewLambda()

    comptroller.impact([True], [entry])

    impact = comptroller.viewImpact(True, 1e18)

    inverse_euler = Decimal(1) / Decimal(math.e)

    pressure = Decimal( (entry + 1e18) / 1e18) / Decimal(cap / 1e18)

    impact_factor = Decimal(_lambda / 1e18) * pressure

    expected = ( Decimal(1) - ( inverse_euler ** impact_factor ) ) * Decimal(1e18)

    assert int(expected / Decimal(1e6)) == int(impact / Decimal(1e6))

@given(
    entry=strategy('uint256', min_value=1, max_value=1e6),
    rand=strategy('int', min_value=100, max_value=1000))
@settings(max_examples=20)
def test_impact_pressure_full_cooldown (comptroller, entry, rand):

    comptroller.expand(10)
    impact_window = comptroller.impactWindow()
    chain.mine(timedelta=10)

    entry *= 1e18
    rand = float(rand) / 100
    cap = entry * rand

    comptroller.set_TEST_CAP(cap)

    comptroller.impact([True], [entry])

    chain.mine(timedelta=impact_window+1)

    impact = comptroller.viewImpact(True, 0)

    assert impact == 0

def test_brrrr_when_before_roller_must_interpolate_over_long_timeframe(comptroller):
    pass

def test_brrrr_when_earliest_roller_is_more_contemporary_than_brrrr_window(comptroller):
    pass

def test_brrrr_when_before_roller_must_interpolate_over_small_timeframe(comptroller):
    pass

def test_brrrr_when_earliest_roller_is_much_older_than_brrrr_window(comptroller):
    pass

def test_roller(comptroller):

    print(comptroller)