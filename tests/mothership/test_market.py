import brownie


def test_initialize_market(mothership, market):
    total = mothership.totalMarkets()

    tx = mothership.initializeMarket(market)

    assert mothership.marketExists(market) is True
    assert mothership.marketActive(market) is True
    assert mothership.totalMarkets() == total + 1

    assert 'UpdateMarket' in tx.events
    assert 'market' in tx.events['UpdateMarket']
    assert 'active' in tx.events['UpdateMarket']
    assert tx.events['UpdateMarket']['market'] == market
    assert tx.events['UpdateMarket']['active'] is True


def test_disable_market(mothership, market):
    # init state
    _ = mothership.initializeMarket(market)
    total = mothership.totalMarkets()

    tx = mothership.disableMarket(market)

    assert mothership.marketExists(market) is True
    assert mothership.marketActive(market) is False
    assert mothership.totalMarkets() == total

    assert 'UpdateMarket' in tx.events
    assert 'market' in tx.events['UpdateMarket']
    assert 'active' in tx.events['UpdateMarket']
    assert tx.events['UpdateMarket']['market'] == market
    assert tx.events['UpdateMarket']['active'] is False


def test_enable_market(mothership, market):
    # init state
    _ = mothership.initializeMarket(market)
    _ = mothership.disableMarket(market)
    total = mothership.totalMarkets()

    tx = mothership.enableMarket(market)

    assert mothership.marketExists(market) is True
    assert mothership.marketActive(market) is True
    assert mothership.totalMarkets() == total

    assert 'UpdateMarket' in tx.events
    assert 'market' in tx.events['UpdateMarket']
    assert 'active' in tx.events['UpdateMarket']
    assert tx.events['UpdateMarket']['market'] == market
    assert tx.events['UpdateMarket']['active'] is True


def test_enable_then_disable_market(mothership, market):
    # init state
    _ = mothership.initializeMarket(market)
    _ = mothership.disableMarket(market)
    total = mothership.totalMarkets()

    _ = mothership.enableMarket(market)

    assert mothership.marketExists(market) is True
    assert mothership.marketActive(market) is True
    assert mothership.totalMarkets() == total

    _ = mothership.disableMarket(market)

    assert mothership.marketExists(market) is True
    assert mothership.marketActive(market) is False
    assert mothership.totalMarkets() == total
