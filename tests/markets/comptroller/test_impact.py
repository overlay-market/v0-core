import math 

from brownie import reverts, chain
from brownie.test import given, strategy 
from hypothesis import settings
from pytest import approx

ONE_BLOCK = 13


from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(
            tx.events['log'][i]['k'] + ": " 
            + str(tx.events['log'][i]['v'])
        )


def test_sanity(comptroller):
    pass


def test_impact(comptroller):

    chain.mine(timedelta=1200)

    tx = comptroller.impactBatch([True],[1e18])

    tx = comptroller.impactBatch([True],[1e18])

    roller0 = comptroller.impactRollers(0)
    roller1 = comptroller.impactRollers(1)
    roller2 = comptroller.impactRollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

    tx = comptroller.impactBatch([True],[1e18])

    roller0 = comptroller.impactRollers(0)
    roller1 = comptroller.impactRollers(1)
    roller2 = comptroller.impactRollers(2)

    print(roller0)
    print(roller1)
    print(roller2)

def test_impact_roller_expected_impact(comptroller):

    cap = comptroller.oiCap()

    print("cap", cap)

    pressure = 1e18 / cap

    print("pressure", pressure)

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

    assert comptroller.impactCycloid() == 6 

    assert comptroller.impactRollers(1)[1] / 1e18 == approx(1 * pressure)
    assert comptroller.impactRollers(2)[1] / 1e18 == approx(2 * pressure)
    assert comptroller.impactRollers(3)[1] / 1e18 == approx(3 * pressure)
    assert comptroller.impactRollers(4)[1] / 1e18 == approx(4 * pressure)
    assert comptroller.impactRollers(5)[0] == chain[-1].timestamp
    assert comptroller.impactRollers(5)[1] / 1e18 == approx(5 * pressure)
    assert comptroller.impactRollers(6)[0] == 0

def test_roller_cardinality_increments_to_5_with_many_rolls(comptroller):

    cap = comptroller.oiCap()

    pressure = int(( 1e18 / cap ) * 1e18)

    chain.mine(timedelta=ONE_BLOCK)

    tx = comptroller.impactBatch(
        [True,True,True,True ],
        [1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch(
        [True,True,True],
        [1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch(
        [True,True,True,True],
        [1e18, 1e18, 1e18, 1e18]
    )
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch(
        [True,True,True,True,True],
        [1e18, 1e18, 1e18, 1e18, 1e18]
    )

    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch(
        [True,True,True,True,True,True],
        [1e18, 1e18, 1e18, 1e18, 1e18, 1e18]
    )

    assert comptroller.impactRollers(1)[1] == 4 * pressure
    assert comptroller.impactRollers(2)[1] == 7 * pressure
    assert comptroller.impactRollers(3)[1] == 11 * pressure
    assert comptroller.impactRollers(4)[1] == 16 * pressure
    assert comptroller.impactRollers(5)[0] == chain[-1].timestamp
    assert comptroller.impactRollers(5)[1] == 22 * pressure

@given(time_diff=strategy('uint', min_value=1, max_value=100),
       brrrr=strategy('uint', min_value=100, max_value=100000))
@settings(max_examples=100)
def test_scry_interpolated_roller(comptroller, time_diff, brrrr):

    time_diff *= ONE_BLOCK
    brrrr *= 1e16

    cap = comptroller.oiCap()

    time0 = Decimal(chain[-1].timestamp)

    window = comptroller.impactWindow()

    chain.mine(timedelta=window+time_diff)

    _ = comptroller.impactBatch([True],[brrrr])
    time1 = Decimal(chain[-1].timestamp)

    chain.mine(timedelta=(window/4))

    _ = comptroller.impactBatch([True],[brrrr])
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

@given(entry=strategy('uint256', min_value=1, max_value=1e6))
@settings(max_examples=20)
def test_impact_pressure(comptroller, entry):

    entry *= 1e18

    chain.mine(timedelta=ONE_BLOCK)

    cap = comptroller.oiCap()

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

    impact_window = comptroller.impactWindow()
    chain.mine(timedelta=ONE_BLOCK)

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