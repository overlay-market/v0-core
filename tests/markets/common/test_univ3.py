import json
# import pandas as pd 
import os 
import typing as tp
from pprint import pprint

from brownie import \
    chain, \
    UniswapV3OracleMock, \
    UniswapV3Listener

# def test_uniswap(gov):

#     base = os.path.dirname(os.path.abspath(__file__))
#     path = '../../../feeds/historic_observations/univ3_dai_weth.json'
#     path = os.path.normpath(os.path.join(base, path))
#     with open(os.path.join(base, path)) as f:
#         feed = json.load(f)

#     now = chain[-1].timestamp
#     earliest = feed[-1]['shim'][0]
#     diff = 0

#     feed = feed[:1000]
#     feed.reverse()

#     payloads = [ feed[i:i+200] for i in range(0,len(feed),200) ]

#     obs = [ ] # blockTimestamp, tickCumulative, liquidityCumulative, initialized 
#     shims = [ ] # timestamp, liquidity, tick, cardinality 

#     for p in payloads:
#         obs.append([])
#         shims.append([])
#         for f in p:
#             diff = f['shim'][0] - earliest
#             f['shim'][0] = f['observation'][0] = now + diff
#             obs[len(obs)-1].append(f['observation'])
#             shims[len(shims)-1].append(f['shim'])

#     weth = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
#     dai = "0x6b175474e89094c44da98b954eedeac495271d0f"
#     uv3 = gov.deploy(UniswapV3OracleMock, dai, weth)

#     for i in range(len(obs)):
#         uv3.loadObservations(obs[i], shims[i])

#     uv3l = gov.deploy(UniswapV3Listener, uv3.address)

#     # beginning to end
#     for t in range(shims[0][0][0] + 601, shims[-1][-1][0], 600):
#         chain.mine(timestamp=t)
#         tk,l = uv3.observe([0,600])
#         p = uv3l.listen(1e18, weth)
#         print(t,p,tk,l)


def test_uni_liq(uni_test):

    x, y, z = uni_test.testUniLiq(600)

    print("x", x)
    print("y", y)
    print("z", z)