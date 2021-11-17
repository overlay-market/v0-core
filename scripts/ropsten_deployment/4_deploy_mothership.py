from brownie import (
    accounts,
    OverlayToken,
    OverlayV1Mothership
)


FEE = .0015e18
FEE_BURN_RATE = .5e18
MARGIN_BURN_RATE = .5e18

OVL_TOKEN = '0x69d2D936ad815E733f31346e470e4Ad23eF7404b'

GOV = accounts.load('tester')

def main():

    mothership = GOV.deploy(OverlayV1Mothership,
        GOV,
        FEE,
        FEE_BURN_RATE,
        MARGIN_BURN_RATE )

    mothership.setOVL(OVL_TOKEN, { 'from': GOV })

    ovl = OverlayToken.at(OVL_TOKEN)

    ovl.grantRole(ovl.ADMIN_ROLE(), mothership, { 'from': GOV })

    print("Overlay V1 Mothership Address: ", mothership.address)
    