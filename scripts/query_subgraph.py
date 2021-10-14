from re import I
import requests
import json
import os
from os import environ
from pathlib import Path  # Python 3.6+ only
from brownie.convert import to_address
from dotenv import load_dotenv

subgraph = "http://localhost:8000/subgraphs/name/overlay-market/overlay-v1"

alice = "0x256F5ff57469492BC3bF5Ea7A70Daa565737dc68"
bob = "0xdA44bf38D3969931Ad844cB8813423311E68A5c1"

global ALICE
global BOB
global MOTHERSHIP
global MARKET
global OVL_COLLATERAL

load_dotenv("./subgraph.test.env")

def query(gql):

    return json.loads(requests.post(subgraph, json={'query': gql}).text)['data']

def test_alice_and_bob_exist():

    gql = """
        query {
            accounts {
                id
            }
        }
    """

    result = query(gql)

    accounts = [ to_address(x['id']) for x in result['accounts'] ]

    assert alice in accounts, "Alice is not in returned accounts"
    assert bob in accounts, "Bob is not in returned accounts"


def test_alice_and_bob_have_zero_position_one_shares():

    gql = """
        query {
            accounts {
                id
                balances {
                    id
                    account {
                        id
                        address
                    }
                    position
                    shares
                }
            }
        }
    """

    result = query(gql)

    accounts = result['accounts']

    print("result", result['accounts'])

    balances = [ x['balances'] for x in accounts if 0 < len(x['balances'])]

    shares = { 
        to_address(balance['account']['address']):balance['shares'] 
        for sublist in balances 
        for balance in sublist 
        if balance['position'] == '1' 
    }

    assert shares[alice] == 0, 'alices shares are not zero'
    assert shares[bob] == 0, 'bobs shares are not zero'

# flatten_planets = [planet 
#                    for sublist in planets 
#                    for planet in sublist 
#                    if len(planet) < 6] 

    print("balances", balances)
    print("shares", shares)
    print("shares", shares[alice])
    print("shares", shares[bob])
    # print("shares", shares[0])
    # print("shares", shares[1])

    # filtered = filter(lambda y: ( print("y", y), y['position'] == 1 ), accounts)

    # shares = list(map(lambda x: list(filter(lambda y: (print("y", y), y['position'] == 1), x['balances'])), accounts) )

    # print("shares", shares)

    # for thing in shares:
    #     print("thing", thing)

def set_env():

    env_path = Path('.') / '.subgraph.test.env'
    load_dotenv(dotenv_path=env_path)

    global MOTHERSHIP 
    global MARKET
    global OVL_COLLATERAL
    global ALICE
    global BOB
    global GOV
    global FEE_TO 

    MOTHERSHIP = to_address(environ.get("MOTHERSHIP"))
    MARKET = to_address(environ.get("MARKET"))
    OVL_COLLATERAL = to_address(environ.get("OVL_COLLATERAL"))
    ALICE = to_address(environ.get("ALICE"))
    BOB = to_address(environ.get("BOB"))
    GOV = to_address(environ.get("GOV"))
    FEE_TO = to_address(environ.get("FEE_TO"))


if __name__ == "__main__":

    set_env()

    # test_alice_and_bob_exist()

    # test_alice_and_bob_have_zero_position_one_shares()