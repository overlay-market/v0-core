import pytest
import brownie


def test_only_minter(token, alice):
    with brownie.reverts():
        token.mint(alice, 1 * 10 ** token.decimals(), {"from": alice})


def test_only_burner(token, bob):
    with brownie.reverts():
        token.burn(bob, 1 * 10 ** token.decimals(), {"from": bob})


def test_mint(token, minter, alice):
    before = token.balanceOf(alice)
    amount = 1 * 10 ** token.decimals()
    token.mint(alice, amount, {"from": minter})
    assert token.balanceOf(alice) == before + amount


def test_burn(token, burner, bob):
    before = token.balanceOf(bob)
    amount = 1 * 10 ** token.decimals()
    token.burn(bob, amount, {"from": burner})
    assert token.balanceOf(bob) == before - amount


def test_mint_then_burn(token, admin, alice):
    before = token.balanceOf(alice)
    token.mint(alice, 20 * 10 ** token.decimals(), {"from": admin})
    mid = before + 20 * 10 ** token.decimals()
    assert token.balanceOf(alice) == mid
    token.burn(alice, 15 * 10 ** token.decimals(), {"from": admin})
    assert token.balanceOf(alice) == mid - 15 * 10 ** token.decimals()
