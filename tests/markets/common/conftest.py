import pytest
import brownie
import os
import json
import time
from brownie import \
    ETH_ADDRESS,\
    OverlayToken,\
    ComptrollerShim,\
    chain,\
    interface,\
    UniTest


TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000e18
OI_CAP = 800000
AMOUNT_IN = 1
PRICE_POINTS_START = 50
PRICE_POINTS_END = 100

@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts[0]

@pytest.fixture(scope="module")
def rewards(accounts):
    yield accounts[1]

@pytest.fixture(scope="module")
def alice(accounts):
    yield accounts[2]

@pytest.fixture(scope="module")
def bob(accounts):
    yield accounts[3]

@pytest.fixture(scope="module")
def feed_owner(accounts):
    yield accounts[6]

@pytest.fixture(scope="module")
def create_token(gov, alice, bob):
    sup = TOKEN_TOTAL_SUPPLY

    def create_token(mothership, supply=sup):
        tok = gov.deploy(OverlayToken, mothership)
        tok.mint(gov, supply, {"from": gov})
        ts = tok.totalSupply()
        tok.transfer(bob, supply, {"from": gov})
        return tok

    yield create_token

def get_uni_feeds (feed_owner):

    base = os.path.dirname(os.path.abspath(__file__))
    path = '../../../feeds/historic_observations/univ3_dai_weth.json'

    with open(os.path.normpath(os.path.join(base, path))) as f:
        feed = json.load(f)
    
    now = chain[-1].timestamp
    earliest = feed[-1]['shim'][0]
    diff = 0

    feed.reverse()

    obs = [ ] # blockTimestamp, tickCumulative, liquidityCumulative, initialized 
    shims = [ ] # timestamp, liquidity, tick, cardinality 

    feed = feed[:300]

    feed = [ feed[i:i+300] for i in range(0,len(feed),300) ]

    for fd in feed:
        obs.append([])
        shims.append([])
        for f in fd:
            diff = f['shim'][0] - earliest
            f['observation'][0] = f['shim'][0] = now + diff
            obs[len(obs)-1].append(f['observation'])
            shims[len(shims)-1].append(f['shim'])
    
    UniswapV3MockFactory = getattr(brownie, 'UniswapV3FactoryMock')
    IUniswapV3OracleMock = getattr(interface, 'IUniswapV3OracleMock')

    uniswapv3_factory = feed_owner.deploy(UniswapV3MockFactory)

    token0 = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    token1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

    # TODO: place token0 and token1 into the json
    uniswapv3_factory.createPool(
        token0,
        token1,
    );

    uniswapv3_mock = IUniswapV3OracleMock( uniswapv3_factory.allPools(0) )

    for i in range(len(obs)):
        uniswapv3_mock.loadObservations(obs[i], shims[i], { 'from': feed_owner })

    chain.mine(1, timestamp=chain[-1].timestamp + 1200)

    return uniswapv3_factory.address, uniswapv3_mock.address, uniswapv3_mock.address, token1

@pytest.fixture( scope="module" )
def comptroller(gov):
    comptroller = gov.deploy(ComptrollerShim, 1e24, 600, 1653439153439, 1e18)
    yield comptroller

@pytest.fixture(
    scope="module",
    params=[
        ("OverlayV1Mothership", [
            .5e18,         # margin burn rate
            .00015e18,    # fee
            .5e18,        # fee burn rate
            .001e18,      # update reward rate
        ], 
         "OverlayV1UniswapV3MarketZeroComptrollerShim", [ 
            1e18,                # amount in
            600,                 # macro window
            60,                  # micro window
            343454218783234,     # k
            100,                 # levmax
            5e18,                # payoff cap
            .00573e18,           # spread
            600,                 # update period
            600,                 # compound period
            600,                 # impact window
            OI_CAP*1e18,         # oi cap
            0,                   # lambda
            1e18,                # brrrr fade
         ],
         "OverlayV1OVLCollateral", [
             .06e18,             # margin maintenance
             .5e18,              # margin reward rate
         ],
         get_uni_feeds,
        ),
    ])
def create_mothership(create_token, alice, bob, gov, rewards, feed_owner, request):
    ovlms_name, ovlms_args, ovlm_name, ovlm_args, ovlc_name, ovlc_args, get_feed = request.param

    chain.mine(timestamp=int(time.time()))

    ovlms = getattr(brownie, ovlms_name)
    ovlm = getattr(brownie, ovlm_name)
    ovlc = getattr(brownie, ovlc_name)

    ovlms_args.append(rewards)

    def create_mothership(
        c_tok=create_token,
        ovlms_type=ovlms,
        ovlms_args=ovlms_args,
        ovlm_type=ovlm,
        ovlm_args=ovlm_args,
        ovlc_type=ovlc,
        ovlc_args=ovlc_args,
        fd_getter=get_feed
    ):
        feed_factory, ovl_feed, market_feed, quote = fd_getter(feed_owner)

        mothership = gov.deploy(ovlms_type, *ovlms_args)

        eth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

        tok = c_tok(mothership)

        mothership.setOVL(tok, { 'from': gov })

        print("ovlm_type", ovlm_type)
        print("mothership", mothership)
        print("ovl feed", ovl_feed)
        print("market_feed", market_feed)
        print("quote", quote)
        print("eth", eth)

        market = gov.deploy(ovlm_type, mothership, ovl_feed, market_feed, quote, eth, *ovlm_args[:3])
        market.setEverything(*ovlm_args[3:], { "from": gov })
        mothership.initializeMarket(market, { "from": gov})

        ovl_collateral = gov.deploy(ovlc_type, "our_uri", mothership)
        ovl_collateral.setMarketInfo(market, *ovlc_args, { "from": gov })
        mothership.initializeCollateral(ovl_collateral)

        market.addCollateral(ovl_collateral, { 'from': gov })

        tok.approve(ovl_collateral, 1e50, { "from": alice })
        tok.approve(ovl_collateral, 1e50, { "from": bob })

        chain.mine(timedelta=ovlm_args[1]) # mine the update period

        return mothership

    yield create_mothership

@pytest.fixture(scope="module")
def mothership(create_mothership):
    yield create_mothership()

@pytest.fixture(scope="module")
def token(mothership):
    yield getattr(interface, 'IOverlayToken')(mothership.ovl())

@pytest.fixture(
    scope="module",
    params=['IOverlayV1OVLCollateral'])
def ovl_collateral(mothership, request):
    addr = mothership.allCollateral(0)
    ovl_collateral = getattr(interface, request.param)(addr)
    yield ovl_collateral

@pytest.fixture(
    scope="module",
    params=["IOverlayV1Market"])
def market(mothership, request):
    addr = mothership.allMarkets(0)
    market = getattr(interface, request.param)(addr)
    yield market



@pytest.fixture(scope="module")
def uni_test(gov, rewards, accounts):

    dai_eth = "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8"
    usdc_eth = "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8"
    wbtc_eth = "0xcbcdf9626bc03e24f779434178a73a0b4bad62ed"
    uni_eth = "0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801"
    link_eth = "0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8"
    aave_eth = "0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB"

    usdc = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    eth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    wbtc = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"
    uni = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"
    link = "0x514910771AF9Ca656af840dff83E8264EcF986CA"
    aave = "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9"

    # we are trying to find amount USDC in OVL terms

    unitest = rewards.deploy(
        UniTest, 
        eth,
        usdc,
        usdc_eth,
        aave,
        eth,
        aave_eth
    )

    yield unitest
