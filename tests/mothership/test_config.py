def test_balances(token, gov, alice, bob):
    assert token.totalSupply() == token.balanceOf(bob)
    assert token.balanceOf(gov) == 0
    assert token.balanceOf(alice) == 0


def test_roles(token, gov, collateral):
    assert token.hasRole(token.ADMIN_ROLE(), gov) is True
    assert token.hasRole(token.MINTER_ROLE(), collateral) is False
    assert token.hasRole(token.BURNER_ROLE(), collateral) is False


def test_erc20(token):
    assert token.decimals() == 18
    assert token.name() == "Overlay"
    assert token.symbol() == "OVL"
