import math
import os
import json
import brownie
from brownie import \
    chain, \
    interface, \
    accounts

def reflect_feed(path):

    base = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.normpath(os.path.join(base, path + '_raw_uni.json'))) as f:
        feed = json.load(f)

    now = chain[-1].timestamp
    earliest = feed[-1]['observation'][0]
    latest = feed[0]['observation'][0]
    diff = 0

    feed.reverse()

    obs = []
    shims = []

    feed = feed[:300]

    # bite sized pieces to feed solidity
    feed = [feed[i:i+300] for i in range(0, len(feed), 300)]
    for fd in feed:
        obs.append([])
        shims.append([])
        for f in fd:
            diff = f['shim'][0] - earliest
            f['observation'][0] = f['shim'][0] = now + diff
            obs[len(obs)-1].append(f['observation'])
            shims[len(shims)-1].append(f['shim'])

    factory = accounts[6].deploy(getattr(brownie, 'UniswapV3FactoryMock'))

    IUniswapV3OracleMock = getattr(interface, 'IUniswapV3OracleMock')

    zeroth = "0x0000000000000000000000000000000000000000"
    factory.createPool(zeroth, zeroth)

    mock = IUniswapV3OracleMock(factory.allPools(0))

    for i in range(len(obs)): mock.loadObservations( obs[i], shims[i], { 'from': accounts[0] } )

    chain.mine(timedelta=3601)


    start = obs[0][0][0]
    end = obs[-1][-1][0]
    breadth = end - start - 3600

    # set end after adjusting the timestamps

    timestamps = []
    ten_mins = []
    one_hrs = []
    spots = []
    bids = []
    asks = []

    for x in range(0, breadth, 60):

        time = brownie.chain.time()

        print("time", time, "end", end)

        pbnj = .00573

        if time < end:
            timestamps.append(time)
            obs = mock.observe([3600, 600, 1, 0])

            ten_min = 1.0001 ** (( obs[0][3] - obs[0][1] ) / 600)
            one_hr = 1.0001 ** (( obs[0][3] - obs[0][0] ) / 3600)
            spot = 1.0001 ** (( obs[0][3] - obs[0][2] ))
            bid = min(ten_min, one_hr) * math.exp(-pbnj)
            ask = max(ten_min, one_hr) * math.exp(pbnj)

            ten_mins.append(ten_min)
            one_hrs.append(one_hr)
            spots.append(spot)
            bids.append(bid)
            asks.append(ask)

        else: break
        
        brownie.chain.mine(timedelta=60)

    reflected = {
        'timestamp': timestamps,
        'one_hr': one_hrs,
        'ten_min': ten_mins,
        'spot': spots,
        'bids': bids,
        'asks': asks
    }

    with open(os.path.normpath(os.path.join(base, path + '_reflected.json')), 'w+') as f:
        json.dump(reflected, f) 

def main():

    axs_weth_path = '../feeds/univ3_axs_weth'

    dai_weth_path = '../feeds/univ3_dai_weth'

    reflect_feed(dai_weth_path)

    reflect_feed(axs_weth_path)
