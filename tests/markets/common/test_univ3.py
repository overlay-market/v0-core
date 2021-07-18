
from brownie import chain, interface, UniswapV3OracleMock

import brownie
import pandas as pd 
import os 
import typing as tp
import json

def get_uni_oracle (feed_owner):

    base = os.path.dirname(os.path.abspath(__file__))
    path = 'fixtures/univ3_mock_feeds_1.json'
    with open(os.path.join(base, path)) as f:
        feeds = json.load(f)

    obs =  feeds['UniswapV3: WETH / DAI .3%']['tick_cumulatives']

    uniswapv3_mock = feed_owner.deploy(
        UniswapV3OracleMock,
        "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        600
    )

    uniswapv3_mock.addObservations(obs, { 'from': feed_owner })

    return uniswapv3_mock

def see_tick(gov) -> int:
    univ3_listener = getattr(brownie, 'UniswapV3Listener')
    uv3l = gov.deploy( univ3_listener, "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8" )
    return uv3l.see_tick()

def test_uniswap(gov):

    uni_mock = get_uni_oracle(gov)

    for i in range(10):
        try:
            obs = uni_mock.observe.transact([], { 'from': gov })
        except Exception as e:
            print("e", e)
            assert True == False
        if obs.revert_msg:
            print(obs.traceback())
            print(obs.call_trace())
            assert True == False

        print(obs)
        chain.mine(timedelta=600)
