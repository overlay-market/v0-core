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

