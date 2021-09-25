
import brownie
from brownie.test import given, strategy
from hypothesis import settings


def test_unwind(ovl_collateral, token, bob):
    pass


def test_unwind_revert_insufficient_shares(ovl_collateral, bob):

    with brownie.reverts("OVLV1:!shares"):
        print("HELLO!")
        ovl_collateral.unwind(
            1,
            1e18,
            { "from": bob }
        );
