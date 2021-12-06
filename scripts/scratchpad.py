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

    tx = test.failure()

    print_logs(tx)

