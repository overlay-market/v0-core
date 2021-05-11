import pytest
import brownie

def test_balances(token, gov, rewards, alice, bob, feed_owner):
    assert token.totalSupply() == token.balanceOf(bob)
    assert token.balanceOf(gov) == 0
    assert token.balanceOf(rewards) == 0
    assert token.balanceOf(alice) == 0
    assert token.balanceOf(feed_owner) == 0


def test_roles(token, gov, feed_owner, factory):
    assert token.hasRole(token.ADMIN_ROLE(), gov) is True
    assert token.hasRole(token.MINTER_ROLE(), feed_owner) is False
    assert token.hasRole(token.BURNER_ROLE(), feed_owner) is False
    assert token.hasRole(token.ADMIN_ROLE(), factory) is True


def test_markets(factory, market):
    assert factory.allMarkets(0) == market.address


def test_erc1155(market):
    assert market.uri(0) == "https://metadata.overlay.exchange/mirin/{id}.json"
