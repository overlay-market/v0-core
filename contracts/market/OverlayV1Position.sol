// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "../libraries/Position.sol";
import "./OverlayV1PricePoint.sol";

abstract contract OverlayV1Position is ERC1155, OverlayV1PricePoint {
    using Position for Position.Info;

    // array of pos attributes; id is index in array
    Position.Info[] public positions;

    // mapping from position (erc1155) id to total shares issued of position
    mapping(uint256 => uint256) public totalPositionShares;

    // mapping from leverage to index in positions array of queued position; queued can still be built on while updatePeriod elapses
    mapping(uint256 => uint256) private queuedPositionLongIds;
    mapping(uint256 => uint256) private queuedPositionShortIds;

    constructor(string memory _uri) ERC1155(_uri) {

        positions.push(Position.Info({
            isLong: false,
            leverage: 0,
            pricePoint: 0,
            oiShares: 0,
            debt: 0,
            cost: 0
        }));

    }


    /// @notice Updates position queue for T+1 price settlement
    function getQueuedPositionId(
        bool isLong,
        uint256 leverage
    ) internal returns (uint256 queuedPositionId) {
        mapping(uint256 => uint256) storage queuedPositionIds = (
            isLong ? queuedPositionLongIds : queuedPositionShortIds
        );

        queuedPositionId = queuedPositionIds[leverage];
        uint pricePointCurrentIndex = pricePoints.length;

        if (positions[queuedPositionId].pricePoint < pricePointCurrentIndex) {
            // prior update window for this queued position has passed
            positions.push(Position.Info({
                isLong: isLong,
                leverage: leverage,
                pricePoint: pricePointCurrentIndex,
                oiShares: 0,
                debt: 0,
                cost: 0
            }));
            queuedPositionId = positions.length - 1;
            queuedPositionIds[leverage] = queuedPositionId;
        }

    }
}
