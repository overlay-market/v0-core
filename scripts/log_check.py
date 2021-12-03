
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
        # 1e18,                                         # weth base amount
        # "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth base
        # "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", # usdc quote
        # "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", # usdc/weth uni
        1e18,                                         # weth base amount
        "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth base
        "0xdac17f958d2ee523a2206206994597c13d831ec7", # usdt quote
        "0x4e68ccd3e89f51c3074ca5072bbac773960dfa36", # usdt/weth uni
        # 1e8,                                          # wbtc base amount
        # "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599", # wbtc base
        # "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth quote
        # "0xcbcdf9626bc03e24f779434178a73a0b4bad62ed", # weth/wbtc uni
        # 1e8                                           # multiplex base amount
        1e18,                                         # ens base amount
        "0xc18360217d8f7ab5e7c516566761ea12ce7f9d72", # ens base
        "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth quote
        "0x92560c178ce069cc014138ed3c2f5221ba71f58a", # weth/ens uni
        1e18                                          # multiplex base amount
        # 1e18,                                         # uni base amount
        # "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", # uni base
        # "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth quote
        # "0x1d42064fc4beb5f8aaf85f4617ae8b3b5b8bd801", # weth/uni uni
        # 1e18                                          # multiplex base amount
        # 1e6,                                         # weth base amount
        # "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", # usdc base
        # "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", # weth quote
        # "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", # usdc/weth uni
        # 1e6
    )

    print("deployed")

    tx = multiplex_tester.testMultiplex()

    print_logs(tx)

