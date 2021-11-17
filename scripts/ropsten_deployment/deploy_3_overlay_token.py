
from brownie import (
    accounts,
    OverlayToken
)


GOV = accounts.load('tester')

TOTAL_SUPPLY = 8_000_000e18

def main():

    ovl = GOV.deploy(OverlayToken)

    ovl.mint(GOV, TOTAL_SUPPLY, { 'from': GOV })

    print("Overlay Token Address: ", ovl.address)
