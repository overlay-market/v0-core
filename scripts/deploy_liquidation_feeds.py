from brownie import interface
from brownie import \
    ERC20Mock, \
    UniswapV3FactoryMock, \
    OverlayV1Mothership, \
    OverlayV1OVLCollateral, \
    OverlayV1UniswapV3Market, \
    OverlayToken, \
    chain, \
    accounts
import time


def print_logs(tx):
    if 'log' in tx.events:
        for i in range(len(tx.events['log'])):
            print(tx.events['log'][i]['k'] + ": " +
                  str(tx.events['log'][i]['v']))


''' OVERLAY TOKEN PARAMETERS '''
TOKEN_TOTAL_SUPPLY = 8000000e18

''' OVERLAY QUANTO DAI/ETH MARKET PARAMETERS '''
AMOUNT_IN = 1e18
PRICE_WINDOW_MACRO = 3600
PRICE_WINDOW_MICRO = 600

K = 343454218783234
PRICE_FRAME_CAP = 5e18
SPREAD = .00573e18

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
    '''
    Deploys the UniswapV3FactoryMock on the Feed Owner's behalf.

    Output:
        [Contract]:  UniswapV3FactoryMock contract instance
    '''
    return FEED_OWNER.deploy(UniswapV3FactoryMock)


def deploy_uni_pool(factory, token0, token1, feed):
    '''
    Inputs:
      factory [Contract]:  UniswapV3FactoryMock contract instance
      token0  [str]:       First token contract address in the token pair
      token1  [str]:       Second token contract address in the token pair
      path    [str]:       Path to directory containing mock feed data
    '''

    beginning = feed['observations'][0][0]

    # Creates a pool with the provided token pair
    factory.createPool(token0, token1)

    # Get instance of the IUniswapV3OracleMock contract interface
    IUniswapV3OracleMock = getattr(interface, 'IUniswapV3OracleMock')

    uniswapv3_pool = IUniswapV3OracleMock(factory.allPools(0))

    uniswapv3_pool.loadObservations(
        feed['observations'],
        feed['shims'],
        {'from': FEED_OWNER}
    )

    chain.mine(timestamp=beginning + 3600)

    return uniswapv3_pool


def deploy_ovl():

    ovl = GOV.deploy(OverlayToken)
    ovl.mint(ALICE, TOKEN_TOTAL_SUPPLY / 2, {"from": GOV})
    ovl.mint(BOB, TOKEN_TOTAL_SUPPLY / 2, {"from": GOV})

    return ovl


def deploy_mothership(ovl):

    mothership = GOV.deploy(
        OverlayV1Mothership,
        ovl,
        FEE_TO,
        FEE,
        FEE_BURN_RATE,
        MARGIN_BURN_RATE
    )

    ovl.grantRole(ovl.ADMIN_ROLE(), mothership, {"from": GOV})

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
        PRICE_WINDOW_MICRO,
        PRICE_FRAME_CAP
    )

    market.setEverything(
        K,
        SPREAD,
        COMPOUND_PERIOD,
        LAMBDA,
        STATIC_CAP,
        BRRRR_EXPECTED,
        BRRRR_WINDOW_MACRO,
        BRRRR_WINDOW_MICRO,
        {"from": GOV}
    )

    mothership.initializeMarket(market, {"from": GOV})

    return market


def deploy_ovl_collateral(mothership, ovl, markets):

    ovl_collateral = GOV.deploy(
        OverlayV1OVLCollateral,
        "uri",
        mothership
    )

    for i in range(len(markets)):

        ovl_collateral.setMarketInfo(
            markets[i],
            MARGIN_MAINTENANCE,
            MARGIN_REWARD_RATE,
            MAX_LEVERAGE,
            {"from": GOV}
        )

        markets[i].addCollateral(ovl_collateral, {"from": GOV})

    mothership.initializeCollateral(ovl_collateral, {"from": GOV})

    ovl.approve(ovl_collateral, 1e50, {"from": ALICE})
    ovl.approve(ovl_collateral, 1e50, {"from": BOB})

    return ovl_collateral


def build_position(collateral_manager, market, collateral, leverage, is_long,
                   taker):

    tx_build = collateral_manager.build(market, collateral, leverage, is_long,
                                        0, {"from": taker})

    print_logs(tx_build)

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


def unwind_position(collateral_manager, position_id, position_shares,
                    unwinder):
    collateral_manager.unwind(position_id, position_shares, {"from": unwinder})


def transfer_position_shares(collateral_manager, sender, receiver, position_id,
                             amount):
    collateral_manager.safeTransferFrom(sender, receiver, position_id, amount,
                                        "", {"from": sender})


def transfer_position_shares_batch(collateral_manager, sender, receiver,
                                   position_ids, amounts):
    collateral_manager.safeBatchTransferFrom(sender, receiver, position_ids,
                                             amounts, "", {"from": sender})


def feeds():
    ''' Synthesized UniV3 oracle mock price feed rigged to liquidate longs.
        Price decreases by about two percent per period. '''
    long_liquidation_feed = {
        'observations': [],
        'shims': []
    }

    ''' Synthesized UniV3 oracle mock price feed rigged to liquidate shorts.
        Price increases by about two percent per period.  '''
    short_liquidation_feed = {
        'observations': [],
        'shims': []
    }

    ''' Synthesized price feed for UniV3 oracle mock rigged to zig zag half
        the time increasing price by about two percent per period while the
        other half decreases.  '''
    zig_zag_feed = {
        'observations': [],
        'shims': []
    }

    ''' Synthesized UniV3 oracle mock price feed rigged to always report the
        same price and liquidity to minimize variation in the caps. '''
    depth_feed = {
        'observations': [],
        'shims': []
    }

    cur_tick = 0
    cum_tick = 0

    cur_liq = 4880370053085953032800977
    cum_liq = 0

    delta = 15

    start = int(time.time())

    cur_tick = -10000

    now = start
    for i in range(1000):  # long feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        long_liquidation_feed['observations'].append(
            [now, cum_tick, cum_liq, True])
        long_liquidation_feed['shims'].append([now, cur_liq, cur_tick, i])

        cur_tick -= 200  # decrease tick to lower price

    cur_tick = -100000
    now = start
    for i in range(1000):  # short feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        short_liquidation_feed['observations'].append(
            [now, cum_tick, cum_liq, True])
        short_liquidation_feed['shims'].append([now, cur_liq, cur_tick, i])

        cur_tick += 200  # increase tick to raise price

    cur_tick = -50000
    now = start
    for i in range(1000):  # zig zag feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        zig_zag_feed['observations'].append([now, cum_tick, cum_liq, True])
        zig_zag_feed['shims'].append([now, cur_liq, cur_tick, i])

        if ((i//100) % 2):  # increase if hundredth is even
            cur_tick += 200
        else:               # decrease if hundredth is odd
            cur_tick -= 200

    cur_tick = 8000
    cur_liq = 4880370053085953032800977
    cum_liq = 0
    now = start
    for i in range(1000):  # zig zag feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        depth_feed['observations'].append([now, cum_tick, cum_liq, True])
        depth_feed['shims'].append([now, cur_liq, cur_tick, i])

    return (
        long_liquidation_feed,
        short_liquidation_feed,
        zig_zag_feed,
        depth_feed
    )


def main():

    uni_factory = deploy_uni_factory()

    ovl = deploy_ovl()

    ZIG_ZAG = accounts[0].deploy(ERC20Mock, "ZIG_ZAG", "ZIG_ZAG")
    LONG_LIQ = accounts[0].deploy(ERC20Mock, "LONG_LIQ", "LONG_LIQ")
    SHORT_LIQ = accounts[0].deploy(ERC20Mock, "SHORT_LIQ", "SHORT_LIQ")

    (long_liqs, short_liqs, zig_zags, depth) = feeds()

    depth_feed = deploy_uni_pool(uni_factory, WETH, ovl, depth)

    long_liq_feed = deploy_uni_pool(uni_factory, WETH, LONG_LIQ, long_liqs)
    short_liq_feed = deploy_uni_pool(uni_factory, WETH, SHORT_LIQ, short_liqs)
    zig_zag_feed = deploy_uni_pool(uni_factory, WETH, ZIG_ZAG, zig_zags)

    mothership = deploy_mothership(ovl)

    long_liq_market = deploy_market(mothership, depth_feed, long_liq_feed)
    short_liq_market = deploy_market(mothership, depth_feed, short_liq_feed)
    zig_zag_market = deploy_market(mothership, depth_feed, zig_zag_feed)

    ovl_collateral = deploy_ovl_collateral(
        mothership,
        ovl,
        [long_liq_market, short_liq_market, zig_zag_market]
        # [long_liq_market]
    )

    chain.mine(timedelta=COMPOUND_PERIOD * 3)

    ll_position_1 = build_position(
        ovl_collateral, long_liq_market, 5e18, 1, True, ALICE)
    _ = build_position(
        ovl_collateral, short_liq_market, 5e18, 1, True, ALICE)
    _ = build_position(
        ovl_collateral, zig_zag_market, 5e18, 1, True, ALICE)

    chain.mine(timedelta=COMPOUND_PERIOD * 2)

    ll_position_2 = build_position(
        ovl_collateral, long_liq_market, 5e18, 5, False, ALICE)

    transfer_position_shares(ovl_collateral, ALICE, BOB, ll_position_1['id'],
                             ll_position_1['oi'] / 2)

    unwind_position(ovl_collateral, ll_position_1['id'],
                    ovl_collateral.balanceOf(BOB, ll_position_1['id']), BOB)

    unwind_position(ovl_collateral, ll_position_1['id'],
                    ovl_collateral.balanceOf(ALICE, ll_position_1['id']), ALICE) # noqa E501

    chain.mine(timedelta=COMPOUND_PERIOD)

    ll_position_3 = build_position(
        ovl_collateral, long_liq_market, 5e18, 1, True, ALICE)

    chain.mine(timedelta=100)

    ll_position_4 = build_position(
        ovl_collateral, long_liq_market, 5e18, 1, True, ALICE)

    chain.mine(timedelta=100)

    ll_position_5 = build_position(
        ovl_collateral, long_liq_market, 5e18, 1, True, ALICE)

    position_ids = [ll_position_3['id'],
                    ll_position_4['id'], ll_position_5['id']]
    amounts = [ll_position_3['oi'],
               ll_position_4['oi'] / 2, ll_position_5['oi'] / 4]

    transfer_position_shares_batch(ovl_collateral, ALICE, BOB, position_ids,
                                   amounts)

    chain.mine(timedelta=100)

    ll_position_6 = build_position(
        ovl_collateral, long_liq_market, 5e18, 1, True, ALICE)

    chain.mine(timedelta=100)

    with open(".subgraph.liquidations.test.env", "w") as f:
        f.write('OVL={}\n'.format(ovl))
        f.write('MOTHERSHIP={}\n'.format(mothership))
        f.write('LONG_LIQ_MARKET={}\n'.format(long_liq_market))
        f.write('SHORT_LIQ_MARKET={}\n'.format(short_liq_market))
        f.write('ZIG_ZAG_MARKET={}\n'.format(zig_zag_market))
        f.write('OVL_COLLATERAL={}\n'.format(ovl_collateral))
        f.write('ALICE={}\n'.format(ALICE))
        f.write('BOB={}\n'.format(BOB))
        f.write('GOV={}\n'.format(GOV))
        f.write('FEE_TO={}\n'.format(FEE_TO))
        f.write('BOB_POSITION_1={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_1['id'])))
        f.write('BOB_POSITION_2={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_2['id'])))
        f.write('BOB_POSITION_3={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_3['id'])))
        f.write('BOB_POSITION_4={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_4['id'])))
        f.write('BOB_POSITION_5={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_5['id'])))
        f.write('BOB_POSITION_5={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_5['id'])))
        f.write('BOB_POSITION_6={}\n'.format(ovl_collateral.balanceOf(BOB,
                ll_position_6['id'])))
        f.write('ALICE_POSITION_1={}\n'.format(ovl_collateral.balanceOf(ALICE,
                ll_position_1['id'])))
        f.write('ALICE_POSITION_2={}\n'.format(ovl_collateral.balanceOf(ALICE,
                ll_position_2['id'])))
        f.write('ALICE_POSITION_3={}\n'.format(ovl_collateral.balanceOf(ALICE,
                ll_position_3['id'])))
        f.write('ALICE_POSITION_4={}\n'.format(ovl_collateral.balanceOf(ALICE,
                ll_position_4['id'])))
        f.write('ALICE_POSITION_5={}\n'.format(ovl_collateral.balanceOf(ALICE,
                ll_position_5['id'])))
        f.write('ALICE_POSITION_6={}\n'.format(ovl_collateral.balanceOf(ALICE,
                ll_position_6['id'])))
