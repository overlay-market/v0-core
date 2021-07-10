import brownie
import pandas as pd 
import os 
import typing as tp

from influxdb_client import InfluxDBClient

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

def test_uniswap(gov):

    # tick = see_tick(gov)

    config = get_config()
    client = create_client(config)
    query_api = client.query_api()

    qid = "UniswapV3: WETH / DAI .3%"
    points = 30
    org = config['org']

    print(f'Fetching prices for {qid} ...')
    query = f'''
        from(bucket:"{config['source']}") |> range(start: -{points}d)
            |> filter(fn: (r) => r["id"] == "{qid}")
    '''

    df = query_api.query_data_frame(query=query, org=org)

    # Filter then separate the df into p0c and p1c dataframes
    df_filtered = df.filter(items=['_time', '_field', '_value'])

    df_tc_now = df_filtered[df_filtered['_field'] == 'tickCumulative']
    df_tc_now = df_tc_now.sort_values(by='_time', ignore_index=True)

    df_tc_then = df_filtered[df_filtered['_field'] == 'tickCumulativeMinusPeriod']
    df_tc_then = df_tc_then.sort_values(by='_time', ignore_index=True)

    tick_cum_now = [ int(x) for x in df_tc_now['_value'].to_list() ]
    tick_cum_then = [ int(x) for x in df_tc_then['_value'].to_list() ]

    observations = [ list(x) for x in zip(tick_cum_now, tick_cum_then) ]

    print(observations)

    UniswapV3OracleMock = getattr(brownie, 'UniswapV3OracleMock')

    uv3mock = gov.deploy(UniswapV3OracleMock, 
        "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        observations
    )

    uv3mock.observeAndIncrement([])
    (tick, liq) = uv3mock.observe([0,1])
    index = uv3mock.index()
    print(index, tick)

    uv3mock.observeAndIncrement([])
    (tick, liq) = uv3mock.observe([0,1])
    index = uv3mock.index()
    print(index, tick)

    uv3mock.observeAndIncrement([])
    (tick, liq) = uv3mock.observe([0,1])
    index = uv3mock.index()
    print(index, tick)

    uv3mock.observeAndIncrement([])
    (tick, liq) = uv3mock.observe([0,1])
    index = uv3mock.index()
    print(index, tick)

    uv3l = gov.deploy(
        getattr(brownie, 'UniswapV3Listener'),
        uv3mock.address
    )

    price = uv3l.listen(
        1e18,
        "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    )

    uv3lmain = gov.deploy(
        getattr(brownie, 'UniswapV3Listener'),
        "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8"
    )

    pricemain = uv3lmain.listen(
        1e18,
        "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    )

    print(price)
    print(pricemain)
