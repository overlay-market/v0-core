import brownie
import pandas as pd 

def test_uniswap(gov):

    univ3_listener = getattr(brownie, 'UniswapV3Listener')

    uv3l = gov.deploy(
        univ3_listener, 
        "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8"
    )

    price, gas = uv3l.listen()
     
    print("price " + str(price))
    print("gas " + str(gas))