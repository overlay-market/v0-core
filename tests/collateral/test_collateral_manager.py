import pytest
import brownie


def test_required():
    #Check require statements: max leverage, min collateral, oi cap.

    #case A: check that collateral<min raises:
    #relevant line in Collateral manager: require(MIN_COLLAT <= _collateral, "OVLV1:collat<min");

    with brownie.reverts('only burner'):
        token.build(bob, 1 * 10 ** token.decimals(), {"from": bob})







