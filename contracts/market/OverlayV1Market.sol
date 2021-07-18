// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../libraries/Position.sol";
import "../interfaces/IOverlayV1Factory.sol";
import "./OverlayV1Governance.sol";
import "./OverlayV1OI.sol";
import "./OverlayV1Position.sol";
import "../OverlayToken.sol";

contract OverlayV1Market is OverlayV1PricePoint, OverlayV1OI, OverlayV1Governance {

    mapping (address => bool) public isPositionContract;

    uint256 public fees;
    uint256 public liquidations;

    uint constant RESOLUTION = 1e4;

    event Update(
        uint newPrice,
        int256 fundingPaid
    );
    event Build(uint256 positionId, uint256 oi, uint256 debt);
    event Unwind(uint256 positionId, uint256 oi, uint256 debt);
    event Liquidate(address indexed rewarded, uint256 reward);

    uint16 public constant MIN_COLLATERAL_AMOUNT = 10**4;

    // block at which market update was last called: includes funding payment, fees, price fetching
    uint256 public updateBlockLast;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "OverlayV1: !unlocked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyApprovedPositionContract () {
        require(isPositionContract[msg.sender], "OverlayV1: !position manager");
        _;
    }

    constructor(
        string memory _uri,
        address _ovl,
        uint256 _updatePeriod,
        uint8 _leverageMax,
        uint16 _marginAdjustment,
        uint144 _oiCap,
        uint112 _fundingKNumerator,
        uint112 _fundingKDenominator
    ) OverlayV1Position(_uri) OverlayV1Governance(
        _ovl,
        _updatePeriod,
        _leverageMax,
        _marginAdjustment,
        _oiCap,
        _fundingKNumerator,
        _fundingKDenominator
    ) {

        updateBlockLast = block.number;

    }


    /// @notice Updates funding payments, cumulative fees, queued position builds, and price points
    function update() public {
        uint256 blockNumber = block.number;
        uint256 elapsed = (blockNumber - updateBlockLast) / updatePeriod;
        if (elapsed > 0) {

            // Funding payment changes at T+1
            int fundingPaid = updateFunding(fundingKNumerator, fundingKDenominator, elapsed);

            // Settle T < t < T+1 built positions at T+1 update
            // WARNING: Must come after funding to prevent funding harvesting w zero price risk
            uint256 newPrice = updatePricePoints();

            updateOi();

            // Increment update block
            updateBlockLast = blockNumber;

            emit Update(
                newPrice,
                fundingPaid
            );

        }
    }


    /// @notice Adds open interest to the market
    /// @dev invoked by an overlay position contract
    /// @returns pricePoint_ the index of the price for the position
    function increaseOI (
        bool _isLong,
        uint _oiShares
    ) external onlyApprovedPositionContract returns (
        uint pricePoint_
    ) {

        queueOi(_isLong, _oiShares, oiCap);

        return pricePoints.length;

    }

    function decreaseOI (
        bool _isLong,
        uint _oiShares
    ) external onlyApprovedPositionContract {

        uint oi_ = 

    }

}
