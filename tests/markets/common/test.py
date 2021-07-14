import brownie
import pandas as pd 
import os 
import typing as tp

from influxdb_client import InfluxDBClient
from brownie import chain, reverts, web3


def get_config() -> tp.Dict:
    return {
        "token": os.getenv('INFLUXDB_TOKEN'),
        "org": os.getenv('INFLUXDB_ORG'),
        "source": os.getenv('INFLUXDB_SOURCE', "ovl_univ3_james"),
        "url": os.getenv("INFLUXDB_URL"),
    }


def create_client(config: tp.Dict) -> InfluxDBClient:
    '''
    Returns an InfluxDBClient initialized with config `url` and `token` params
    returned by `get_config`

    Inputs:
        [tp.Dict]
        token   [str]:  INFLUXDB_TOKEN env representing an InfluxDB token
        url     [str]:  INFLUXDB_URL env representing an InfluxDB url

    Outputs:
        [InfluxDBClient]: InfluxDB client connection instance
    '''
    return InfluxDBClient(
            url=config['url'],
            token=config['token'],
            debug=False)

def see_tick(gov) -> int:
    univ3_listener = getattr(brownie, 'UniswapV3Listener')
    uv3l = gov.deploy( univ3_listener, "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8" )
    return uv3l.see_tick()

def test_blocktime(gov):

    time = chain[len(chain) - 1]['timestamp']
    block = len(chain)
    print(time)
    print(block)

    chain.mine(timedelta=600)

    time = chain[len(chain) - 1]['timestamp']
    block = len(chain)
    print(time)
    print(block)

    chain.mine(timedelta=600)

    time = chain[len(chain) - 1]['timestamp']
    block = len(chain)
    print(time)
    print(block)

def test_scratchpad (gov):

    Scratchpad = getattr(brownie, Scratchpad)

    test = gov.deploy(Scratchpad)





