import pytest

from brownie import chain, reverts, web3
from brownie.test import given, strategy
from collections import OrderedDict


MIN_COLLATERAL_AMOUNT = 10**4  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
FEE_RESOLUTION = 1e4


def _build_positions(token, market, bob, oi_long, oi_short):
    token.approve(market, oi_long+oi_short, {"from": bob})
    # 1x long w oi_long as collateral
    if oi_long >= MIN_COLLATERAL_AMOUNT:
        market.build(oi_long, True, 1, bob, {"from": bob})
    # 1x short w oi_short as collateral
    if oi_short >= MIN_COLLATERAL_AMOUNT:
        market.build(oi_short, False, 1, bob, {"from": bob})


@given(
    oi_long=strategy('uint256',
                     min_value=0,
                     max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    oi_short=strategy('uint256',
                      min_value=0,
                      max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    num_periods=strategy('uint16', min_value=1, max_value=144),
)
def test_update(token,
                factory,
                market,
                alice,
                bob,
                rewards,
                oi_long,
                oi_short,
                num_periods):
    start_block = chain[-1]['number']
    update_period = market.updatePeriod()

    # queue up bob's positions to be settled at next update (T+1)
    _build_positions(token, market, bob, oi_long, oi_short)
    prior_queued_oi_long = market.queuedOiLong()
    prior_queued_oi_short = market.queuedOiShort()

    _, _, reward_rate, _ = factory.getFeeParams()
    reward_perc = reward_rate / FEE_RESOLUTION
    reward_amount = reward_perc * market.fees()

    chain.mine(update_period)

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()

    # plus 1 since tx will mine a block
    prior_plus_updates = start_block + update_period + 1
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': reward_amount,
    })

    # Check queued OI settled
    expected_oi_long = prior_queued_oi_long
    expected_oi_short = prior_queued_oi_short
    curr_queued_oi_long = market.queuedOiLong()
    curr_queued_oi_short = market.queuedOiShort()
    curr_oi_long = market.oiLong()
    curr_oi_short = market.oiShort()

    assert curr_oi_long == expected_oi_long
    assert curr_oi_short == expected_oi_short
    assert curr_queued_oi_long == 0
    assert curr_queued_oi_short == 0

    curr_oi_imb = curr_oi_long - curr_oi_short
    curr_oi_tot = curr_oi_long + curr_oi_short

    # Check price points updated

    # Check fee burn and forward

    # Now do a longer update ...
    # TODO: rename vars to next_ ...
    update_blocks = num_periods * update_period
    chain.mine(update_blocks)

    tx = market.update(rewards, {"from": alice})
    next_update_block = market.updateBlockLast()

    # plus 1 since tx will mine a block
    next_block = chain[-1]['number']
    curr_plus_updates = next_block + update_blocks + 1
    assert next_update_block == curr_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0,  # rewarded 0 since no positions built
    })

    # check funding payments over longer period
    expected_oi_imb = curr_oi_imb * (1 - 2*k)**num_periods
    if curr_oi_long == 0:
        expected_oi_long = 0
        expected_oi_short = expected_oi_imb
    elif curr_oi_short == 0:
        expected_oi_long = expected_oi_imb
        expected_oi_short = 0
    else:
        expected_oi_long = (curr_oi_tot + expected_oi_imb) / 2
        expected_oi_short = (curr_oi_tot - expected_oi_imb) / 2

    next_oi_long = market.oiLong()
    next_oi_short = market.oiShort()
    assert next_oi_long == expected_oi_long
    assert next_oi_short == expected_oi_short


def test_update_early():
    # TODO: number of update periods have gone by is zero so nothing should happen to state
    pass


def test_update_between_periods(token, factory, market, alice, rewards):
    update_period = market.updatePeriod()
    update_blocks = update_period
    prior_update_block = market.updateBlockLast()

    latest_block = chain[-1]['number']
    if int((latest_block - prior_update_block) / update_period) > 0:
        market.update(rewards, {"from": alice})
        latest_block = chain[-1]['number']
        prior_update_block = market.updateBlockLast()

    blocks_to_mine = update_period - (latest_block - prior_update_block) - 2

    chain.mine(blocks_to_mine)

    # Should not update since update period hasn't passed yet
    market.update(rewards, {"from": alice})

    curr_update_block = market.updateBlockLast()
    assert curr_update_block == prior_update_block


def test_update_max_compound(token, factory, market, alice, rewards):
    start_block = chain[-1]['number']
    update_period = market.updatePeriod()
    update_blocks = market.MAX_FUNDING_COMPOUND()
    prior_update_block = market.updateBlockLast()

    chain.mine(update_blocks)

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()

    # plus 1 since tx will mine a block
    prior_plus_updates = start_block + update_blocks + 1
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0,  # TODO: ...
    })
