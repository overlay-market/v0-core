import pytest
import brownie
from brownie import ETH_ADDRESS, OverlayToken, chain, interface


TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000


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
    last_timestamp = chain.time()
    r = 50
    return (
        [ last_timestamp - r + i for i in range(1, r) ],
        [ i * 10 ** decimals for i in range(1, r) ],
        [ (1 / i) * 10 ** decimals for i in range(1, r) ]
    )


@pytest.fixture(
    scope="module",
    params=[
        ("OverlayMirinFactory", [15, 5000, 100, ETH_ADDRESS, 60, 50, ETH_ADDRESS],
         "OverlayMirinMarket", [True, 4, 24, 100, OI_CAP*10**TOKEN_DECIMALS, 1, 8],
         "MirinFactoryMock", [],
         "IMirinOracle"),
    ])
def create_factory(token, gov, feed_owner, price_points, request):
    ovlf_name, ovlf_args, _, ovlm_args, fdf_name, fdf_args, ifdp_name = request.param
    ovlf = getattr(brownie, ovlf_name)
    fdf = getattr(brownie, fdf_name)

    ifdp = getattr(interface, ifdp_name)

    def create_factory(
        tok = token,
        ovlf_type = ovlf,
        ovlf_args = ovlf_args,
        ovlm_args = ovlm_args,
        fdf_type = fdf,
        fdf_args = fdf_args,
        ifdp_type = ifdp,
    ):
        feed = feed_owner.deploy(fdf_type, *fdf_args)
        timestamps, p0cs, p1cs = price_points
        feed.createPool(
            timestamps,
            p0cs,
            p1cs,
            {"from": feed_owner}
        )
        pool_addr = feed.allPools(0)
        pool = ifdp_type(pool_addr)

        factory = gov.deploy(ovlf_type, tok, feed, *ovlf_args)
        tok.grantRole(tok.ADMIN_ROLE(), factory, {"from": gov})
        factory.createMarket(pool, *ovlm_args, {"from": gov})
        return factory

    yield create_factory


@pytest.fixture(scope="module")
def factory(create_factory):
    yield create_factory()


@pytest.fixture(
    scope="module",
    params=["IOverlayMarket"])
def market(factory, request):
    addr = factory.allMarkets(0)
    market = getattr(interface, request.param)(addr)
    yield market
