import json
import pandas as pd 
import os 
import typing as tp
from pprint import pprint

from brownie import \
    chain, \
    UniswapV3OracleMock, \
    UniswapV3Listener

def get_uni_oracle (feed_owner):

    base = os.path.dirname(os.path.abspath(__file__))
    path = '../../../historic_observations/univ3_dai_weth.json'
    path = os.path.normpath(os.path.join(base, path))
    with open(os.path.join(base, path)) as f:
        hist = json.load(f)

    obs = [ ] # blockTimestamp, tickCumulative, liquidityCumulative, initialized 
    shims = [ ] # timestamp, liquidity, tick, cardinality 

    now = chain[-1].timestamp
    earliest = hist[-1]['shim'][0]
    diff = 0

    hist.reverse()
    hist = hist[:15]

    for i in range(len(hist)):
        diff = hist[i]['shim'][0] - earliest

        hist[i]['shim'][0] = hist[i]['observation'][0] = now + diff

        obs.append(hist[i]['observation'])
        shims.append(hist[i]['shim'])

    weth = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
    dai = "0x6b175474e89094c44da98b954eedeac495271d0f"
    uv3 = feed_owner.deploy(UniswapV3OracleMock, dai, weth)

    uv3listener = feed_owner.deploy(UniswapV3Listener, uv3.address)


    uv3.loadObservations(obs, shims)
    cardinality = uv3.cardinality()
    print("cardinality", cardinality)

    beginning = shims[0][0]
    end = shims[-1][0]
    span = end - beginning

    middle = int( beginning + span / 2 )

    diffs = [ shims[1:][i][0] - shims[:-1][i][0] for i in range(len(shims)-1)]

    pprint(shims)
    pprint(obs)
    pprint(diffs)

    now += 600
    chain.mine(timestamp=now)
    uv3.observe([0, 600])

    for d in diffs:
        now += d
        chain.mine(timestamp=now)
        t,l = uv3.observe([0, 600])
        print(t,l)

def test_uniswap(gov):

    uni_mock = get_uni_oracle(gov)

    # for i in range(10):
    #     try:
    #         obs = uni_mock.observe.transact([], { 'from': gov })
    #     except Exception as e:
    #         print("e", e)
    #         assert True == False
    #     if obs.revert_msg:
    #         print(obs.traceback())
    #         print(obs.call_trace())
    #         assert True == False

    #     print(obs)
    #     chain.mine(timedelta=600)
