import requests
import json
from brownie.convert import to_address

subgraph = "http://localhost:8000/subgraphs/name/overlay-market/overlay-v1"

alice = "0x256F5ff57469492BC3bF5Ea7A70Daa565737dc68"
bob = "0xdA44bf38D3969931Ad844cB8813423311E68A5c1"

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
                    position
                    shares
                }
            }
        }
    """

    result = query(gql)

    shares = map(lambda x: filter(lambda y: y['position'] == 1, x['balances']), result['accounts]'])

    print("shares", shares)


if __name__ == "__main__":

    # test_alice_and_bob_exist()

    test_alice_and_bob_have_zero_position_one_shares()