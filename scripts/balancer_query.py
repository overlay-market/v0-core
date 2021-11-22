from brownie import (
    accounts,
    interface,
    BalancerQueries
)


account = accounts.load('tester')


def main():

    balancer = account.deploy(
        BalancerQueries,
        "0x0b09dea16768f0799065c475be02919503cb2a35",
        "0xBA12222222228d8Ba445958a75a0704d566BF2C8"
    )

    ten, hour, ten_d = balancer.twa()

    print("ten", ten)

    print("hour", hour)

    print("ten_d", ten_d)

    weights = balancer.weights()

    print("weights", weights)

    id = balancer.id()

    print("id", id)

    tokens = balancer.tokens()

    print("tokens", tokens)
