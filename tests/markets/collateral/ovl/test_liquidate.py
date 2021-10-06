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
        "exitSeconds": 13978,               # seconds after entry
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

    now = brownie.chain.time()
    print("now", now)

    market.setK(0, { 'from': gov })

    margin_maintenance = ovl_collateral.marginMaintenance(market) / 1e18
    margin_reward = ovl_collateral.marginRewardRate(market) / 1e18

    # find long liquidation price 
    # bidExit = askEntry * (MM + 1 - 1/L) 
    # find short liquidation price
    # askExit = bidEntry * ( 1 - MM + 1/L )

    start = 318920981789185 / 1e18
    liquidation_price = start * ( margin_maintenance + 1 - 1 / position['leverage'] )

    liq_ix = None
    for i in range(len(feed_infos.market_info[2]['bids'])):
        bid = feed_infos.market_info[2]['bids'][i]
        if bid < liquidation_price:
            liq_ix = i
            break
    
    liq_time = feed_infos.market_info[2]['timestamp'][liq_ix]

    next = feed_infos.market_info[2]['bids'][liq_ix+1]
    print("next", next)

    print("liquidation price", liquidation_price)
    print("liquidation index", liq_ix)
    print("liquidation time", liq_time, liq_time - now)

    

    brownie.chain.mine(timedelta=position['entrySeconds'])

    tx_build = ovl_collateral.build(
        market, 
        position['collateral'], 
        position['leverage'], 
        position['is_long'], 
        { 'from': bob }
    )

    pos_id = tx_build.events['Build']['positionId']
    _, _, _, pos_price_ix, pos_oi_shares , pos_debt, pos_cost, pos_compounding = ovl_collateral.positions(pos_id)

    brownie.chain.mine(timedelta=position['exitSeconds'])

    total_oi, total_oi_shares, price_frame = market.positionInfo(
        position['is_long'],
        pos_price_ix,
        pos_compounding
    )

    total_oi /= 1e18
    total_oi_shares /= 1e18
    pos_oi_shares /= 1e18
    pos_debt /= 1e18
    pos_cost /= 1e18
    price_frame /= 1e18

    expected_value = value(
        total_oi,
        total_oi_shares,
        pos_oi_shares,
        pos_debt,
        price_frame,
        position['is_long']
    )

    expected_reward = expected_value * margin_reward
    expected_liquidations = expected_value - expected_reward
    expected_burn = pos_cost - expected_value

    tx_liq = ovl_collateral.liquidate( pos_id, bob, { 'from': bob } )

    price_index = market.pricePointCurrentIndex()

    print("price index", price_index)

    price_point = market.pricePoints(price_index-2)

    print("price_point", price_point)

    price_point = market.pricePoints(price_index-1)

    print("price_point", price_point)

    _, _, _, pos_price_ix, pos_oi_shares , pos_debt, pos_cost, pos_compounding = ovl_collateral.positions(pos_id)

    print("pos shares", pos_oi_shares)

    # burn = None
    # reward = None
    # for i in range(len(tx_liq.events['Transfer'])):
    #     transfer = tx_liq.events['Transfer'][i]
    #     if transfer['to'] == bob 
    #         reward = transfer['value'] / 1e18
    #     if transfer['to'] == '0x0000000000000000000000000000000000000000':
    #         burn = transfer['value'] / 1e18

    # assert burn == approx(expected_burn), 'liquidate burn amount different than expected'

    # assert reward == approx(), 'liquidate reward differen than expected'

    # liquidations = ovl_collateral.liquidations() / 1e18

    # assert liquidations == approx(expected_liquidations)


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