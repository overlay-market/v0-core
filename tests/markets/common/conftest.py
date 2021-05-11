import pytest
import brownie


@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts[0]


@pytest.fixture(scope="module")
def rewards(accounts):
    yield brownie.ETH_ADDRESS


@pytest.fixture(scope="module")
def alice(accounts):
    yield accounts[2]


@pytest.fixture(scope="module")
def bob(accounts):
    yield accounts[3]


@pytest.fixture(scope="module", params=[8000000])
def create_token(gov, alice, bob, request):
    sup = request.param
    def create_token(supply=sup):
        tok = gov.deploy(brownie.OVLToken)
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


@pytest.fixture(
    scope="module",
    params=[
        ("OVLMirinFactory", [15, 5000, 100, brownie.ETH_ADDRESS, 60, 50, brownie.ETH_ADDRESS],
         "MirinFactoryMock", []),
    ])
def create_factory(token, gov, feed_owner, request):
    ovlf_name, ovlf_args, fdf_name, fdf_args = request.param
    ovlf = getattr(brownie, ovlf_name)
    fdf = getattr(brownie, fdf_name)

    def create_factory(
        tok = token,
        ovlf_type=ovlf,
        ovlf_args = ovlf_args,
        fdf_type=fdf,
        fdf_args = fdf_args,
    ):
        feed = feed_owner.deploy(fdf_type, *fdf_args)
        factory = gov.deploy(ovlf_type, tok, feed, *ovlf_args)
        tok.grantRole(tok.ADMIN_ROLE(), factory, {"from": gov})
        return factory

    yield create_factory


@pytest.fixture(scope="module")
def factory(create_factory):
    yield create_factory()
