from brownie import *
from brownie import interface
from brownie import \
    UniswapV3FactoryMock, \
    OverlayV1Mothership, \
    OverlayV1OVLCollateral, \
    OverlayV1UniswapV3Market, \
    OverlayToken, \
    chain, \
    accounts
import os
import json


''' OVERLAY TOKEN PARAMETERS '''
TOKEN_TOTAL_SUPPLY = 8000000e18

''' OVERLAY QUANTO DAI/ETH MARKET PARAMETERS '''
AMOUNT_IN = 1e18
PRICE_WINDOW_MACRO = 3600
PRICE_WINDOW_MICRO = 600

K = 343454218783234
PRICE_FRAME_CAP = 5e18
SPREAD = .00573e18

UPDATE_PERIOD = 100
COMPOUND_PERIOD = 600

IMPACT_WINDOW = 600

LAMBDA = .6e18
STATIC_CAP = 370400e18
BRRRR_EXPECTED = 26320e18
BRRRR_WINDOW_MACRO = 2592000
BRRRR_WINDOW_MICRO = 86400

''' OVERLAY QUANTO DAI_ETH MARKET PARAMETERS ON OVL COLLATERAL MANAGER '''
MARGIN_MAINTENANCE = .06e18
MARGIN_REWARD_RATE = .5e18
MAX_LEVERAGE = 100

''' OVERLAY MOTHERSHIP PARAMETERS '''
FEE = .0015e18
FEE_BURN_RATE = .5e18
MARGIN_BURN_RATE = .5e18

''' GENERAL FEED PARAMETERS '''
DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
AXS = "0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b"
USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

''' GENERAL ACCOUNTS '''
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

    return uniswapv3_pool


def deploy_ovl():

    ovl = GOV.deploy(OverlayToken)
    ovl.mint(ALICE, TOKEN_TOTAL_SUPPLY / 2, { "from": GOV })
    ovl.mint(BOB, TOKEN_TOTAL_SUPPLY / 2, { "from": GOV })

    return ovl


def deploy_mothership(ovl):

    mothership = GOV.deploy(
        OverlayV1Mothership, 
        FEE_TO, 
        FEE, 
        FEE_BURN_RATE, 
        MARGIN_BURN_RATE
    )

    mothership.setOVL(ovl, { "from": GOV })

    ovl.grantRole(ovl.ADMIN_ROLE(), mothership, { "from": GOV })

    return mothership


def deploy_market(mothership, feed_depth, feed_market):

    market = GOV.deploy(
        OverlayV1UniswapV3Market,
        mothership,
        feed_depth,
        feed_market,
        WETH,
        WETH,
        AMOUNT_IN,
        PRICE_WINDOW_MACRO,
        PRICE_WINDOW_MICRO
    )

    market.setEverything(
        K,
        PRICE_FRAME_CAP,
        SPREAD,
        UPDATE_PERIOD,
        COMPOUND_PERIOD,
        IMPACT_WINDOW,
        LAMBDA,
        STATIC_CAP,
        BRRRR_EXPECTED,
        BRRRR_WINDOW_MACRO,
        BRRRR_WINDOW_MICRO,
        { "from": GOV }
    )

    mothership.initializeMarket(market, { "from": GOV })

    return market


def deploy_ovl_collateral(mothership, market, ovl):

    ovl_collateral = GOV.deploy(
        OverlayV1OVLCollateral,
        "uri",
        mothership
    )

    ovl_collateral.setMarketInfo(
        market,
        MARGIN_MAINTENANCE,
        MARGIN_REWARD_RATE,
        MAX_LEVERAGE,
        { "from": GOV }
    )

    market.addCollateral(ovl_collateral, { "from": GOV })

    mothership.initializeCollateral(ovl_collateral, { "from": GOV })

    ovl.approve(ovl_collateral, 1e50, { "from": ALICE })
    ovl.approve(ovl_collateral, 1e50, { "from": BOB })

    return ovl_collateral

def build_position(
    collateral_manager, 
    market, 
    collateral, 
    leverage, 
    is_long, 
    taker
):

    tx_build = collateral_manager.build(
        market,
        collateral,
        leverage,
        is_long,
        { "from": taker }
    )

    position = tx_build.events['Build']['positionId']
    oi = tx_build.events['Build']['oi']
    debt = tx_build.events['Build']['debt']
    collateral = oi - debt

    return {
        'market': market,
        'collateral_manager': collateral_manager,
        'id': position,
        'oi': oi,
        'collateral': collateral,
        'leverage': leverage,
        'is_long': is_long
    }

def unwind_position(
    collateral_manager,
    position_id,
    position_shares,
    unwinder
):

    tx_unwind = collateral_manager.unwind(
        position_id,
        position_shares,
        { "from": unwinder }
    )


def transfer_position_shares(
    collateral_manager,
    sender,
    receiver,
    position_id,
    amount
):

    tx_transfer = collateral_manager.safeTransferFrom(
        sender,
        receiver,
        position_id,
        amount,
        "",
        { "from": sender }
    )


def main():

    uni_factory = deploy_uni_factory()

    feed_depth = deploy_uni_pool(uni_factory, AXS, WETH, '../feeds/univ3_axs_weth')

    feed_market = deploy_uni_pool(uni_factory, DAI, WETH, '../feeds/univ3_dai_weth')

    ovl = deploy_ovl()

    mothership = deploy_mothership(ovl)

    market = deploy_market(mothership, feed_depth, feed_market)

    ovl_collateral = deploy_ovl_collateral(mothership, market, ovl)

    chain.mine( timedelta=market.compoundingPeriod() * 3 )

    position_one = build_position(
        ovl_collateral,
        market,
        5e18,
        5,
        True,
        ALICE
    )

    chain.mine( timedelta=market.updatePeriod() * 2 )

    position_two = build_position(
        ovl_collateral,
        market,
        5e18,
        5,
        True,
        ALICE
    )

    transfer_position_shares(
        ovl_collateral, 
        ALICE, 
        BOB, 
        position_one['id'], 
        2.5e18
    )

    unwind_position(
        ovl_collateral,
        position_one['id'],
        2.5e18,
        BOB
    )

    unwind_position(
        ovl_collateral,
        position_one['id'],
        2.5e18,
        ALICE
    )

    print("market            :", market)
    print("ovl_collateral    :", ovl_collateral)
    print("alice             :", ALICE)
    print("bob               :", BOB)
    print("gov               :", GOV)
    print("fee_to            :", FEE_TO)
