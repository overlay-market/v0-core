import os
import json
import brownie
from brownie import \
    chain, \
    interface, \
    accounts


def reflect_feed(path):

    base = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.normpath(os.path.join(base, path + '.json'))) as f:
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
    obs_10_min = []
    obs_1_hr = []

    for x in range(0, breadth, 60):

        time = brownie.chain.time()

        if time < end:
            timestamps.append(time)
            obs = mock.observe([3600, 600, 0])
            obs_10_min.append(1.0001 ** (( obs[0][2] - obs[0][1] ) / 600))
            obs_1_hr.append(1.0001 ** (( obs[0][2] - obs[0][0] ) / 3600))
        else: break

        
        brownie.chain.mine(timedelta=60)

    reflected = {
        'timestamp': timestamps,
        '1 hr': obs_1_hr,
        '10 min': obs_10_min,
    }

    with open(os.path.normpath(os.path.join(base, path + '_reflected.json')), 'w+') as f:
        json.dump(reflected, f) 

def main():

    dai_weth_path = '../feeds/historic_observations/univ3_dai_weth'

    reflect_feed(dai_weth_path)
