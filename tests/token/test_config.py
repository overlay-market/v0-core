import pytest


def test_balances(token, gov, alice, bob, minter, burner, admin):
    assert token.totalSupply() == token.balanceOf(bob)
    assert token.balanceOf(gov) == 0
    assert token.balanceOf(alice) == 0
    assert token.balanceOf(minter) == 0
    assert token.balanceOf(burner) == 0
    assert token.balanceOf(admin) == 0


def test_roles(token, gov, minter, burner, admin):
    assert token.hasRole(token.ADMIN_ROLE(), gov) is True
    assert token.hasRole(token.MINTER_ROLE(), minter) is True
    assert token.hasRole(token.BURNER_ROLE(), burner) is True

    assert token.hasRole(token.MINTER_ROLE(), admin) is True
    assert token.hasRole(token.BURNER_ROLE(), admin) is True


def test_erc20(token):
    assert token.decimals() == 18
    assert token.name() == "Overlay"
    assert token.symbol() == "OVL"
