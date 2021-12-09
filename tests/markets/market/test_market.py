def test_constructor():
    '''
    Tests that the OverlayV1Market contract is instantiated successfully.
    '''
    pass


def test_enter_oi():
    '''
    Tests the OverlayV1Market enterOI function.
    Checks:

    Note: Calls OverlayV1Comptroller
    '''
    pass


def test_enter_oi_error_collateral_minimum_not_met():
    '''
    Tests that the OverlayV1Market enterOI function fails when the provided collateral amount is
    less than the MIN_COLLAT plus the impact fee and the fee.
    Checks:

    Note: Calls OverlayV1Comptroller
    '''
    pass


def test_update():
    '''
    Tests the OverlayV1Market update function.

    Checks that if _now IS NOT _updated that:
      1) a price point was fetched and set
      2) the updated variable...where is it used next?
    Checks that if _now IS _updated that:
      1) a price point was NOT fetched and set
      2) updated variable?
    Note: Calls to OverlayV1PricePoint, OverlayV1OI, OverlayV1Comptroller
    - NewPricePoint Event emitted in OverlayV1PricePoint contract function: setPricePointNext
    - FundingPaid Event emitted in OverlayV1PricePoint contract function: payFunding
    Suggestion: Some event should be fired when making calls to outside contracts
    '''
    pass
