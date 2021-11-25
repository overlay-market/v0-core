import json
import os
from brownie import (
    accounts,
    chain,
    OverlayToken,
    OverlayV1Mothership,
    OverlayV1OVLCollateral,
    OverlayV1UniswapV3Market,
    UniswapV3FactoryMock,
    UniswapV3OracleMock,
)


DEPLOYER = accounts.load('tester')

AXS = "0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b"
WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
MOCK_OVL_FEED_TOKEN0 = AXS
MOCK_OVL_FEED_TOKEN1 = WETH

ONE_DAY = 86400


def FIRST_deploy_ovl_mock_feed():

    base = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base, '../../feeds/univ3_axs_weth_raw_uni.json')

    with open(os.path.normpath(path)) as file:
        data = json.load(file)

    data.reverse()

    data = data[:700]

    now = chain.time()

    mock_start = now - 4200

    earliest = data[0]['observation'][0]

    obs = []
    shims = []

    for d in data:
        ob = d['observation']
        shim = d['shim']
        time_diff = ob[0] - earliest
        ob[0] = shim[0] = mock_start + time_diff
        obs.append(ob)
        shims.append(shim)

    uv3_factory = DEPLOYER.deploy(UniswapV3FactoryMock)

    uv3_factory.createPool(MOCK_OVL_FEED_TOKEN0, MOCK_OVL_FEED_TOKEN1)

    uv3_pool = UniswapV3OracleMock.at(uv3_factory.allPools(0))

    ob_chunks = [ obs[x:x+175] for x in range(0, len(obs), 175) ]
    shim_chunks = [ shims[x:x+175] for x in range(0, len(shims), 175) ]

    for i in range(len(ob_chunks)):
        success = False
        while not success:
            try:
                uv3_pool.loadObservations(
                    ob_chunks[i],
                    shim_chunks[i],
                    { 'from': DEPLOYER } )
                success = True
            except: print("Retrying.")

    print("WETH/AXS Mock Address: ", uv3_pool.address)

    return uv3_pool


DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
MOCK_ETH_DAI_FEED_TOKEN0 = DAI
MOCK_ETH_DAI_FEED_TOKEN1 = WETH
def SECOND_deploy_weth_dai_mock_feed():

    base = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base, '../../feeds/univ3_dai_weth_raw_uni.json')

    with open(os.path.normpath(path)) as file:
        data = json.load(file)

    data.reverse()

    data = data[:700]

    now = chain.time()

    mock_start = now - 4200

    earliest = data[0]['observation'][0]

    obs = []
    shims = []

    for d in data:
        ob = d['observation']
        shim = d['shim']
        time_diff = ob[0] - earliest
        ob[0] = shim[0] = mock_start + time_diff
        obs.append(ob)
        shims.append(shim)

    uv3_factory = DEPLOYER.deploy(UniswapV3FactoryMock)

    uv3_factory.createPool(
        MOCK_ETH_DAI_FEED_TOKEN0,
        MOCK_ETH_DAI_FEED_TOKEN1
    )

    uv3_pool = UniswapV3OracleMock.at(uv3_factory.allPools(0))

    ob_chunks = [ obs[x:x+175] for x in range(0, len(obs), 175) ]
    shim_chunks = [ shims[x:x+175] for x in range(0, len(shims), 175) ]

    for i in range(len(ob_chunks)):
        success = False
        while not success:
            try:
                uv3_pool.loadObservations(
                    ob_chunks[i],
                    shim_chunks[i],
                    { 'from': DEPLOYER } )
                success = True
            except: print("Retrying.")

    print("WETH/DAI Mock Address: ", uv3_pool.address)

    return uv3_pool
    

TOTAL_SUPPLY = 8_000_000e18
def THIRD_deploy_ovl_token():

    ovl = DEPLOYER.deploy(OverlayToken)

    ovl.mint(DEPLOYER, TOTAL_SUPPLY, { 'from': DEPLOYER })

    print("Overlay Token Address: ", ovl.address)

    return ovl

FEE = .0015e18
FEE_BURN_RATE = .5e18
MARGIN_BURN_RATE = .5e18
def FOURTH_deploy_mothership(ovl_token):

    mothership = DEPLOYER.deploy(OverlayV1Mothership,
        DEPLOYER,
        FEE,
        FEE_BURN_RATE,
        MARGIN_BURN_RATE )

    ovl_token.grantRole(
        ovl_token.ADMIN_ROLE(), 
        mothership, 
        { 'from': DEPLOYER } )

    return mothership


TEN_MINUTES = 600
ONE_HOUR = 3600
SEVEN_DAYS = 604800

BASE_AMOUNT = 1e18
PRICE_WINDOW_MACRO = ONE_HOUR
PRICE_WINDOW_MICRO = TEN_MINUTES
PRICE_FRAME_CAP = 5e18
K = 343454218783234
SPREAD = .00573e18
COMPOUND_PERIOD = 600
LAMBDA = 0
OI_CAP = 800_000e18
BRRRR_EXPECTED = 26_320e18
BRRRR_WINDOW_MACRO = SEVEN_DAYS
BRRRR_WINDOW_MICRO = TEN_MINUTES
def FIFTH_deploy_overlay_eth_dai_market(
    mothership, 
    market_feed,
    ovl_feed
):

    market = DEPLOYER.deploy(
        OverlayV1UniswapV3Market,
        mothership,
        ovl_feed,
        market_feed,
        WETH, # TODO: What is the deal with this market quote.
        WETH,
        BASE_AMOUNT,
        PRICE_WINDOW_MACRO,
        PRICE_WINDOW_MICRO,
        PRICE_FRAME_CAP
    )

    market.setEverything(
        K,
        SPREAD,
        COMPOUND_PERIOD,
        LAMBDA,
        OI_CAP,
        BRRRR_EXPECTED,
        BRRRR_WINDOW_MACRO,
        BRRRR_WINDOW_MICRO,
        { 'from': DEPLOYER }
    )

    print("Overlay WETH/DAI Market Address: ", market)

    return market


URI = "https://degenscore.com"
MARGIN_MAINTENANCE = .06e18
MARGIN_REWARD_RATE = .5e18
MAX_LEVERAGE = 100
def SIXTH_deploy_ovl_collateral(mothership, eth_dai_market):

    ovl_collateral = DEPLOYER.deploy(
        OverlayV1OVLCollateral, 
        URI, mothership
    )

    ovl_collateral.setMarketInfo(
        eth_dai_market,
        MARGIN_MAINTENANCE,
        MARGIN_REWARD_RATE,
        MAX_LEVERAGE,
        { 'from': DEPLOYER }
    )

    eth_dai_market.addCollateral(ovl_collateral, { 'from': DEPLOYER })

    print("Overlay Collateral Address: ", ovl_collateral.address)

    return ovl_collateral


def main():

    mock_ovl_feed       = FIRST_deploy_ovl_mock_feed()

    mock_weth_dai_feed  = SECOND_deploy_weth_dai_mock_feed()

    ovl_token           = THIRD_deploy_ovl_token()

    mothership          = FOURTH_deploy_mothership(ovl_token)

    eth_dai_market      = FIFTH_deploy_overlay_eth_dai_market(
        mothership,
        mock_weth_dai_feed, 
        mock_ovl_feed, 
    )

    ovl_collateral      = SIXTH_deploy_ovl_collateral(
        mothership,
        eth_dai_market
    )

    print("deployed")



