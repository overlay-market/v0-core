import pytest

from brownie import reverts, chain
from brownie.test import given, strategy

# def test_sanity(m_gen):

#     hello = m_gen.test();

#     assert hello == "hello"

#     update_block = m_gen.updateBlockLast()
#     deploy_block = chain.height()

#     assert update_block == "f"
    

def test_thing(m_gen, alice, rewards):

    update_block = m_gen.updateBlockLast()
    current_block = chain.height
    update_period = m_gen.updatePeriod()
    assert update_block == chain.height
    chain.mine(int( update_period / 2 ))
    tx = m_gen.update(rewards, {"from": alice})
    curr_update_block = m_gen.updateBlockLast()
    assert  chain.height - curr_update_block == 13
    chain.mine(int( update_period / 2 ))
    tx = m_gen.update(rewards, {"from": alice})
    curr_update_block = m_gen.updateBlockLast()
    assert  chain.height == curr_update_block


