import pytest
from brownie import OverlayToken


@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts[0]


@pytest.fixture(scope="module")
def alice(accounts):
    yield accounts[1]


@pytest.fixture(scope="module")
def bob(accounts):
    yield accounts[2]


@pytest.fixture(scope="module")
def rando(accounts):
    yield accounts[3]


@pytest.fixture(scope="module")
def collateral(accounts):
    yield accounts[4]


@pytest.fixture(scope="module")
def market(accounts):
    yield accounts[5]


@pytest.fixture(scope="module", params=[8000000])
def create_token(gov, alice, bob, request):
    sup = request.param

    def create_token(supply=sup):
        tok = gov.deploy(OverlayToken)
        tok.mint(gov, supply * 10 ** tok.decimals(), {"from": gov})
        tok.transfer(bob, supply * 10 ** tok.decimals(), {"from": gov})
        return tok

    yield create_token


@pytest.fixture(scope="module")
def token(create_token):
    yield create_token()
