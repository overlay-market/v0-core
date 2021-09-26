from brownie import chain
from brownie.test import given, strategy
from hypothesis import settings
from decimal import *

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

MIN_COLLATERAL_AMOUNT = 1e16  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
FEE_RESOLUTION = 1e18

@given(
    oi_long=strategy('uint256',
                     min_value=MIN_COLLATERAL_AMOUNT,
                     max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),
    oi_short=strategy('uint256',
                      min_value=MIN_COLLATERAL_AMOUNT,
                      max_value=0.999*OI_CAP*10**TOKEN_DECIMALS),)
@settings(max_examples=1)
def test_update(mothership,
                token,
                market,
                ovl_collateral,
                alice,
                bob,
                rewards,
                oi_long,
                oi_short):

    token.approve(ovl_collateral, 1e70, {"from": bob})

    update_period = market.updatePeriod()

    # do an initial update before build so all oi is queued
    market.update({"from": bob})

    tx_long = ovl_collateral.build(market, oi_long, 1, True, {"from": bob})
    tx_short = ovl_collateral.build(market, oi_short, 1, False, {"from": bob})

    print_logs(tx_long)
    print_logs(tx_short)

    pos_long_id = tx_long.events['Build']['positionId']
    pos_short_id = tx_short.events['Build']['positionId']

    pos_long_bal = ovl_collateral.balanceOf(bob, pos_long_id)
    pos_short_bal = ovl_collateral.balanceOf(bob, pos_short_id)

    # prior fee state
    margin_burn_rate, fee_burn_rate, fee_to = mothership.getUpdateParams()
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

    chain.mine(timestamp=chain[-1].timestamp + update_period)

    tx = ovl_collateral.update(market, {"from": alice})

    print("oi long", oi_long)
    print("oi short", oi_short)

    print_logs(tx)

    ovl_collateral_balance_now = token.balanceOf(ovl_collateral)

    fee_to_balance_now = token.balanceOf(fee_to)
    total_supply_now = token.totalSupply()

    burn_amount = Decimal(prior_fees) * ( Decimal(fee_burn_rate) / Decimal(1e18) )

    print("prior total supply", prior_total_supply)
    print("total supply now", total_supply_now)
    print("burn amount", burn_amount)

    print("prior ovl collateral balance", prior_balance_ovl_collateral)
    print("prior fee to balance", prior_balance_fee_to)

    print("ovl_collateral_balance_now", ovl_collateral_balance_now)
    print("fee to balance now", fee_to_balance_now)

    # test burn amount
    assert int(total_supply_now) == int(Decimal(prior_total_supply) - burn_amount)

    assert int(fee_to_balance_now) == int(Decimal(prior_fees) * ( Decimal(fee_burn_rate) / Decimal(1e18)))


def test_update_funding_burn():
    pass


def test_update_funding_k():
    # TODO: test for different k values via an adjust
    pass


def test_update_early():
    # TODO: number of update periods have gone by is zero so nothing
    # should happen to state
    pass


def test_update_between_periods(token, factory, ovl_collateral, market,
                                alice, rewards):
    update_period = market.updatePeriod()
    window_size = market.windowSize()
    prior_update_block = market.updateBlockLast()

    latest_block = chain[-1]['number']
    if int((latest_block - prior_update_block) / update_period) > 0:
        ovl_collateral.update(market, {"from": alice})
        latest_block = chain[-1]['number']
        prior_update_block = market.updateBlockLast()

    blocks_to_mine = update_period - (latest_block - prior_update_block) - 2

    chain.mine(blocks_to_mine, timestamp=chain[-1].timestamp - window_size)

    # Should not update since update period hasn't passed yet
    ovl_collateral.update(market, {"from": alice})

    curr_update_block = market.updateBlockLast()
    assert curr_update_block == prior_update_block


def test_update_max_compound(token, factory, market, alice, rewards):
    pass
