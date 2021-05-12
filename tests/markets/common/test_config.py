import pytest
import brownie
import re


def test_balances(token, gov, rewards, alice, bob, feed_owner):
    assert token.totalSupply() == token.balanceOf(bob)
    assert token.balanceOf(gov) == 0
    assert token.balanceOf(rewards) == 0
    assert token.balanceOf(alice) == 0
    assert token.balanceOf(feed_owner) == 0


def test_roles(token, gov, feed_owner, factory, market, alice, bob):
    assert token.hasRole(token.ADMIN_ROLE(), gov) is True
    assert token.hasRole(token.MINTER_ROLE(), feed_owner) is False
    assert token.hasRole(token.BURNER_ROLE(), feed_owner) is False

    assert token.hasRole(token.ADMIN_ROLE(), factory) is True
    assert token.hasRole(token.MINTER_ROLE(), factory) is False
    assert token.hasRole(token.BURNER_ROLE(), factory) is False

    assert token.hasRole(token.ADMIN_ROLE(), alice) is False
    assert token.hasRole(token.MINTER_ROLE(), alice) is False
    assert token.hasRole(token.BURNER_ROLE(), alice) is False

    assert token.hasRole(token.ADMIN_ROLE(), bob) is False
    assert token.hasRole(token.MINTER_ROLE(), bob) is False
    assert token.hasRole(token.MINTER_ROLE(), bob) is False

    assert token.hasRole(token.MINTER_ROLE(), market) is True
    assert token.hasRole(token.BURNER_ROLE(), market) is True
    assert token.hasRole(token.ADMIN_ROLE(), market) is False


def test_markets(factory, market):
    assert factory.allMarkets(0) == market.address


def test_market_is_enabled(factory, market):
    assert factory.isMarket(market) == True


def test_market_erc1155(market):
    match = re.fullmatch(
        r"https://metadata.overlay.exchange/(\w+)/{id}.json",
        market.uri(0),
    )
    assert match is not None
