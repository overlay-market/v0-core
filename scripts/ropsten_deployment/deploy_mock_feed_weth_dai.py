from brownie import \
    accounts, \
    chain, \
    interface, \
    UniswapV3FactoryMock, \
    UniswapV3OracleMock
import json
import os

FEED_OWNER = accounts.load('tester')

DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
TOKEN0 = DAI
TOKEN1 = WETH

ONE_DAY = 86400

def main():

    base = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base, '../../feeds/univ3_dai_weth_raw_uni.json')

    with open(os.path.normpath(path)) as file:
        data = json.load(file)

    now = chain.time()

    mock_start = now - 3600

    earliest = data[0]['observation'][0]

    obs = []
    shims = []

    for d in data:
        ob = d['observation']
        shim = d['shim']
        time_diff = ob[0] - earliest
        ob[0] = shim[0] = mock_start + time_diff
        obs.append(ob)
        shims.append(shim)

    uv3_factory = FEED_OWNER.deploy(UniswapV3FactoryMock)

    uv3_factory.createPool(TOKEN0, TOKEN1)

    uv3_pool = UniswapV3OracleMock.at(uv3_factory.allPools(0))

    ob_chunks = [ obs[x:x+175] for x in range(0, len(obs), 175)]
    shim_chunks = [ shims[x:x+175] for x in range(0, len(shims), 175)]

    for i in range(len(ob_chunks)):
        success = False
        while not success:
            try:
                load_tx = uv3_pool.loadObservations(
                    ob_chunks[i],
                    shim_chunks[i],
                    { 'from': FEED_OWNER } )
                success = True
            except:
                pass
