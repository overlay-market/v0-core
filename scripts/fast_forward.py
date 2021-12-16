from brownie import chain


def main():

    chain.mine(timedelta=3600)