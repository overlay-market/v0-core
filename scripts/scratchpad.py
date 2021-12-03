from brownie import *
from brownie import interface
from brownie import \
    Scratchpad, \
    chain, \
    accounts
import os
import json


def main():

    test = accounts[6].deploy(Scratchpad)

    a,b = test.one_and_two()

    print("a", a)
    print("b", b)


