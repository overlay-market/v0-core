from brownie import *
from brownie import interface
from brownie import \
    UniswapV3FactoryMock, \
    OverlayV1Mothership, \
    OverlayToken, \
    chain, \
    accounts
import os
import json

TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000e18
OI_CAP = 800000
AMOUNT_IN = 1
PRICE_POINTS_START = 50
PRICE_POINTS_END = 100

PRICE_WINDOW_MACRO = 3600
PRICE_WINDOW_MICRO = 600

UPDATE_PERIOD = 100
COMPOUND_PERIOD = 600

IMPACT_WINDOW = 600

LAMBDA = .6e18
STATIC_CAP = 370400e18
BRRRR_EXPECTED = 26320e18
BRRRR_WINDOW_MACRO = 2592000
BRRRR_WINDOW_MICRO = 86400


FEE = .0015e18
FEE_BURN_RATE = .5e18
MARGIN_BURN_RATE = .5e18


DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
AXS = "0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b"
USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

ALICE = accounts[2]
BOB = accounts[3]
FEED_OWNER = accounts[6]
GOV = accounts[0]
FEE_TO = accounts[4]


def deploy_uni_factory():

    uniswapv3_factory = FEED_OWNER.deploy(UniswapV3FactoryMock)

    return uniswapv3_factory


def deploy_uni_pool(factory, token0, token1, path):

    base = os.path.dirname(os.path.abspath(__file__))

    with open(os.path.normpath(os.path.join(base, path + '_raw_uni_framed.json'))) as f: 
        data = json.load(f)

    with open(os.path.normpath(os.path.join(base, path + '_reflected.json'))) as f: 
        beginning = json.load(f)['timestamp'][0]

    factory.createPool(token0, token1)

    IUniswapV3OracleMock = getattr(interface, 'IUniswapV3OracleMock')

    uniswapv3_pool = IUniswapV3OracleMock(factory.allPools(0))

    uniswapv3_pool.loadObservations(
        data['observations'],
        data['shims'],
        { 'from': FEED_OWNER }
    )

    chain.mine(timestamp=beginning)

def deploy_ovl():

    ovl = GOV.deploy(OverlayToken)
    ovl.mint(ALICE, TOKEN_TOTAL_SUPPLY / 2, { "from": GOV })
    ovl.mint(BOB, TOKEN_TOTAL_SUPPLY / 2, { "from": GOV })

    return ovl


def deploy_mothership():

    mothership = GOV.deploy(OverlayV1Mothership, FEE_TO, FEE, FEE_BURN_RATE, MARGIN_BURN_RATE)

    return mothership

def main():

    uni_factory = deploy_uni_factory()

    uni_market = deploy_uni_pool(uni_factory, DAI, WETH, '../feeds/univ3_dai_weth')

    ovl = deploy_ovl()

    mothership = deploy_mothership()
