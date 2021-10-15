from re import I
import requests
from pytest import approx
import json
import os
from os import environ
from pathlib import Path  # Python 3.6+ only
from brownie.convert import to_address
from dotenv import load_dotenv

subgraph = "http://localhost:8000/subgraphs/name/overlay-market/overlay-v1"

load_dotenv(".subgraph.test.env")

def ENV(key): 
    value = environ.get(key)
    if "0x" in value: return to_address(value)
    else: return value

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

    assert ENV("ALICE") in accounts, "Alice is not in returned accounts"
    assert ENV("BOB") in accounts, "Bob is not in returned accounts"


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

    position_one = { 
        to_address(balance['account']['address']):balance['shares'] 
        for sublist in [ x['balances'] for x in accounts if 0 < len(x['balances'])]
        for balance in sublist 
        if balance['position'] == '1' 
    }

    assert position_one[ENV('BOB')] == ENV('BOB_POSITION_ONE'), 'bobs position one shares are not zero'
    assert position_one[ENV('ALICE')] == ENV('ALICE_POSITION_ONE'), 'alices position one shares are not zero'

    position_two = { 
        to_address(balance['account']['address']):balance['shares'] 
        for sublist in [ x['balances'] for x in accounts if 0 < len(x['balances'])]
        for balance in sublist 
        if balance['position'] == '2' 
    }

    assert ENV('BOB') not in position_two, 'bob has no position two shares'

    assert position_two[ENV('ALICE')] == ENV('ALICE_POSITION_TWO')
    

if __name__ == "__main__":

    test_alice_and_bob_exist()

    test_alice_and_bob_have_zero_position_one_shares()

    print("end")