import pytest

from brownie import chain, reverts, web3
from brownie.test import given, strategy
from collections import OrderedDict
from hypothesis import settings

def test_update_max_compound(token, factory, market, alice, rewards):
    start_block = chain[-1]['number']
    update_period = market.updatePeriod()
    update_blocks = market.MAX_FUNDING_COMPOUND()
    prior_update_block = market.updateBlockLast()

    chain.mine(update_blocks)

    tx = market.update(rewards, {"from": alice})
    curr_update_block = market.updateBlockLast()
    prior_plus_updates = start_block + update_blocks + 1 # plus 1 since tx will mine a block
    assert curr_update_block == prior_plus_updates

    assert 'Update' in tx.events
    assert tx.events['Update'] == OrderedDict({
        'sender': alice.address,
        'rewarded': rewards.address,
        'reward': 0, # TODO: ...
    })
