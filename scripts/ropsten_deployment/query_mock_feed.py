
from brownie import \
    chain, \
    UniswapV3OracleMock


def main():

    uv3_pool = UniswapV3OracleMock.at(
        '0x155F4dB9c0B7Aa9a84d25228205B0aC1d1971683')

    card = uv3_pool.cardinality()

    print('card', card)

    ob = uv3_pool.observations(card-1)
    shim = uv3_pool.shims(card-1)

    print("ob", ob)
    print("shim", shim)

    now = chain.time()

    print("now", now)

    (obs, shims) = uv3_pool.observe([60], {'gas': 1250000})
    print("obs", obs)
    print("shims", shims)
