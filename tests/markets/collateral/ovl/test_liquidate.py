import os 
import brownie
import datetime
import pytest
import json
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
        "entrySeconds": 15000,              # seconds after test begins 
        "entryPrice": 318889092879897,
        # "exitSeconds": 1633485143 - 3600,               # seconds after entry
        "exitSeconds": 30000,               # seconds after entry
        "exitPrice": 304687017011120,
        "collateral": COLLATERAL,
        "leverage": 10,
        "is_long": True,
    },
]

def value(
    total_oi, 
    total_oi_shares, 
    pos_oi_shares, 
    debt,
    price_frame,
    is_long
):
    pos_oi = pos_oi_shares * total_oi / total_oi_shares

    if is_long:
        val = pos_oi * price_frame
        val -= min(val, debt)
    else:
        val = pos_oi * 2
        val -= min(val, debt + pos_oi * price_frame )
    
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

    max_ask = max(feed_infos.market_info[2]['asks'])
    min_bid = min(feed_infos.market_info[2]['bids'])

    margin_maintenance = ovl_collateral.marginMaintenance(market) / 1e18
    margin_reward = ovl_collateral.marginRewardRate(market) / 1e18

    # bid = ask * (MM + 1 - 1/L)
    
    entry_ask = 318889092879897 / 1e18
    exit_bid = entry_ask * ( margin_maintenance + 1 - 1/10)

    for i in range(len(feed_infos.market_info[2]['bids'])):
        bid = feed_infos.market_info[2]['bids'][i]
        if bid < exit_bid:
            print("~~~ ~~~~ ~~~~ bid", bid)
            exit_index = i
            break

    print("now", brownie.chain.time())
    print("timestamp", feed_infos.market_info[2]['timestamp'][491])
    print("~~~ exit index ~~~", exit_index)
    print("max", max_ask)
    print("min", min_bid)
    print("ask", entry_ask)
    print("bid", exit_bid)
    print("margin_maintenance", margin_maintenance)

    # market.setK(0, { 'from': gov })

    # update_period = market.updatePeriod()

    # brownie.chain.mine(timedelta=position['entrySeconds'])

    # tx_build = ovl_collateral.build(
    #     market, 
    #     position['collateral'], 
    #     position['leverage'], 
    #     position['is_long'], 
    #     { 'from': bob }
    # )


    # pos_id = tx_build.events['Build']['positionId']
    # pos_oi = tx_build.events['Build']['oi']
    # ( _, _, _, _, pos_oi_shares , pos_debt, pos_cost, _ ) = ovl_collateral.positions(pos_id)

    # brownie.chain.mine(timedelta=position['exitSeconds'])

    # oi = market.oiLong() if position['is_long'] else market.oiShort()
    # oi_shares = market.oiLongShares() if position['is_long'] else market.oiShortShares()

    # tx_liq = ovl_collateral.liquidate( pos_id, bob, { 'from': bob } )

    # price_index = market.pricePointCurrentIndex()

    # print("price index", price_index)

    # price_point = market.pricePoints(price_index-1)

    # print("price_point", price_point)

    # print("liquidate time", brownie.chain.time())

    # price_index = market.pricePointCurrentIndex()
    # print("price index", price_index)
    # price_point = market.pricePoints(price_index-1)
    # print("price_point", price_point)



    # print("price index", price_index)
    # print("price_point", price_point)
    # print("y/x Avg 10M start", feed_infos.market_info[2]['y/x Avg 10M'][0])

    # TODO: make a param passed in via hypothesis to loop through
    # collateral = position["collateral"]
    # leverage = position["leverage"]
    # is_long = position["is_long"]

    # entry_time = position["entry"]["timestamp"]
    # exit_time = position["exit"]["timestamp"]

    # fast forward to time we want for entry
    # TODO: timestamp=entry_time
    # brownie.chain.mine(timestamp=entry_time)

    # # market constants
    # maintenance_margin, maintenance_margin_reward = ovl_collateral.marketInfo(
    #     market)

    # # build a position with leverage
    # token.approve(ovl_collateral, collateral, {"from": bob})
    # tx_build = ovl_collateral.build(
    #     market,
    #     collateral,
    #     leverage,
    #     is_long,
    #     {"from": bob}
    # )
    # pid = tx_build.events['Build']['positionId']

    # # Get info after settlement
    # (_, _, _, entry_price_idx,
    #     oi, debt, cost, _) = ovl_collateral.positions(pid)

    # print('entry_price_idx', entry_price_idx)
    # print('current_price_idx', market.pricePointCurrentIndex())
    # print('last price point',  market.pricePoints(
    #     market.pricePointCurrentIndex()-1))

    # # fast forward to time at which should get liquidated
    # # TODO: timestamp=exit_time
    # brownie.chain.mine(timedelta=10*market.compoundingPeriod())

    # # get market and manager state prior to liquidation
    # oi_long_prior, oi_short_prior = market.oi()
    # value = ovl_collateral.value(pid)

    # # get balances  prior
    # alice_balance = token.balanceOf(alice)
    # ovl_balance = token.balanceOf(ovl_collateral)
    # liquidations = ovl_collateral.liquidations()

    # # check liquidation condition was actually met: value < oi(0) * mm
    # assert value < oi * maintenance_margin
    # ovl_collateral.liquidate(pid, alice, {"from": alice})

    # # check oi removed from market
    # oi_long, oi_short = market.oi()
    # if is_long:
    #     assert pytest.approx(oi_long) == int(oi_long_prior - oi)
    #     assert pytest.approx(oi_short) == int(oi_short_prior)
    # else:
    #     assert pytest.approx(oi_long) == int(oi_long_prior)
    #     assert pytest.approx(oi_short) == int(oi_short_prior - oi)

    # # check loss burned by collateral manager
    # loss = cost - value
    # assert int(ovl_balance - loss)\
    #     == pytest.approx(token.balanceOf(ovl_collateral))

    # # check reward transferred to rewarded
    # reward = value * maintenance_margin_reward
    # assert int(reward + alice_balance) == pytest.approx(token.balanceOf(alice))

    # # check liquidations pot increased
    # assert int(liquidations + (value - reward))\
    #     == pytest.approx(ovl_collateral.liquidations())

    # # check position is no longer able to be unwind
    # with brownie.reverts("OVLV1:!shares"):
    #     ovl_collateral.unwind(pid, oi, {"from": bob})
    pass


def test_no_unwind_after_liquidate():
    pass