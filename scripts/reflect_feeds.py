import os
import json
import brownie
from brownie import \
    chain, \
    interface, \
    accounts

def reflect_feeds(market_mock, market_feed, depth_mock, depth_feed):

    print("market mock", market_mock)
    print("market feed", market_feed)
    print("depth mock", depth_mock)
    print("depth feed", depth_feed)

    market_start = market_feed[0][0][0][0]
    market_end = market_feed[0][-1][-1][0]

    depth_start = depth_feed[0][0][0][0]
    depth_end = depth_feed[0][-1][-1][0]

    breadth = max(depth_end, market_end ) - market_start - 3600

    timestamps = []
    depth_obs_10_min = []
    market_obs_10_min = []
    depth_obs_1_hr = []
    market_obs_1_hr = []

    for x in range(0, breadth, 60):

        print("x", x, breadth)

        time = brownie.chain.time()
        timestamps.append(time)

        if time < depth_end:
            obs = depth_mock.observe([3600, 600, 0])
            depth_obs_10_min.append(1.0001 ** (( obs[0][2] - obs[0][1] ) / 600))
            depth_obs_1_hr.append(1.0001 ** (( obs[0][2] - obs[0][0] ) / 3600))

        if time < market_end:
            obs = market_mock.observe([3600, 600, 0])
            market_obs_10_min.append(1.0001 ** (( obs[0][2] - obs[0][1] ) / 600))
            market_obs_1_hr.append(1.0001 ** (( obs[0][2] - obs[0][0] ) / 3600))
        
        brownie.chain.mine(timedelta=60)

    twaps = {
        'timestamps': timestamps,
        'market 1 hr': market_obs_1_hr,
        'market 10 min': market_obs_10_min,
        'depth 1 hr': depth_obs_1_hr,
        'depth 10 min': depth_obs_10_min
    }

    print("CWD", os.getcwd())

    with open('./feeds/feeds_reflected.json', 'w+') as f:
        json.dump(twaps, f)

def deploy_feeds():

    # TODO: fix this relative path fetch
    market_path = '../feeds/historic_observations/univ3_dai_weth'
    depth_path = '../feeds/historic_observations/univ3_axs_weth'

    market_obs, market_shims = polish_feed(market_path)

    print("market feed", len(market_obs[0]))

    depth_obs, depth_shims = polish_feed(depth_path)

    UniswapV3MockFactory = getattr(brownie, 'UniswapV3FactoryMock')
    IUniswapV3OracleMock = getattr(interface, 'IUniswapV3OracleMock')

    uniswapv3_factory = accounts[6].deploy(UniswapV3MockFactory)

    DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    AXS = "0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b"

    uniswapv3_factory.createPool(DAI, WETH)
    uniswapv3_factory.createPool(AXS, WETH)

    market_mock = IUniswapV3OracleMock(uniswapv3_factory.allPools(0))
    depth_mock = IUniswapV3OracleMock(uniswapv3_factory.allPools(1))

    for i in range(len(market_obs)):
        market_mock.loadObservations(
            market_obs[i],
            market_shims[i],
            { 'from': accounts[6] }
        )

    for i in range(len(depth_obs)):
        depth_mock.loadObservations(
            depth_obs[i],
            depth_shims[i],
            { 'from': accounts[6] }
        )

    chain.mine(timedelta=3601)

    return ( market_mock, (market_obs, market_shims), depth_mock, (depth_obs, depth_shims) )
    
def polish_feed(path):

    base = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.normpath(os.path.join(base, path+'.json'))) as f: 
        feed = json.load(f)

    with open(os.path.normpath(os.path.join(base, path+'_twaps.json'))) as f: 
        twaps = json.load(f)
    
    now = chain[-1].timestamp
    earliest = feed[-1]['shim'][0]
    diff = 0

    feed.reverse()

    obs = []  # blockTimestamp, tickCumulative, liquidityCumulative,initialized
    shims = []  # timestamp, liquidity, tick, cardinality

    feed = feed[:300]

    feed = [feed[i:i+300] for i in range(0, len(feed), 300)]

    for fd in feed:
        obs.append([])
        shims.append([])
        for f in fd:
            diff = f['shim'][0] - earliest
            f['observation'][0] = f['shim'][0] = now + diff
            obs[len(obs)-1].append(f['observation'])
            shims[len(shims)-1].append(f['shim'])

    return ( obs, shims )


def main():

    # market_mock, market_feed, depth_mock, depth_feed = deploy_feeds()

    reflect_feeds(*deploy_feeds())

    print("accounts", accounts[6])