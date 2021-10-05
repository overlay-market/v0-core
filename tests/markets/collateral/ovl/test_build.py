import brownie
from brownie.test import given, strategy
from pytest import approx


def print_logs(tx):
    for i in range(len(tx.events['log'])):
        print(tx.events['log'][i]['k'] + ": " + str(tx.events['log'][i]['v']))


MIN_COLLATERAL = 1e14  # min amount to build
TOKEN_DECIMALS = 18
TOKEN_TOTAL_SUPPLY = 8000000
OI_CAP = 800000e18
FEE_RESOLUTION = 1e18


@given(
    collateral=strategy('uint256', min_value=1e18,
                        max_value=(OI_CAP - 1e4)/100),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'))
def test_build_success_zero_impact(
        ovl_collateral,
        token,
        mothership,
        market,
        bob,
        rewards,
        collateral,
        leverage,
        is_long
        ):

    oi = collateral * leverage
    trade_fee = oi * mothership.fee() / FEE_RESOLUTION

    # get prior state of collateral manager
    fee_bucket = ovl_collateral.fees()
    ovl_balance = token.balanceOf(ovl_collateral)

    # get prior state of market
    queued_oi = market.queuedOiLong() if is_long else market.queuedOiShort()

    # approve collateral contract to spend bob's ovl to build position
    token.approve(ovl_collateral, collateral, {"from": bob})

    # build the position
    tx = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})

    assert 'Build' in tx.events
    assert 'positionId' in tx.events['Build']
    pid = tx.events['Build']['positionId']

    # fees should be sent to fee bucket in collateral manager
    assert int(fee_bucket + trade_fee) == approx(ovl_collateral.fees())

    # check collateral sent to collateral manager
    assert int(ovl_balance + collateral) \
        == approx(token.balanceOf(ovl_collateral))

    # check position token issued with correct oi shares
    collateral_adjusted = collateral - trade_fee
    oi_adjusted = collateral_adjusted * leverage
    assert approx(ovl_collateral.balanceOf(bob, pid)) == int(oi_adjusted)

    # check position attributes for PID
    (pos_market,
     pos_islong,
     pos_lev,
     _,
     pos_oishares,
     pos_debt,
     pos_cost,
     _) = ovl_collateral.positions(pid)

    assert pos_market == market
    assert pos_islong == is_long
    assert pos_lev == leverage
    assert approx(pos_oishares) == int(oi_adjusted)
    assert approx(pos_debt) == int(oi_adjusted - collateral_adjusted)
    assert approx(pos_cost) == int(collateral_adjusted)

    # check oi has been queued on the market for respective side of trade
    if is_long:
        assert int(queued_oi + oi_adjusted) == approx(market.queuedOiLong())
    else:
        assert int(queued_oi + oi_adjusted) == approx(market.queuedOiShort())


def test_build_when_market_not_supported(
            ovl_collateral,
            token,
            mothership,
            market,
            notamarket,
            bob,
            leverage=1,  # doesn't matter
            is_long=True  # doesn't matter
        ):

    EXPECTED_ERROR_MESSAGE = 'OVLV1:!market'

    token.approve(ovl_collateral, 3e18, {"from": bob})
    # just to avoid failing min_collateral check because of fees
    trade_amt = MIN_COLLATERAL*2

    assert mothership.marketActive(market)
    assert not mothership.marketActive(notamarket)
    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.build(notamarket, trade_amt,
                             leverage, is_long, {'from': bob})


@given(
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool')
    )
def test_build_min_collateral(
            ovl_collateral,
            token,
            mothership,
            market,
            bob,
            leverage,
            is_long
        ):

    EXPECTED_ERROR_MESSAGE = 'OVLV1:collat<min'

    token.approve(ovl_collateral, 3e18, {"from": bob})

    # Here we compute exactly how much to trade in order to have just the
    # MIN_COLLATERAL after fees are taken
    # TODO: check this logic ...
    FL = mothership.fee()*leverage
    fee_offset = MIN_COLLATERAL*(FL/(FEE_RESOLUTION - FL))
    trade_amt = (MIN_COLLATERAL + fee_offset)

    # higher than min collateral passes
    tx = ovl_collateral.build(market, trade_amt + 1,
                              leverage, is_long, {'from': bob})
    assert isinstance(tx, brownie.network.transaction.TransactionReceipt)

    # lower than min collateral fails
    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.build(market, trade_amt - 2,
                             leverage, is_long, {'from': bob})


def test_build_max_leverage(
            ovl_collateral,
            token,
            market,
            bob,
            collateral=1e18,
            is_long=True
        ):

    EXPECTED_ERROR_MESSAGE = 'OVLV1:lev>max'

    token.approve(ovl_collateral, collateral, {"from": bob})
    # just to avoid failing min_collateral check because of fees
    trade_amt = MIN_COLLATERAL*2

    tx = ovl_collateral.build(
        market, trade_amt, ovl_collateral.maxLeverage(market), is_long, {'from': bob})
    assert isinstance(tx, brownie.network.transaction.TransactionReceipt)

    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.build(market, trade_amt, ovl_collateral.maxLeverage(market) + 1,
                             is_long, {'from': bob})


def test_build_cap(
            token,
            ovl_collateral,
            market,
            bob,
            leverage=1,
            is_long=True
        ):

    # NOTE error msg should be 'OVLV1:collat>cap'
    EXPECTED_ERROR_MESSAGE = 'OVLV1:>cap'

    cap = market.oiCap()
    token.approve(ovl_collateral, cap*2, {"from": bob})

    tx = ovl_collateral.build(market, cap, leverage, is_long, {'from': bob})
    assert isinstance(tx, brownie.network.transaction.TransactionReceipt)

    with brownie.reverts(EXPECTED_ERROR_MESSAGE):
        ovl_collateral.build(market, cap + 1, leverage, is_long, {"from": bob})


@given(
    collateral=strategy('uint256', min_value=1e18,
                        max_value=(OI_CAP - 1e4)/100),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool')
    )
def test_oi_queued(
            ovl_collateral,
            token,
            mothership,
            market,
            bob,
            collateral,
            leverage,
            is_long
        ):

    queued_oi = market.queuedOiLong() if is_long else market.queuedOiShort()
    assert queued_oi == 0

    token.approve(ovl_collateral, collateral, {"from": bob})
    tx = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})

    oi = collateral * leverage
    trade_fee = oi * mothership.fee() / FEE_RESOLUTION

    # queued oi less fees should be taken from collateral
    collateral_adjusted = collateral - trade_fee
    oi_adjusted = collateral_adjusted * leverage

    new_oi = market.queuedOiLong() if is_long else market.queuedOiShort()
    assert approx(new_oi) == int(oi_adjusted)


@given(
    # bc we build multiple positions w leverage take care not to hit CAP
    collateral=strategy('uint256', min_value=1e18,
                        max_value=(OI_CAP - 1e4)/300),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool')
    )
def test_entry_update_price_fetching(
            ovl_collateral,
            token,
            market,
            bob,
            collateral,
            leverage,
            is_long
        ):

    token.approve(ovl_collateral, collateral*3, {"from": bob})

    _ = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})
    idx1 = market.pricePointCurrentIndex()
    _ = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})
    idx2 = market.pricePointCurrentIndex()

    assert idx1 == idx2

    brownie.chain.mine(timedelta=market.updatePeriod()+1)

    _ = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})
    idx3 = market.pricePointCurrentIndex()

    assert idx3 > idx2


@given(
    # bc we build multiple positions w leverage take care not to hit CAP
    collateral=strategy('uint256', min_value=1e18,
                        max_value=(OI_CAP - 1e4)/300),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'),
    compoundings=strategy('uint16', min_value=1, max_value=36),
    )
def test_entry_update_compounding_oi_onesided(
            ovl_collateral,
            token,
            market,
            mothership,
            bob,
            collateral,
            leverage,
            is_long,
            compoundings
        ):

    token.approve(ovl_collateral, collateral*2, {"from": bob})
    _ = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})

    _ = ovl_collateral.build(
        market, collateral, leverage, is_long, {"from": bob})
    oi2 = market.queuedOiLong() if is_long else market.queuedOiShort()

    oi = collateral * leverage
    trade_fee = oi * mothership.fee() / FEE_RESOLUTION

    collateral_adjusted = collateral - trade_fee
    oi_adjusted = collateral_adjusted * leverage
    assert approx(oi2) == int(2*oi_adjusted)

    brownie.chain.mine(timedelta=(compoundings+1)*market.compoundingPeriod()+1)
    _ = market.update({"from": bob})

    oi_after_funding = market.oiLong() if is_long else market.oiShort()

    k = market.k() / 1e18
    funding_factor = (1 - 2*k)**(compoundings)
    expected_oi = oi2 * funding_factor

    assert int(expected_oi) == approx(oi_after_funding)


@given(
    # bc we build multiple positions w leverage take care not to hit CAP
    collateral=strategy('uint256', min_value=1e18,
                        max_value=(OI_CAP - 1e4)/300),
    leverage=strategy('uint8', min_value=1, max_value=100),
    is_long=strategy('bool'),
    compoundings=strategy('uint16', min_value=1, max_value=36),
    )
def test_entry_update_compounding_oi_imbalance(
            ovl_collateral,
            token,
            market,
            mothership,
            alice,
            bob,
            collateral,
            leverage,
            is_long,
            compoundings
        ):

    # transfer alice some tokens first given the conftest
    token.transfer(alice, collateral, {"from": bob})

    token.approve(ovl_collateral, collateral, {"from": alice})
    token.approve(ovl_collateral, 2*collateral, {"from": bob})

    _ = ovl_collateral.build(
        market, collateral, leverage, not is_long, {"from": alice})
    _ = ovl_collateral.build(
        market, 2*collateral, leverage, is_long, {"from": bob})

    queued_oi_long = market.queuedOiLong()
    queued_oi_short = market.queuedOiShort()

    collateral_adjusted = collateral - collateral * \
        leverage*mothership.fee()/FEE_RESOLUTION
    oi_adjusted = collateral_adjusted*leverage

    if is_long:
        assert approx(queued_oi_long) == int(2*oi_adjusted)
        assert approx(queued_oi_short) == int(oi_adjusted)
    else:
        assert approx(queued_oi_long) == int(oi_adjusted)
        assert approx(queued_oi_short) == int(2*oi_adjusted)

    queued_oi_imbalance = queued_oi_long - queued_oi_short

    brownie.chain.mine(timedelta=(compoundings+1)*market.compoundingPeriod()+1)
    _ = market.update({"from": bob})

    oi_long_after_funding = market.oiLong()
    oi_short_after_funding = market.oiShort()
    oi_imbalance_after_funding = oi_long_after_funding - oi_short_after_funding

    k = market.k() / 1e18
    funding_factor = (1 - 2*k)**(compoundings)
    expected_oi_imbalance = queued_oi_imbalance * funding_factor

    assert int(expected_oi_imbalance) == approx(oi_imbalance_after_funding)
    assert int(queued_oi_long + queued_oi_short) == approx(
        oi_long_after_funding + oi_short_after_funding)
