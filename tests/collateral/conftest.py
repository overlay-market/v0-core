import pytest
from brownie import


@pytest.fixture(scope="module")
def gov(accounts):
    yield accounts[0]



@pytest.fixture(scope="module", params=[8000000])
def create_token(gov, mothership, alice, bob, request):
    sup = request.param

    def create_token(supply=sup):
        tok = gov.deploy(OverlayToken, mothership)
        tok.mint(gov, supply * 10 ** tok.decimals(), {"from": gov})
        tok.transfer(bob, supply * 10 ** tok.decimals(), {"from": gov})
        return tok

    yield create_token


