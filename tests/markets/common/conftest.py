import pytest
import brownie
import os
import json
from brownie import \
    ETH_ADDRESS,\
    OverlayToken,\
    ComptrollerShim,\
    chain,\
    interface


TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000
AMOUNT_IN = 1
PRICE_POINTS_START = 50
PRICE_POINTS_END = 100
FIRST_TIMESTAMP = chain.time()


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
def create_token(gov, alice, bob):
    sup = TOKEN_TOTAL_SUPPLY

    def create_token(supply=sup):
        tok = gov.deploy(OverlayToken)
        tok.mint(gov, supply * 10 ** tok.decimals(), {"from": gov})
        ts = tok.totalSupply()
        tok.transfer(bob, supply * 10 ** tok.decimals(), {"from": gov})
        return tok

    yield create_token


@pytest.fixture(scope="module")
def token(create_token):
    yield create_token()


@pytest.fixture(scope="module")
def feed_owner(accounts):
    yield accounts[6]


@pytest.fixture(scope="module")
def price_points(token):
    # TODO: json import of real data ...
    decimals = token.decimals()
    price_range = range(1, PRICE_POINTS_START)
    return (
        [FIRST_TIMESTAMP - PRICE_POINTS_START + i for i in price_range],
        [i * 10 ** decimals for i in price_range],
        [(1 / i) * 10 ** decimals for i in price_range]
    )


@pytest.fixture(scope="module")
def price_points_after(token):
    decimals = token.decimals()
    price_range = range(PRICE_POINTS_START, PRICE_POINTS_END)
    return (
        [FIRST_TIMESTAMP - PRICE_POINTS_START + i for i in price_range],
        [i * 10 ** decimals for i in price_range],
        [(1 / i) * 10 ** decimals for i in price_range]
    )

def get_uni_oracle (feed_owner):

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

    # TODO: place token0 and token1 into the json
    uniswapv3_factory.createPool(
        "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    );

    uniswapv3_mock = IUniswapV3OracleMock( uniswapv3_factory.allPools(0) )

    for i in range(len(obs)):
        uniswapv3_mock.loadObservations(obs[i], shims[i], { 'from': feed_owner })

    chain.mine(1, timestamp=chain[-1].timestamp + 1200)

    return uniswapv3_factory.address, uniswapv3_mock.address


@pytest.fixture( scope="module" )
def comptroller(gov):
    comptroller = gov.deploy(ComptrollerShim, 600, 60)
    yield comptroller

@pytest.fixture(
    scope="module",
    params=[
        ("OverlayV1UniswapV3Deployer", [],
         "OverlayV1UniswapV3Factory", [15, 5000, 100, ETH_ADDRESS, 60, 50, 25], 
         "OverlayV1UniswapV3Market", [ 10, 10, 10, 600, 60, OI_CAP*10**TOKEN_DECIMALS, 3293944666953, 9007199254740992, 100, AMOUNT_IN*10**TOKEN_DECIMALS, True ],
         get_uni_oracle,
        ),
    ])
def create_factory(token, gov, feed_owner, request):
    ovlmd_name, _, ovlf_name, ovlf_args, __, ovlm_args, get_feed = request.param

    ovlmd = getattr(brownie, ovlmd_name)
    ovlf = getattr(brownie, ovlf_name)

    def create_factory(
        tok=token,
        ovlmd_type=ovlmd,
        ovlf_type=ovlf,
        ovlf_args=ovlf_args,
        ovlm_args=ovlm_args,
        fd_getter=get_feed
    ):
        print("create factory")

        feed_factory, feed_addr = fd_getter(feed_owner)

        deployer = gov.deploy(ovlmd_type)
        factory = gov.deploy(ovlf_type, tok, deployer, feed_factory, *ovlf_args)
        tok.grantRole(tok.ADMIN_ROLE(), factory, {"from": gov})
        factory.createMarket(feed_addr, *ovlm_args, {"from": gov})

        chain.mine(ovlm_args[0]) # mine the update period

        return factory

    yield create_factory

@pytest.fixture(scope="module")
def ovl_collateral(factory, market, gov, token):
    OvlCollateral = getattr(brownie, 'OverlayV1OVLCollateral')
    collateral_man = OvlCollateral.deploy(
        "", 
        token, 
        factory,
        { 'from': gov }
    )
    market.addCollateral(collateral_man, { 'from': gov })
    token.grantRole(token.MINTER_ROLE(), collateral_man, { 'from': gov })
    token.grantRole(token.BURNER_ROLE(), collateral_man, { 'from': gov })
    yield collateral_man

@pytest.fixture(scope="module")
def factory(create_factory):
    yield create_factory()

@pytest.fixture(
    scope="module",
    params=["IOverlayV1Market"])
def market(factory, request):
    addr = factory.allMarkets(0)
    market = getattr(interface, request.param)(addr)
    yield market

