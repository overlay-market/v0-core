// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./interfaces/IMirinOracle.sol";
import "./interfaces/IOVLFactory.sol";

contract OVLMirinMarket is ERC1155("https://metadata.overlay.exchange/mirin/{id}.json") {
    // TODO: using FixedPoint for *;
    using SafeERC20 for IERC20;

    // ovl erc20 token
    address public immutable ovl;
    // OVLMirinFactory address
    address public immutable factory;
    // mirin pool and factory addresses
    address public immutable mirinFactory;
    address public immutable mirinPool;
    bool public immutable isPrice0;

    struct Position {
        bool isLong; // whether long or short
        uint256 leverage; // discrete leverage amount
        uint256 oi; // shares of total open interest on long/short side, depending on isLong value
        uint256 debt; // shares of total debt on long/short side, depending on isLong value
        uint256 collateral; // shares of total collateral owned on long/short side, depending on isLong value; NOTE: technically redudant with (debt, leverage) given oi
        uint256 pricePointStartIndex; // index in mirin oracle's pricePoints to use as start of TWAP calculation for position entry (lock) price
        uint256 pricePointEndIndex; // index in mirin oracle's pricePoints to use as end of TWAP calculation for position entry (lock) price
    }

    // leverage max allowed for a position: leverages are assumed to be discrete increments of 1
    uint256 public leverageMax;
    // period size for sliding window TWAP calc
    uint256 public periodSize;
    // window size for sliding window TWAP calc
    uint256 public windowSize;
    // open interest cap on each side long/short
    uint256 public cap;
    // open interest funding constant, charged per block
    uint256 public k;

    // total open interest long
    uint256 public oiLong;
    // total open interest short
    uint256 public oiShort;
    // total debt on long side
    uint256 public debtLong;
    // total debt on short side
    uint256 public debtShort;

    // array of pos attributes; id is index in array
    Position[] public positions;
    // mapping from leverage to index in positions array of queued position; queued can still be built on while periodSize elapses
    mapping(uint256 => uint256) private queuedPositionLongIds;
    mapping(uint256 => uint256) private queuedPositionShortIds;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "!unlocked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "!factory");
        _;
    }

    modifier enabled() {
        require(IOVLFactory(factory).isMarket(address(this)), "!enabled");
        _;
    }

    constructor(
        address _ovl,
        address _mirinFactory,
        address _mirinPool,
        bool _isPrice0,
        uint256 _periodSize,
        uint256 _windowSize,
        uint256 _leverageMax,
        uint256 _cap,
        uint256 _k
    ) {
        // immutables
        factory = msg.sender;
        ovl = _ovl;
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

    function updateQueuedPosition(bool isLong, uint256 leverage) private returns (uint256 queuedPositionId) {
        // TODO: implement this PROPERLY so users pool collateral within periodSize windows
        positions.push(Position({
            isLong: isLong,
            leverage: leverage,
            oi: 0,
            debt: 0,
            collateral: 0,
            pricePointStartIndex: 0,
            pricePointEndIndex: 0
        }));
        queuedPositionId = positions.length - 1;
    }

    function build(
        uint256 collateralAmount,
        bool isLong,
        uint256 leverage
    ) external lock enabled {
        require(leverage >= 1 && leverage <= leverageMax, "invalid leverage");
        // TODO: updateFunding();
        uint256 positionId = updateQueuedPosition(isLong, leverage);
        Position storage position = positions[positionId];

        // effects
        // position
        position.oi += collateralAmount * leverage;
        position.debt += (leverage - 1) * collateralAmount;
        position.collateral += collateralAmount;

        // totals
        if (isLong) {
            oiLong += collateralAmount * leverage;
            debtLong += (leverage - 1) * collateralAmount;
        } else {
            oiShort += collateralAmount * leverage;
            debtShort += (leverage - 1) * collateralAmount;
        }

        // interactions
        // transfer collateral into pool then mint shares of queued position
        IERC20(ovl).safeTransferFrom(msg.sender, address(this), collateralAmount);
        _mint(msg.sender, positionId, collateralAmount, "");
    }

    function unwind(uint256 positionId, uint256 collateralAmount) external lock enabled {
        // TODO: updateFunding();
    }

    // adjusts params associated with this market
    function adjust(
        uint256 _periodSize,
        uint256 _windowSize,
        uint256 _leverageMax,
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
