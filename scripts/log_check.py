
from brownie import (
    accounts,
    network,
    UniTest
)


def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))


def main():

    multiplex_tester = accounts[6].deploy(
        UniTest,
        1e18,                                         # weth base amount
        "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth base
        "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", # usdc quote
        "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", # usdc/weth uni
        1e8,                                          # wbtc base amount
        "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599", # wbtc base
        "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth quote
        "0xcbcdf9626bc03e24f779434178a73a0b4bad62ed", # weth/wbtc uni
        1e8                                           # multiplex base amount
        # 1e18,                                         # ens base amount
        # "0xc18360217d8f7ab5e7c516566761ea12ce7f9d72", # ens base
        # "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth quote
        # "0x92560c178ce069cc014138ed3c2f5221ba71f58a", # weth/ens uni
        # 1e6                                           # multiplex quote amount
    )

    print("deployed")

    tx = multiplex_tester.testMultiplex()

    print_logs(tx)

