def test_initialize_collateral(mothership, collateral, gov, token):
    total = mothership.totalCollateral()
    tx = mothership.initializeCollateral(collateral, {"from": gov})

    assert mothership.collateralExists(collateral) is True
    assert mothership.collateralActive(collateral) is True
    assert mothership.totalCollateral() == total + 1

    assert token.hasRole(token.MINTER_ROLE(), collateral) is True
    assert token.hasRole(token.BURNER_ROLE(), collateral) is True

    assert 'UpdateCollateral' in tx.events
    assert 'collateral' in tx.events['UpdateCollateral']
    assert 'active' in tx.events['UpdateCollateral']
    assert tx.events['UpdateCollateral']['collateral'] == collateral
    assert tx.events['UpdateCollateral']['active'] is True
