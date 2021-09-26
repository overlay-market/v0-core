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

    # prior fee state
    margin_burn_rate, fee_burn_rate, fee_to = mothership.getUpdateParams()
    fees = ovl_collateral.fees()

    prior_total_supply = token.totalSupply()

    ovl_collateral.update(market, {"from": alice})

    fee_to_balance_now = token.balanceOf(fee_to)
    total_supply_now = token.totalSupply()

    burn_amount = Decimal(fees) * ( Decimal(fee_burn_rate) / Decimal(1e18) )

    # test burn amount
    assert int(total_supply_now) == int(Decimal(prior_total_supply) - burn_amount)

    # test fee amount
    assert int(fee_to_balance_now) == int(Decimal(fees) - burn_amount)


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
