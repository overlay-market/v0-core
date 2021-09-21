import pytest

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

def set_compound(sender, factory, market, compound):
    args = market_params(market)
    args[1] = compound
    factory.adjustParamsPerMarket(args, { 'from': sender })

def set_update(sender, factory, market, update):
    args = market_params(market)
    args[0] = update
    factory.adjustParamsPerMarket(args, { 'from': sender })

def market_params(market):
    return (
        market.address,
        market.updatePeriod(),
        market.compoundingPeriod(),
        market.oiCap(),
        market.fundingKNumerator(),
        market.fundingKDenominator(),
        market.leverageMax()
    )

def print_events(events):
    for i in range(len(events['log'])):
        print(
            events['log'][i]['k'] + ": " 
            + str(events['log'][i]['v'])
        )

@given(
    oi_long=strategy('uint256',
                     min_value=MIN_COLLATERAL_AMOUNT,
                     max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    oi_short=strategy('uint256',
                      min_value=MIN_COLLATERAL_AMOUNT,
                      max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    num_periods=strategy('uint16', min_value=1, max_value=144),
)
@settings(max_examples=1)
def test_update(token,
                factory,
                market,
                ovl_collateral,
                alice,
                bob,
                rewards,
                oi_long,
                oi_short,
                num_periods):

    update_period = market.updatePeriod()

    feed = market.feed()

    token.approve(ovl_collateral, 1e70, {"from": bob})

    # do an initial update before build so all oi is queued
    market.update({"from": alice})

    ovl_collateral.build(market, oi_long, True, 1, bob, {"from": bob})
    ovl_collateral.build(market, oi_short, False, 1, bob, {"from": bob})

    # prior fee state
    _, fee_burn_rate, fee_reward_rate, fee_to = factory.getUpdateParams()
    prior_fees = ovl_collateral.fees()

    # prior token balances
    prior_balance_ovl_collateral = token.balanceOf(ovl_collateral)
    prior_balance_fee_to = token.balanceOf(fee_to)
    prior_balance_rewards_to = token.balanceOf(rewards)
    prior_total_supply = token.totalSupply()

    # prior oi state
    prior_queued_oi_long = market.queuedOiLong()
    prior_queued_oi_short = market.queuedOiShort()
    prior_oi_long = market.oiLong()
    prior_oi_short = market.oiShort()

    # prior price point state
    prior_price_point_idx = market.pricePointCurrentIndex()

    # prior epochs
    prior_updated = market.updated()
    prior_compounded = market.compounded()

    # Calc reward rate before update
    reward_perc = fee_reward_rate / 1e18

    expected_fee_reward = int(reward_perc * prior_fees)

    chain.mine(timestamp=chain[-1].timestamp + update_period)

    tx = ovl_collateral.update(market, rewards, {"from": alice})

    curr_updated = market.updated()
    assert  curr_updated == prior_updated + update_period

    # check update event attrs
    assert 'FundingPaid' in tx.events
    assert 'NewPrice' in tx.events
    assert tx.events['Update']['rewarded'] == rewards.address
    assert abs(tx.events['Update']['rewardAmount'] - expected_fee_reward) <= 1

    # Check queued OI settled
    expected_oi_long = prior_queued_oi_long + prior_oi_long
    expected_oi_short = prior_queued_oi_short + prior_oi_short

    curr_queued_oi_long = market.queuedOiLong()
    curr_queued_oi_short = market.queuedOiShort()
    curr_oi_long = market.oiLong()
    curr_oi_short = market.oiShort()

    assert curr_queued_oi_long == 0
    assert curr_queued_oi_short == 0
    assert curr_oi_long == expected_oi_long
    assert curr_oi_short == expected_oi_short

    # Check price points updated ...
    expected_price_point_idx = prior_price_point_idx + 1
    assert market.pricePointCurrentIndex() == expected_price_point_idx

    # ... and price has settled
    assert market.pricePoints(prior_price_point_idx) > 0

    # Check fee burn ...
    expected_fee_burn = int(prior_fees * fee_burn_rate / FEE_RESOLUTION)
    expected_total_supply = prior_total_supply - expected_fee_burn
    curr_total_supply = token.totalSupply()
    assert abs(curr_total_supply - expected_total_supply) <= 1

    # ... and rewards sent to address to be rewarded
    expected_balance_rewards_to = prior_balance_rewards_to + expected_fee_reward
    curr_balance_rewards_to = token.balanceOf(rewards)
    assert abs(curr_balance_rewards_to - expected_balance_rewards_to) <= 1

    # ... and fees forwarded
    expected_balance_ovl_collateral = prior_balance_ovl_collateral - prior_fees
    expected_fee_forward = prior_fees - expected_fee_burn - expected_fee_reward
    expected_balance_fee_to = prior_balance_fee_to + expected_fee_forward

    curr_balance_fee_to = token.balanceOf(fee_to)
    curr_balance_ovl_collateral = token.balanceOf(ovl_collateral)
    assert abs(curr_balance_fee_to - expected_balance_fee_to) <= 1
    assert curr_balance_ovl_collateral == expected_balance_ovl_collateral

    # Check cumulative fee pot zeroed
    assert ovl_collateral.fees() == 0

    # Now do a longer update ...
    update_delta = num_periods * update_period

    ovl_collateral.build(market, oi_long, True, 1, bob, {"from": bob})
    ovl_collateral.build(market, oi_short, False, 1, bob, {"from": bob})

    chain.mine(1, timestamp=chain[-1].timestamp + update_delta)

    tx = ovl_collateral.update(market, rewards, {"from": alice})

    curr_oi_imb = curr_oi_long - curr_oi_short
    curr_oi_tot = curr_oi_long + curr_oi_short

    # plus 1 since tx will mine a block
    assert curr_updated == prior_updated + update_delta

    # check update event attrs
    assert 'Update' in tx.events
    assert 'FundingPaid' in tx.events
    assert 'NewPrice' in tx.events
    assert tx.events['Update']['rewarded'] == rewards.address
    assert tx.events['Update']['rewardAmount'] == 0  # rewarded 0 since no positions built

    # check funding payments over longer period
    k = market.fundingKNumerator() / market.fundingKDenominator()
    expected_oi_imb = curr_oi_imb * (1 - 2*k)**num_periods
    expected_oi_long = int((curr_oi_tot + expected_oi_imb) / 2) * 2
    expected_oi_short = int((curr_oi_tot - expected_oi_imb) / 2) * 2

    next_oi_long = market.oiLong()
    next_oi_short = market.oiShort()

    assert abs(next_oi_long - expected_oi_long) <= 1
    assert abs(next_oi_short - expected_oi_short) <= 1


def test_update_funding_burn():
    pass


def test_update_funding_k():
    # TODO: test for different k values via an adjust
    pass


def test_update_early():
    # TODO: number of update periods have gone by is zero so nothing
    # should happen to state
    pass


def test_update_between_periods(token, factory, ovl_collateral, market, alice, rewards):
    update_period = market.updatePeriod()
    window_size = market.windowSize()
    prior_update_block = market.updateBlockLast()

    latest_block = chain[-1]['number']
    if int((latest_block - prior_update_block) / update_period) > 0:
        ovl_collateral.update(market, rewards, {"from": alice})
        latest_block = chain[-1]['number']
        prior_update_block = market.updateBlockLast()

    blocks_to_mine = update_period - (latest_block - prior_update_block) - 2

    chain.mine(blocks_to_mine, timestamp=chain[-1].timestamp - window_size)

    # Should not update since update period hasn't passed yet
    ovl_collateral.update(market, rewards, {"from": alice})

    curr_update_block = market.updateBlockLast()
    assert curr_update_block == prior_update_block


def test_update_max_compound(token, factory, market, alice, rewards):
    pass
