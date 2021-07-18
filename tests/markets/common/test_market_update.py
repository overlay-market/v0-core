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
FEE_RESOLUTION = 1e4


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
                alice,
                bob,
                rewards,
                oi_long,
                oi_short,
                num_periods):

    update_period = market.updatePeriod()

    mubl = market.updateBlockLast()

    print(time.time(), "oi_long", oi_long, "oi_short", oi_short)

    print("block",
        "\n current", chain[-1].number,
        "\n update block last", mubl
    )

    print("update period", update_period)


    # queue up bob's positions to be settled at next update (T+1)
    # 1x long w oi_long as collateral and 1x short with oi_short
    token.approve(market, oi_long+oi_short, {"from": bob})

    print("approve")

    window_size = market.windowSize()

    print("window size")
    # do an initial update before build so all oi is queued
    tsbu1 = token.totalSupply()
    mu1 = market.update(rewards, {"from": alice})
    print("update")

    assert 'Update' in mu1.events

    # build so all oi is queued
    # TODO: check no issues when some queued, some settled

    tsbb = token.totalSupply()
    mbbb = token.balanceOf(market)
    txbl = market.build(oi_long, True, 1, bob, {"from": bob})
    mbabl = token.balanceOf(market)
    tsabl = token.totalSupply()
    txbs = market.build(oi_short, False, 1, bob, {"from": bob})
    mbabs = token.balanceOf(market)
    tsabs = token.totalSupply()

    print("market update tx",
        "\n timestamp", mu1.timestamp,
        "\n block number", mu1.block_number)

    print("market build long tx",
        "\n timestamp", txbl.timestamp,
        "\n block number", txbl.block_number)

    print("market build short tx",
        "\n timestamp", txbs.timestamp,
        "\n block number", txbs.block_number)

    if 'Update' in txbl.events:
        print("update called in build long")
    if 'Update' in txbs.events:
        print("update called in build short")

    print("oi", 
        "\n oi long", oi_long, 
        "\n oi short", oi_short
    )
    print("total supply",
        "\n before build", tsbb,
        "\n after build long", tsabl,
        "\n after build short", tsabs
    )
    print("market balance",
        "\n before building", mbbb,
        "\n after build long", mbabl,
        "\n after build short", mbabs
    )

    # prior fee state
    _, fee_burn_rate, fee_reward_rate, fee_to = factory.getUpdateParams()
    prior_fees = market.fees()
    print("fees")

    # prior token balances
    prior_balance_market = token.balanceOf(market)
    prior_balance_fee_to = token.balanceOf(fee_to)
    prior_balance_rewards_to = token.balanceOf(rewards)
    prior_total_supply = token.totalSupply()

    print( "prior balance",
        "\n market    ", prior_balance_market,
        "\n fee to    ", prior_balance_fee_to,
        "\n reward to ", prior_balance_rewards_to
    )

    # prior oi state
    prior_queued_oi_long = market.queuedOiLong()
    prior_queued_oi_short = market.queuedOiShort()
    prior_oi_long = market.oiLong()
    prior_oi_short = market.oiShort()
    print("prior oi", 
        "\n qoil   ", prior_queued_oi_long,
        "\n oil    ", prior_oi_long,
        "\n qois   ", prior_queued_oi_short,
        "\n ois    ", prior_oi_short
    )

    # prior price point state
    prior_price_point_idx = market.pricePointCurrentIndex()
    print("price pp ix")

    # Calc reward rate before update
    reward_perc = fee_reward_rate / FEE_RESOLUTION
    expected_fee_reward = int(reward_perc * prior_fees)

    start_block = chain[-1]['number']
    chain.mine(update_period+1, timestamp=chain[-1].timestamp + window_size)

    tx = market.update.transact(rewards, {"from": alice})
    print("~~~~ update ~~~~~")

    curr_update_block = market.updateBlockLast()

    # plus another 1 since tx will mine a block
    prior_plus_updates = start_block + update_period + 2
    assert curr_update_block == prior_plus_updates

    # check update event attrs
    assert 'Update' in tx.events
    assert tx.events['Update']['rewarded'] == rewards.address
    assert (
        tx.events['Update']['reward'] == expected_fee_reward
        or tx.events['Update']['reward'] == expected_fee_reward - 1
    )

    price_len = market.pricePointCurrentIndex()
    prices = []
    for i in range(price_len):
        prices.append(market.pricePoints(i))

    print("prices", prices)
    print("p oi long", prior_oi_long, "q", prior_queued_oi_long)
    print("p oi short", prior_oi_short, "q", prior_queued_oi_short)

    # Check queued OI settled
    expected_oi_long = prior_queued_oi_long + prior_oi_long
    expected_oi_short = prior_queued_oi_short + prior_oi_short

    curr_queued_oi_long = market.queuedOiLong()
    curr_queued_oi_short = market.queuedOiShort()
    curr_oi_long = market.oiLong()
    curr_oi_short = market.oiShort()

    print("c oi long", curr_oi_long, "q", curr_queued_oi_long)
    print("c oi short", curr_oi_short, "q", curr_queued_oi_short)

    assert curr_queued_oi_long == 0
    assert curr_queued_oi_short == 0
    assert curr_oi_long == expected_oi_long
    assert curr_oi_short == expected_oi_short

    curr_oi_imb = curr_oi_long - curr_oi_short
    curr_oi_tot = curr_oi_long + curr_oi_short

    # Check price points updated ...
    expected_price_point_idx = prior_price_point_idx + 1
    curr_price_point_idx = market.pricePointCurrentIndex()
    assert curr_price_point_idx == expected_price_point_idx

    # ... and price has settled
    assert market.pricePoints(prior_price_point_idx) > 0

    # Check fee burn ...
    expected_fee_burn = int(prior_fees * fee_burn_rate / FEE_RESOLUTION)
    expected_total_supply = prior_total_supply - expected_fee_burn
    curr_total_supply = token.totalSupply()
    assert (
        curr_total_supply == expected_total_supply
        or curr_total_supply == expected_total_supply + 1
    )

    # ... and rewards sent to address to be rewarded
    expected_balance_rewards_to = prior_balance_rewards_to + expected_fee_reward
    curr_balance_rewards_to = token.balanceOf(rewards)
    assert (
        curr_balance_rewards_to == expected_balance_rewards_to
        or curr_balance_rewards_to == expected_balance_rewards_to - 1
    )

    # ... and fees forwarded
    expected_balance_market = prior_balance_market - prior_fees
    expected_fee_forward = prior_fees - expected_fee_burn - expected_fee_reward
    expected_balance_fee_to = prior_balance_fee_to + expected_fee_forward

    curr_balance_fee_to = token.balanceOf(fee_to)
    curr_balance_market = token.balanceOf(market)
    assert (
        curr_balance_fee_to == expected_balance_fee_to
        or curr_balance_fee_to == expected_balance_fee_to - 1
    )
    assert curr_balance_market == expected_balance_market

    # Check cumulative fee pot zeroed
    assert market.fees() == 0

    # Now do a longer update ...
    curr_block = chain[-1]['number']
    update_blocks = num_periods * update_period
    chain.mine(update_blocks, timestamp=chain[-1].timestamp + window_size)

    tx = market.update(rewards, {"from": alice})
    next_update_block = market.updateBlockLast()

    # plus 1 since tx will mine a block
    curr_plus_updates = curr_block + update_blocks + 1
    assert next_update_block == curr_plus_updates

    # check update event attrs
    assert 'Update' in tx.events
    assert tx.events['Update']['rewarded'] == rewards.address
    assert tx.events['Update']['reward'] == 0  # rewarded 0 since no positions built

    # check funding payments over longer period
    k = market.fundingKNumerator() / market.fundingKDenominator()
    expected_oi_imb = curr_oi_imb * (1 - 2*k)**num_periods
    expected_oi_long = int((curr_oi_tot + expected_oi_imb) / 2)
    expected_oi_short = int((curr_oi_tot - expected_oi_imb) / 2)

    next_oi_long = market.oiLong()
    next_oi_short = market.oiShort()

    assert (
        next_oi_long == expected_oi_long
        or next_oi_long == expected_oi_long - 1
    )
    assert (
        next_oi_short == expected_oi_short
        or next_oi_short == expected_oi_short + 1
    )


def test_update_funding_burn():
    pass


def test_update_funding_k():
    # TODO: test for different k values via an adjust
    pass


def test_update_early():
    # TODO: number of update periods have gone by is zero so nothing
    # should happen to state
    pass


def test_update_between_periods(token, factory, market, alice, rewards):
    update_period = market.updatePeriod()
    window_size = market.windowSize()
    prior_update_block = market.updateBlockLast()

    latest_block = chain[-1]['number']
    if int((latest_block - prior_update_block) / update_period) > 0:
        market.update(rewards, {"from": alice})
        latest_block = chain[-1]['number']
        prior_update_block = market.updateBlockLast()

    blocks_to_mine = update_period - (latest_block - prior_update_block) - 2

    chain.mine(blocks_to_mine, timestamp=chain[-1].timestamp - window_size)

    # Should not update since update period hasn't passed yet
    market.update(rewards, {"from": alice})

    curr_update_block = market.updateBlockLast()
    assert curr_update_block == prior_update_block


def test_update_max_compound(token, factory, market, alice, rewards):
    pass
