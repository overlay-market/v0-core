
import json
import os

import time


def main():

    cur_tick = -80000
    cum_tick = 0

    cur_liq = 4880370053085953032800977
    cum_liq = 0

    delta = 15

    start = int(time.time())

    long_liquidation_feed = {
        'description': 'Synthesized price feed for UniV3 oracle mock ' +
        'rigged to liquidate longs. Price decreases by about two ' +
        'percent per period.',
        'observations': [],
        'shims': []
    }

    short_liquidation_feed = {
        'description': 'Synthesized price feed for UniV3 oracle mock ' +
        'rigged to liquidate shorts. Price increases by about two ' +
        'percent per period.',
        'observations': [],
        'shims': []
    }

    zig_zag_feed = {
        'description': 'Synthesized price feed for UniV3 oracle mock ' +
        'rigged to zig zag half the time increasing in price by about ' +
        'two percent per period while the other half decreasing.',
        'observations': [],
        'shims': []
    }

    now = start
    for i in range(1000):  # long feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        long_liquidation_feed['observations'].append([now, cum_tick, cum_liq, True]) # noqa E501
        long_liquidation_feed['shims'].append([now, cur_liq, cur_tick, i])

        cur_tick -= 200  # decrease tick to lower price

    now = start
    for i in range(1000):  # short feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        short_liquidation_feed['observations'].append([now, cum_tick, cum_liq, True]) # noqa E501
        short_liquidation_feed['shims'].append([now, cur_liq, cur_tick, i])

        cur_tick += 200  # increase tick to raise price

    now = start
    for i in range(1000):  # zig zag feed

        now += delta

        cum_tick += cur_tick * delta
        cum_liq += (delta << 128) / cur_liq

        zig_zag_feed['observations'].append([now, cum_tick, cum_liq, True])
        zig_zag_feed['shims'].append([now, cur_liq, cur_tick, i])

        if ((i//100) % 2):  # increase if hundredth is even
            cur_tick += 200
        else:               # decrease if hundredth is odd
            cur_tick -= 200

    base = os.path.dirname(os.path.abspath(__file__))

    path = os.path.join(base, '../feeds/synthetic_long_liquidations.json')
    with open(os.path.normpath(path), 'w+') as f:
        json.dump(long_liquidation_feed, f)

    path = os.path.join(base, '../feeds/synthetic_short_liquidations.json')
    with open(os.path.normpath(path), 'w+') as f:
        json.dump(short_liquidation_feed, f)

    path = os.path.join(base, '../feeds/synthetic_zig_zag.json')
    with open(os.path.normpath(path), 'w+') as f:
        json.dump(zig_zag_feed, f)
