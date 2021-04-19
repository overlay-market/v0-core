# overlay-protocol

V1 smart contracts for the Overlay protocol.

## Contracts

For each feed type, we'll have a factory contract that governance uses to deploy all new oracle data streams to offer as markets, that are associated with that feed type.

Any new feed type we wish to support (e.g. Mirin, Chainlink, UniswapV3), will have the same setup. A factory contract to deploy the position contract for each new stream to offer as a market and stores all the market contracts offered as a registry and the actual position contract for that market for traders to build/unwind with.
