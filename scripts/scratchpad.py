from brownie import *
from brownie import interface
from brownie import \
    Scratchpad, \
    chain, \
    accounts
import os
import json

def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))

def main():

    test = accounts[6].deploy(Scratchpad)

    test.setCodex(
        True,
        1e18,
        .5e18,
        .123456e18,
        .123456e18
    )

    _marge = test.getMarginRewardRate()
    print("marge", _marge)
    _marge = test.getMarginMaintenance()
    print("marge", _marge)

    _1, _2, _3, _4, _5, _6 = test.getCodex()

    print("1", _1)
    print("2", _2)
    print("3", _3)
    print("4", _4)
    print("5", _5)
    print("6", _6)
