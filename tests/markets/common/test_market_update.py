import pytest

from brownie import chain, reverts, web3
from brownie.test import given, strategy
from collections import OrderedDict


@given(num_periods=strategy('uint16', min_value=1, max_value=144))
def test_update(token, factory, market, alice, rewards, num_periods):
    start_block = chain[-1]['number']
    update_period = market.updatePeriod()
    update_blocks = num_periods * update_period

    chain.mine(update_blocks)

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()

    prior_plus_updates = start_block + update_blocks + 1  # plus 1 since tx will mine a block
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0,  # TODO: ...
    })


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
    prior_plus_updates = start_block + update_blocks + 1  # plus 1 since tx will mine a block
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0,  # TODO: ...
    })
