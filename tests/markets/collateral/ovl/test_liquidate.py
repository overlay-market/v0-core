import brownie
import pytest
from brownie.test import given, strategy
from pytest import approx


def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))


MIN_COLLATERAL = 1e14  # min amount to build
COLLATERAL = 10*1e18
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18

POSITIONS = [
    {
        "entry": {"timestamp": 1633520012, "price": 306204647441547},
        "liquidation": {"timestamp": 1633546772, "price": 318674244785741},
        "collateral": COLLATERAL,
        "leverage": 10,
        "is_long": False,
    },
    {
        "entry": {"timestamp": 1633504052, "price": 319655307482755},
        "liquidation": {"timestamp": 1633504112, "price": 314983505945323},
        "collateral": COLLATERAL,
        "leverage": 14,
        "is_long": True,
    },
]


def value(total_oi, total_oi_shares, pos_oi_shares, debt,
          price_frame, is_long):
    pos_oi = pos_oi_shares * total_oi / total_oi_shares

    if is_long:
        val = pos_oi * price_frame
        val -= min(val, debt)
    else:
        val = pos_oi * 2
        val -= min(val, debt + pos_oi * price_frame)

    return val


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_success_zero_impact_zero_funding(
    mothership,
    feed_infos,
    ovl_collateral,
    token,
    market,
    alice,
    gov,
    bob,
    rewards,
    position,
):
    market.setK(0, {'from': gov})

    margin_maintenance = ovl_collateral.marginMaintenance(market) / 1e18

    # Mine to the entry time then build
    brownie.chain.mine(timestamp=position["entry"]["timestamp"])
    tx_build = ovl_collateral.build(
        market,
        position['collateral'],
        position['leverage'],
        position['is_long'],
        {'from': bob}
    )
    pos_id = tx_build.events['Build']['positionId']
    (_, _, _, pos_price_idx, pos_oi_shares, pos_debt, pos_cost,
     pos_compounding) = ovl_collateral.positions(pos_id)

    # mine a bit more then update to settle
    brownie.chain.mine(timedelta=market.updatePeriod()+1)
    market.update({"from": gov})
    entry_bid, entry_ask, entry_price = market.pricePoints(pos_price_idx)

    brownie.chain.mine(timestamp=position["liquidation"]["timestamp"])

    tx_liq = ovl_collateral.liquidate(pos_id, alice, {'from': alice})

    assert 'Liquidate' in tx_liq.events
    assert 'positionId' in tx_liq.events['Liquidate']
    assert tx_liq.events['Liquidate']['positionId'] == pos_id

    (_, _, _, _, pos_oi_shares_after, _, _,
     _) = ovl_collateral.positions(pos_id)

    assert pos_oi_shares_after == 0

    # Check the price we liquidated at ...
    liq_bid, liq_ask, liq_price = market.pricePoints(
        market.pricePointCurrentIndex()-1)

    # calculate value and make sure it should have been liquidatable
    price_frame = liq_bid/entry_ask if position["is_long"] \
        else liq_ask/entry_bid
    expected_value = value(pos_oi_shares, pos_oi_shares, pos_oi_shares,
                           pos_debt, price_frame, position["is_long"])
    assert expected_value < pos_oi_shares * margin_maintenance


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_revert_not_liquidatable(
    mothership,
    feed_infos,
    ovl_collateral,
    token,
    market,
    alice,
    gov,
    bob,
    rewards,
    position,
):
    pass


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_revert_unwind_after_liquidation(
    mothership,
    feed_infos,
    ovl_collateral,
    token,
    market,
    alice,
    gov,
    bob,
    rewards,
    position,
):
    market.setK(0, {'from': gov})

    margin_maintenance = ovl_collateral.marginMaintenance(market) / 1e18

    # Mine to the entry time then build
    brownie.chain.mine(timestamp=position["entry"]["timestamp"])
    tx_build = ovl_collateral.build(
        market,
        position['collateral'],
        position['leverage'],
        position['is_long'],
        {'from': bob}
    )
    pos_id = tx_build.events['Build']['positionId']
    (_, _, _, pos_price_idx, pos_oi_shares, pos_debt, pos_cost,
     pos_compounding) = ovl_collateral.positions(pos_id)

    # mine a bit more then update to settle
    brownie.chain.mine(timedelta=market.updatePeriod()+1)
    market.update({"from": gov})
    entry_bid, entry_ask, entry_price = market.pricePoints(pos_price_idx)

    brownie.chain.mine(timestamp=position["liquidation"]["timestamp"])

    tx_liq = ovl_collateral.liquidate(pos_id, alice, {'from': alice})

    (_, _, _, _, pos_oi_shares_after, _, _,
     _) = ovl_collateral.positions(pos_id)

    assert pos_oi_shares_after == 0

    EXPECTED_ERROR_MESSAGE = "OVLV1:liquidated"
    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.unwind(
            pos_id,
            pos_oi_shares,
            {"from": bob}
            )


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_pnl_burned(
    mothership,
    feed_infos,
    ovl_collateral,
    token,
    market,
    alice,
    gov,
    bob,
    rewards,
    position,
):
    market.setK(0, {'from': gov})

    # Mine to the entry time then build
    brownie.chain.mine(timestamp=position["entry"]["timestamp"])
    tx_build = ovl_collateral.build(
        market,
        position['collateral'],
        position['leverage'],
        position['is_long'],
        {'from': bob}
    )
    pos_id = tx_build.events['Build']['positionId']
    (_, _, _, pos_price_idx, pos_oi_shares, pos_debt, pos_cost,
     _) = ovl_collateral.positions(pos_id)

    # mine a bit more then update to settle
    brownie.chain.mine(timedelta=market.updatePeriod()+1)
    market.update({"from": gov})
    entry_bid, entry_ask, _ = market.pricePoints(pos_price_idx)

    brownie.chain.mine(timestamp=position["liquidation"]["timestamp"])
    tx_liq = ovl_collateral.liquidate(pos_id, alice, {'from': alice})

    # Check the price we liquidated at ...
    liq_bid, liq_ask, _ = market.pricePoints(
        market.pricePointCurrentIndex()-1)

    # calculate value and make sure it should have been liquidatable
    price_frame = liq_bid/entry_ask if position["is_long"] \
        else liq_ask/entry_bid
    expected_value = value(pos_oi_shares, pos_oi_shares, pos_oi_shares,
                           pos_debt, price_frame, position["is_long"])

    expected_burn = pos_cost - expected_value
    for _, v in enumerate(tx_liq.events['Transfer']):
        if v['to'] == '0x0000000000000000000000000000000000000000':
            act_burn = v['value']

    assert int(expected_burn) == approx(act_burn)


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_oi_removed(
    mothership,
    feed_infos,
    ovl_collateral,
    token,
    market,
    alice,
    gov,
    bob,
    rewards,
    position,
):
    pass


@pytest.mark.parametrize('position', POSITIONS)
def test_liquidate_rewards_and_fees(
    mothership,
    feed_infos,
    ovl_collateral,
    token,
    market,
    alice,
    gov,
    bob,
    rewards,
    position,
):
    pass
