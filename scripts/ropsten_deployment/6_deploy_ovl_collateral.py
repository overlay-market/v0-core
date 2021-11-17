from brownie import (
    accounts,
    OverlayV1UniswapV3Market,
    OverlayV1OVLCollateral
)

URI = "https://degenscore.com"

OVL_TOKEN = '0x69d2D936ad815E733f31346e470e4Ad23eF7404b'

MOTHERSHIP = '0x6a01c92B4D5f25955AE65E3b7cdD49Fe406E3244'
ETH_DAI_MARKET = '0xCbE8FD47bD799B078A0b6cE88e6A76554c581C1a'

GOV = accounts.load('tester')

MARGIN_MAINTENANCE = .06e18
MARGIN_REWARD_RATE = .5e18
MAX_LEVERAGE = 100

def main():

    ovl_collateral = GOV.deploy(OverlayV1OVLCollateral, 
        URI, MOTHERSHIP)

    ovl_collateral.setMarketInfo(
        ETH_DAI_MARKET,
        MARGIN_MAINTENANCE,
        MARGIN_REWARD_RATE,
        MAX_LEVERAGE,
        { 'from': GOV })

    market = OverlayV1UniswapV3Market.at(ETH_DAI_MARKET)

    market.addCollateral(ovl_collateral, { 'from': GOV })

    print("Overlay Collateral Address: ", market.address)