from brownie import (
    accounts,
    Scratchpad
)


def main():

    scratch = accounts[0].deploy(Scratchpad)

    (lhs, cum) = scratch.liq()

    print("lhs", lhs)

    print("cum", cum)
