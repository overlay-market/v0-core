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

    pressure = 1e18 / cap

    chain.mine(timedelta=ONE_BLOCK)

    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch([True],[1e18])
    chain.mine(timedelta=ONE_BLOCK)
    tx = comptroller.impactBatch([True],[1e18])

    assert comptroller.impactCycloid() == 5

    assert comptroller.impactRollers(1)[1] / 1e18 == approx(1 * pressure)
    assert comptroller.impactRollers(2)[1] / 1e18 == approx(2 * pressure)
    assert comptroller.impactRollers(3)[1] / 1e18 == approx(3 * pressure)
    assert comptroller.impactRollers(4)[1] / 1e18 == approx(4 * pressure)
    assert comptroller.impactRollers(5)[1] / 1e18 == approx(5 * pressure)
    assert comptroller.impactRollers(5)[0] == chain[-1].timestamp
    assert comptroller.impactRollers(6)[0] == 0

def test_impact_roller_expected_impact_many_batched(comptroller):

    cap = comptroller.oiCap()

    pressure = 1e18 / cap 

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

    assert comptroller.impactRollers(1)[1] / 1e18 == approx(4 * pressure)
    assert comptroller.impactRollers(2)[1] / 1e18 == approx(7 * pressure)
    assert comptroller.impactRollers(3)[1] / 1e18 == approx(11 * pressure)
    assert comptroller.impactRollers(4)[1] / 1e18 == approx(16 * pressure)
    assert comptroller.impactRollers(5)[1] / 1e18 == approx(22 * pressure)
    assert comptroller.impactRollers(5)[0] == chain[-1].timestamp

@given(time_diff=strategy('uint', min_value=1, max_value=100),
       brrrr=strategy('uint', min_value=100, max_value=100000))
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
    entry=strategy('uint256', min_value=1, max_value=.370400e6),
    rand=strategy('int', min_value=100, max_value=1000))
def test_impact_pressure_full_cooldown_entry_within_cap (comptroller, entry, rand):

    entry *= 1e16

    impact_window = comptroller.impactWindow()

    chain.mine(timedelta=ONE_BLOCK)

    tx = comptroller.impactBatch([True], [entry])

    chain.mine(timedelta=impact_window+1)

    impact = comptroller.viewImpact(True, 0)

    assert impact == 0

def test_impact_when_before_roller_must_interpolate_over_long_timeframe(comptroller):
    pass

def test_impact_when_earliest_roller_is_more_contemporary_than_impact_window(comptroller):
    pass

def test_impact_when_before_roller_must_interpolate_over_small_timeframe(comptroller):
    pass

def test_impact_when_earliest_roller_is_much_older_than_impact_window(comptroller):
    pass
