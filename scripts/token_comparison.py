from brownie import (
    accounts,
    OverlayToken,
    OverlayTokenNew,
)

dev0 = accounts.load('development0')
dev1 = accounts.load('development1')
dev2 = accounts.load('development2')

def main():

    ovl1 = dev0.deploy(OverlayToken)
    ovl2 = dev0.deploy(OverlayTokenNew)

    ovl1.mint(dev1, 8000e18, { 'from': dev0 })
    ovl1.mint(dev2, 8000e18, { 'from': dev0 })
    ovl2.mint(dev1, 8000e18, { 'from': dev0 })
    tx = ovl2.mint(dev2, 8000e18, { 'from': dev0 })
    print("mint gas used", tx.gas_used)
    tx = ovl2.mint(dev2, 8000e18, { 'from': dev0 })
    print("mint gas used", tx.gas_used)

    ovl1.grantRole(ovl1.BURNER_ROLE(), dev1, { 'from': dev0 })
    ovl2.grantRole(ovl2.BURNER_ROLE(), dev1, { 'from': dev0 })
    ovl1.grantRole(ovl1.MINTER_ROLE(), dev1, { 'from': dev0 })
    ovl2.grantRole(ovl2.MINTER_ROLE(), dev1, { 'from': dev0 })
    ovl1.grantRole(ovl1.BURNER_ROLE(), dev2, { 'from': dev0 })
    ovl2.grantRole(ovl2.BURNER_ROLE(), dev2, { 'from': dev0 })
    ovl1.grantRole(ovl1.MINTER_ROLE(), dev2, { 'from': dev0 })
    ovl2.grantRole(ovl2.MINTER_ROLE(), dev2, { 'from': dev0 })

    tx_transfer = ovl1.transfer(dev2, 1e18, { 'from': dev1 })
    tx_burn = ovl1.burn(dev2, 5e17, { 'from': dev2 })
    print("transfer gas", tx_transfer.gas_used)
    print("burn gas", tx_burn.gas_used)
    print("together", tx_transfer.gas_used + tx_burn.gas_used)
    tx_transfer = ovl1.transfer(dev2, 1e18, { 'from': dev1 })
    tx_burn = ovl1.burn(dev2, 5e17, { 'from': dev2 })
    print("transfer gas", tx_transfer.gas_used)
    print("burn gas", tx_burn.gas_used)
    print("together", tx_transfer.gas_used + tx_burn.gas_used)


    tx_transfer_burn = ovl2.transferBurn(dev2, 5e17, 5e17, { 'from': dev1 })
    print("transfer burn gas", tx_transfer_burn.gas_used)
    tx_transfer_burn = ovl2.transferBurn(dev2, 5e17, 5e17, { 'from': dev1 })
    print("transfer burn gas", tx_transfer_burn.gas_used)

