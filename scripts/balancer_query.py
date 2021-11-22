from brownie import (
    accounts,
    interface,
    BalancerQueries
)


account = accounts.load('tester')


def main():

    balancer = account.deploy(
        BalancerQueries,
        "0x0b09dea16768f0799065c475be02919503cb2a35"
    )

    ten, hour, ten_d = balancer.twa()

    print("ten", ten)
    print("hour", hour)
    print("ten_d", ten_d)

    weights = balancer.weights()

    print("weights", weights)