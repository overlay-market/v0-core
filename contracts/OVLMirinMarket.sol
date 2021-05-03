// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract OVLMirinMarket is ERC1155("https://metadata.overlay.exchange/mirin/{id}.json") {

    // OVLMirinFactory address
    address public immutable factory;

    // mirin pool and factory addresses
    address public immutable mirinFactory;
    address public immutable mirinPool;
    bool public immutable isPrice0;

    struct Position {
        uint8 leverage; // discrete leverage amount
        bool isLong; // whether long or short
        uint256 oi; // shares of total open interest on long/short side, depending on isLong value
        uint256 debt; // shares of total debt on long/short side, depending on isLong value
        uint256 collateral; // shares of total collateral owned on long/short side, depending on isLong value; NOTE: technically redudant with debt, leverage given oi
        uint256 pricePointStartIndex; // index in mirin oracle's pricePoints to use as start of TWAP calculation for position entry (lock) price
        uint256 pricePointEndIndex; // index in mirin oracle's pricePoints to use as end of TWAP calculation for position entry (lock) price
    }

    // leverage max allowed for a position: leverages are assumed to be discrete increments of 1
    // TODO: think about allowing for finer granularity e.g., 1.25, 1.5
    uint8 public leverageMax;
    // period size for sliding window TWAP calc
    uint256 public periodSize;
    // window size for sliding window TWAP calc
    uint256 public windowSize;
    // open interest cap on each side long/short
    uint256 public cap;
    // open interest funding constant
    uint256 public k;

    // total open interest long
    uint256 public oiLong;
    // total open interest short
    uint256 public oiShort;
    // total debt on long side
    uint256 public debtLong;
    // total debt on short side
    uint256 public debtShort;

    // counter for erc1155 pos IDs
    uint256 currentPositionId;
    // map from pos id to attributes
    mapping(uint256 => Position) positions;

    modifier onlyFactory {
        require(msg.sender == factory, "!factory");
        _;
    }

    constructor(
        address _mirinFactory,
        address _mirinPool,
        bool _isPrice0,
        uint256 _periodSize,
        uint256 _windowSize,
        uint8 _leverageMax,
        uint256 _cap,
        uint256 _k
    ) {
        // immutables
        factory = msg.sender;
        mirinFactory = _mirinFactory;
        mirinPool = _mirinPool;
        isPrice0 = _isPrice0;

        // per-market adjustable params
        periodSize = _periodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        cap = _cap;
        k = _k;
    }

    // adjusts params associated with this market
    function adjust(
        uint256 _periodSize,
        uint256 _windowSize,
        uint8 _leverageMax,
        uint256 _cap,
        uint256 _k
    ) external onlyFactory {
        periodSize = _periodSize;
        windowSize = _windowSize;
        leverageMax = _leverageMax;
        cap = _cap;
        k = _k;
    }
}
