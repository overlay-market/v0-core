import pytest

from brownie import chain, reverts, web3
from brownie.test import given, strategy
from collections import OrderedDict


@given(num_periods=strategy('uint16', min_value=1, max_value=144))
def test_update(token, factory, market, alice, rewards, num_periods):
    update_period = market.updatePeriodSize()
    update_blocks = num_periods * update_period
    prior_update_block = market.updateBlockLast()

    chain.mine(update_blocks)
    updatable = market.updatable()
    assert updatable is True

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()
    prior_plus_updates = prior_update_block + update_blocks + 1 # plus 1 since tx will mine a block
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0, # TODO: ...
    })


def test_update_between_periods(token, factory, market, alice, rewards):
    update_period = market.updatePeriodSize()
    update_blocks = update_period - 2
    prior_update_block = market.updateBlockLast()

    chain.mine(update_blocks-1)
    updatable = market.updatable()
    assert updatable is False

    market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()
    assert curr_update_block == prior_update_block


def test_update_max_compound(token, factory, market, alice, rewards):
    update_period = market.updatePeriodSize()
    update_blocks = market.MAX_FUNDING_COMPOUND() + 10
    prior_update_block = market.updateBlockLast()

    chain.mine(update_blocks)
    updatable = market.updatable()
    assert updatable is True

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()
    prior_plus_updates = prior_update_block + update_blocks + 1 # plus 1 since tx will mine a block
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0, # TODO: ...
    })
