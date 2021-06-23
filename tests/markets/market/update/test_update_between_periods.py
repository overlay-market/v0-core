import pytest

from brownie import chain, reverts, web3
from brownie.test import given, strategy
from collections import OrderedDict
from hypothesis import settings

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