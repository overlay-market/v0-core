import math 

from brownie import reverts, chain
from brownie.test import given, strategy 
from hypothesis import settings
from pytest import approx

from decimal import *

def print_logs(tx):
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

    chain.mine(timedelta=1200)

    comptroller.expand(50)

    index = comptroller.index()
    cardinality = comptroller.cardinality()
    cardinality_n = comptroller.cardinalityNext()

    tx = comptroller.impactBatch([True],[1e18])

    tx = comptroller.impactBatch([True],[1e18])

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    tx = comptroller.impactBatch([True],[1e18])

    roller0 = comptroller.rollers(0)
    roller1 = comptroller.rollers(1)
    roller2 = comptroller.rollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

def test_impact_cardinality_one_one_per_block_overwrites_roller(comptroller):

    tx = comptroller.impactBatch([True],[1e18])
    assert comptroller.rollers(0)[0] == chain[-1].timestamp

    chain.mine(timedelta=10)

    tx = comptroller.impactBatch([True],[1e18])

    roller = comptroller.rollers(0)
    assert roller[0] == chain[-1].timestamp
    assert roller[1] == 2e18

def test_impact_cardinality_one_many_per_block_overwrites_roller(comptroller):

    ( cap, _, __ ) = comptroller.oiCap()

    pressure = Decimal(1e18) / Decimal(cap)

    tx = comptroller.impactBatch([True,True],[1e18,1e18])

    chain.mine(timedelta=10)

    tx = comptroller.impactBatch([True,True,True],[1e18,1e18,1e18])

    roller = comptroller.rollers(0)
    assert roller[0] == chain[-1].timestamp
    assert Decimal(roller[1]) / Decimal(1e18) == pressure * 5

def test_impact_cardinality_two_increments_cardinality_once(comptroller):

    comptroller.expand(2)

    assert comptroller.cardinalityNext() == 2

    comptroller.impactBatch([True], [1e18])

    roller = comptroller.rollers(1)

    assert roller[0] == chain[-1].timestamp
    assert roller[1] == 1e18

    assert comptroller.index() == 1
    assert comptroller.cardinality() == 2

def test_roller_cardinality_two_rolls_index_rolls_over_to_0_with_single_rolls(comptroller):

    ( cap, _, __ ) = comptroller.oiCap()
    pressure = Decimal(1e18) / Decimal(cap)

    comptroller.expand(2)

    chain.mine(timedelta=10)

    assert comptroller.cardinalityNext() == 2

    comptroller.impactBatch([True],[1e18])

    chain.mine(timedelta=10)

    assert comptroller.index() == 1
    assert comptroller.cardinality() == 2

    comptroller.impactBatch([True],[1e18])

    assert comptroller.index() == 0

    roller = comptroller.rollers(0)
    assert roller[0] == chain[-1].timestamp
    assert Decimal(roller[1]) / Decimal(1e18) == pressure * 2


def test_roller_cardinality_increments_to_5_with_single_rolls(comptroller):

    ( cap, _, __ ) = comptroller.oiCap()

    print("cap", cap)

    pressure = 1e18 / cap

    print("pressure", pressure)

    comptroller.expand(5)
    chain.mine(timedelta=10)

    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch([True],[1e18])

    assert comptroller.cardinality() == 5
    assert comptroller.index() == 0

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] / 1e18 == approx(5 * pressure)
    assert comptroller.rollers(1)[1] / 1e18 == approx(1 * pressure)
    assert comptroller.rollers(2)[1] / 1e18 == approx(2 * pressure)
    assert comptroller.rollers(3)[1] / 1e18 == approx(3 * pressure)
    assert comptroller.rollers(4)[1] / 1e18 == approx(4 * pressure)
    assert comptroller.rollers(5)[0] == 0

def test_roller_cardinality_increments_to_5_with_many_rolls(comptroller):

    ( cap, _, __ ) = comptroller.oiCap()
    pressure = Decimal(1e18) / Decimal(cap)

    comptroller.expand(5)
    chain.mine(timedelta=10)

    tx = comptroller.impactBatch(
        [True,True,True,True ],
        [1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch(
        [True,True,True],
        [1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch(
        [True,True,True,True],
        [1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch(
        [True,True,True,True,True],
        [1e18, 1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=10)
    tx = comptroller.impactBatch(
        [True,True,True,True,True,True],
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

    tx = comptroller.impactBatch([True,True],[1e18, 1e18])

    chain.mine(timedelta=10)

    tx = comptroller.impactBatch([True,True],[1e18, 1e18])

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] == 4e18
    assert comptroller.rollers(1)[1] == 2e18

    chain.mine(timedelta=10)

    tx = comptroller.impactBatch(
        [True,True,True,True,True,True],
        [1e18,1e18,1e18,1e18,1e18,1e18]
    )

    assert comptroller.rollers(1)[0] == chain[-1].timestamp
    assert comptroller.rollers(1)[1] == 10e18

    chain.mine(timedelta=10)
    tx = comptroller.impactBatch([True,True,True],[2e18, 5e18, 3e18])

    assert comptroller.rollers(0)[0] == chain[-1].timestamp
    assert comptroller.rollers(0)[1] == 20e18


@given(time_diff=strategy('uint', min_value=1, max_value=1000),
       brrrr=strategy('uint', min_value=100, max_value=100000))
@settings(max_examples=100)
def test_scry_interpolated_roller(comptroller, time_diff, brrrr):

    brrrr = brrrr * 1e16

    ( cap,_,__ ) = comptroller.oiCap()

    time0 = Decimal(chain[-1].timestamp)

    comptroller.expand(3)

    window = comptroller.impactWindow()

    chain.mine(timedelta=window+time_diff)

    tx = comptroller.impactBatch([True],[brrrr])
    time1 = Decimal(chain[-1].timestamp)

    chain.mine(timedelta=(window/4))

    tx = comptroller.impactBatch([True],[brrrr])
    time2 = Decimal(chain[-1].timestamp)

    ( roller_now, roller_then ) = comptroller.viewScry(window)

    time_target = time2 - Decimal(window)
    time_diff = time1 - time0
    ratio = ( time_target - time0 ) / ( time_diff )

    pressure = Decimal(brrrr) / Decimal(cap)

    expected_pressure = pressure * ratio
    expected_pressure_total = pressure + pressure - expected_pressure

    interpolated_pressure = Decimal(roller_then[1]) / Decimal(1e18)
    interpolated_pressure_total = (Decimal(roller_now[1]) / Decimal(1e18)) - interpolated_pressure

    assert abs(expected_pressure - interpolated_pressure) <= Decimal(1/10**17)
    assert abs(expected_pressure_total - interpolated_pressure_total) <= Decimal(1/10**17)

@given(
    entry=strategy('uint256', min_value=1, max_value=1e6),
    rand=strategy('int', min_value=100, max_value=1000))
@settings(max_examples=20)
def test_impact_pressure(comptroller, entry, rand):

    comptroller.expand(10)
    chain.mine(timedelta=10)

    entry *= 1e18
    rand = float(rand) / 100
    ( cap, _, __ ) = comptroller.oiCap()

    _lambda = comptroller.lmbda()

    comptroller.impactBatch([True], [entry])

    impact = comptroller.viewImpact(True, 1e18)

    inverse_euler = Decimal(1) / Decimal(math.e)

    impact_1 = ( Decimal(entry) / Decimal(1e18) ) / ( Decimal(cap) / Decimal(1e18) )

    impact_2 = ( Decimal(1e18) / Decimal(1e18) ) / ( Decimal(cap) / Decimal(1e18) )

    pressure = impact_1 + impact_2

    impact_factor = Decimal(_lambda / 1e18) * pressure

    expected = ( Decimal(1) - ( inverse_euler ** impact_factor ) ) * Decimal(1e18)

    assert abs(expected - impact) < 1e6

@given(
    entry=strategy('uint256', min_value=1, max_value=1e6),
    rand=strategy('int', min_value=100, max_value=1000))
@settings(max_examples=20)
def test_impact_pressure_full_cooldown (comptroller, entry, rand):

    comptroller.expand(10)
    impact_window = comptroller.impactWindow()
    chain.mine(timedelta=10)

    comptroller.impactBatch([True], [entry])

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