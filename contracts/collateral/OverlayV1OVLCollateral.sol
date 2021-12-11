
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Position.sol";
import "../libraries/FixedPoint.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../interfaces/IOverlayV1Market.sol";
import "../interfaces/IOverlayV1Mothership.sol";
import "../interfaces/IOverlayToken.sol";
import "../interfaces/IOverlayTokenNew.sol";
import "./MarketCodex.sol";

contract OverlayV1OVLCollateral is ERC1155 {

    event log(string k, uint v);
    event log_addr(string k, address v);

    using Position for Position.Info;
    using FixedPoint for uint256;

    bytes32 constant private GOVERNOR = keccak256("GOVERNOR");

    mapping (uint => mapping(uint => LastPosition)) internal lastPositionsLong;
    mapping (uint => mapping(uint => LastPosition)) internal lastPositionsShort;
    struct LastPosition { 
        uint32 pricePoint; 
        uint32 positionId; 
    }

    using MarketCodex for bytes32;
    bytes32[] public marketLineup;
    mapping (address => uint) public marketIndexes;

    Position.Info[] public positions;

    IOverlayV1Mothership public immutable mothership;
    IOverlayTokenNew immutable public ovl;

    uint256 public fees;
    uint256 public liquidations;

    event Build(
        address market,
        uint256 positionId,
        uint256 oi,
        uint256 debt
    );

    event Unwind(
        address market,
        uint256 positionId,
        uint256 oi,
        uint256 debt
    );

    event Liquidate(
        uint256 positionId,
        uint256 oi,
        uint256 reward,
        address rewarded
    );

    event Update(
        uint feesCollected,
        uint feesBurned,
        uint liquidationsCollected,
        uint liquidationsBurned
    );

    modifier onlyGovernor () {
        // require(mothership.hasRole(GOVERNOR, msg.sender), "OVLV1:!governor");
        _;
    }

    /**
      @notice Constructor method
      @dev  Creates a `Position.Info` struct and appends it to `positions` array to track them
      @param _uri Unique Resource Identifier of a token
      @param _mothership OverlayV1Mothership contract address
     */
    constructor (
        string memory _uri,
        address _mothership
    ) ERC1155(_uri) {

        mothership = IOverlayV1Mothership(_mothership);

        ovl = IOverlayV1Mothership(_mothership).ovl();

        marketLineup.push(bytes32(0));

        positions.push(Position.Info({
            market: 0,
            isLong: false,
            leverage: 0,
            oiShares: 0,
            pricePoint: 0,
            debt: 0,
            cost: 0
        }));

    }

    function totalSupply (
        uint _positionId
    ) public view returns (
        uint256 totalSupply_
    ) {

        if (_positionId >= positions.length) {

            totalSupply_ = 0;

        } else totalSupply_ = positions[_positionId].oiShares;
       
    }

    function balanceOf (
        address _account, 
        uint256 _positionId
    ) public view override returns (
        uint256 balance_ 
    ) {

        if ( positions.length <= _positionId ) {

            balance_ = 0;

        } else if ( positions[_positionId].oiShares == 0 ) {

            balance_ = 0;

        } else balance_ = super.balanceOf(_account, _positionId);


    }

    function addMarket (
        address _marketAddress,
        uint _fee,
        uint _maxLeverage,
        uint _marginRewardRate,
        uint _marginMaintenance
    ) external onlyGovernor {

        uint _index = marketIndexes[_marketAddress];

        require(_index == 0, "OVLV1:!!market");

        _index = marketLineup.length;

        bytes32 _market;

        _market = _market.set(
            _marketAddress,
            true,
            _fee,
            _maxLeverage,
            _marginRewardRate,
            _marginMaintenance
        );

        marketLineup.push(_market);

        marketIndexes[_marketAddress] = _index;

    }

    /**
      @notice Sets market information
      @dev Only the Governor can set market info
      @dev Adds market information to the `marketInfo` mapping
      @param _marketAddress Overlay Market contract address
      @param _marginMaintenance maintenance margin
      @param _marginRewardRate margin reward rate
      @param _maxLeverage maximum leverage amount
      */
    function setMarketInfo (
        address _marketAddress,
        uint _fee,
        uint _maxLeverage,
        uint _marginRewardRate,
        uint _marginMaintenance
    ) external onlyGovernor {

        uint _index = marketIndexes[_marketAddress];

        bytes32 _market = marketLineup[_index];

        _market = _market.setFee(_fee);
        _market = _market.setMaxLeverage(_maxLeverage);
        _market = _market.setMarginRewardRate(_marginRewardRate);
        _market = _market.setMarginMaintenance(_marginMaintenance);

        marketLineup[_index] = _market;

        // TODO: Fire and event when new market info is set - yes
    }

    function marketLineupLength () public view returns (
        uint length_
    ) {

        length_ = marketLineup.length;

    }

    function fee (
        address _market
    ) external view returns (
        uint fee_
    ) {

        fee_ = marketLineup[
            marketIndexes[_market]
        ].getFee();

    }

    function maxLeverage (
        address _market
    ) external view returns (
        uint maxLeverage_
    ) {

        maxLeverage_ = marketLineup[
            marketIndexes[_market]
        ].getMaxLeverage();

    }

    function marginRewardRate (
        address _market
    ) external view returns (
        uint marginRewardRate_
    ) {

        marginRewardRate_ = marketLineup[
            marketIndexes[_market]
        ].getMarginRewardRate();

    }

    function marginMaintenance (
        address _market
    ) external view returns (
        uint marginMaintenance_
    ) {

        marginMaintenance_ = marketLineup[
            marketIndexes[_market]
        ].getMarginMaintenance();

    }


    /// @notice Disburses fees
    function disburse () public {

        (   uint256 _marginBurnRate,
            uint256 _feeBurnRate,
            address _feeTo ) = mothership.getUpdateParams();

        uint _feeForward = fees;
        uint _feeBurn = _feeForward.mulUp(_feeBurnRate);
        _feeForward = _feeForward - _feeBurn;

        uint _liqForward = liquidations;
        uint _liqBurn = _liqForward.mulUp(_marginBurnRate);
        _liqForward -= _liqBurn;

        fees = 0;
        liquidations = 0;

        emit Update(
            _feeForward,
            _feeBurn,
            _liqForward,
            _liqBurn
        );

        ovl.burn(address(this), _feeBurn + _liqBurn);
        ovl.transfer(_feeTo, _feeForward + _liqForward);

    }

    /**
      @notice Build a position on Overlay with OVL collateral
      @dev This interacts with an Overlay Market to register oi and hold 
      positions on behalf of users.
      @dev Build event emitted
      @param _market The address of the desired market to interact with
      @param _collateral The amount of OVL to use as collateral in the position
      @param _leverage The amount of leverage to use in the position
      @param _isLong Whether to take out a position on the long or short side
      @param _minOi Minimum acceptable amount of OI after impact and fees
      @return positionId_ Id of the built position for on chain convenience
     */
    function build (
        address _market,
        uint _collateral,
        uint _leverage,
        bool _isLong,
        uint _minOi
    ) external returns (
        uint positionId_
    ) {

        return _build(
            marketIndexes[_market],
            _collateral,
            _leverage,
            _isLong,
            _minOi
        );

    }

    /**
      @notice Build a position on Overlay with OVL collateral
      @dev This interacts with an Overlay Market to register oi and hold 
      positions on behalf of users.
      @param _marketIx The index of the desired market to interact with.
      @param _collateral The amount of OVL to use as collateral in the position.
      @param _leverage The amount of leverage to use in the position
      @param _isLong Whether to take out a position on the long or short side.
      @param _minOi Minimum acceptable amount of OI after impact and fees.
      @return positionId_ Id of the built position for on chain convenience.
     */
    function _build (
        uint _marketIx,
        uint _collateral,
        uint _leverage,
        bool _isLong,
        uint _minOi
    ) internal returns (
        uint positionId_
    ) {

        bytes32 _market = marketLineup[_marketIx];

        require(_market.getActive(), "OVLV1:!market");
        require(_market.getMaxLeverage() >= _leverage, "OVLV1:lev>max");

        (   uint _oiAdjusted,
            uint _collateralAdjusted,
            uint _debtAdjusted,
            uint _exactedFee,
            uint _impact,
            uint _pricePointNext ) = IOverlayV1Market(_market.getMarket())
                .enterOI(
                    _isLong,
                    _collateral,
                    _leverage,
                    _market.getFee()
                );

        require(_oiAdjusted >= _minOi, "OVLV1:oi<min");

        fees += _exactedFee;

        positionId_ = storePosition(
            _marketIx,
            _isLong,
            _leverage,
            _oiAdjusted,
            _debtAdjusted,
            _collateralAdjusted,
            _pricePointNext
        );

        // ovl.burn(msg.sender, _impact);
        ovl.transferFromBurn(
            msg.sender, 
            address(this), 
            _collateralAdjusted + _exactedFee, 
            _impact
        );

        emit Build(_market.getMarket(), positionId_, _oiAdjusted, _debtAdjusted);

        _mint(msg.sender, positionId_, _oiAdjusted, ""); // WARNING: last b/c erc1155 callback

    }

    function storePosition (
        uint _market,
        bool _isLong,
        uint _leverage,
        uint _oi,
        uint _debt,
        uint _cost,
        uint _pricePointNext
    ) internal returns (
        uint positionId_
    ) {

        mapping(uint=>LastPosition) storage lastPositions = _isLong
            ? lastPositionsLong[_market]
            : lastPositionsShort[_market];

        LastPosition memory _lastPosition = _isLong
            ? lastPositions[_leverage]
            : lastPositions[_leverage];

        if (_lastPosition.pricePoint < _pricePointNext) {

            positions.push(Position.Info({
                market: _market,
                isLong: _isLong,
                leverage: uint8(_leverage),
                pricePoint: uint32(_pricePointNext),
                oiShares: uint112(_oi),
                debt: uint112(_debt),
                cost: uint112(_cost)
            }));

            positionId_ = positions.length - 1;

            lastPositions[_leverage] = LastPosition(
                uint32(_pricePointNext),
                uint32(positionId_)
            );

        } else {
            
            positionId_ = _lastPosition.positionId;

            Position.Info memory _position = positions[positionId_];

            _position.oiShares += uint112(_oi);
            _position.debt += uint112(_debt);
            _position.cost += uint112(_cost);

            positions[positionId_] = _position;

        }

    }


    /**
      @notice Unwinds shares of an existing position.
      @dev Interacts with a market contract to realize the PnL on a position.
      @param _positionId Id of the position to be unwound.
      @param _shares Number of shars to unwind from the position.
     */
    function unwind (
        uint256 _positionId,
        uint256 _shares
    ) external {

        require( 0 < _shares && _shares <= 
            balanceOf(msg.sender, _positionId), "OVLV1:!shares");

        Position.Info memory _position = positions[_positionId];
        bytes32 _market = marketLineup[_position.market];

        {

        (   uint _oi,
            uint _oiShares,
            uint _priceFrame ) = IOverlayV1Market(_market.getMarket())
                .exitData(
                    _position.isLong,
                    _position.pricePoint
                );

        uint _userOiShares = _shares;
        uint _totalPosShares = _position.oiShares;
        uint _userDebt = _userOiShares * _position.debt / _totalPosShares;
        uint _userCost = _userOiShares * _position.cost / _totalPosShares;
        uint _userOi = _userOiShares * _position._oi(_oi, _oiShares) / _totalPosShares;
        uint _userNotional = _userOiShares * _position._notional(
            _oi, 
            _oiShares, 
            _priceFrame
        ) / _totalPosShares;

        _position.debt -= uint112(_userDebt);
        _position.cost -= uint112(_userCost);
        _position.oiShares -= uint112(_userOiShares);

        positions[_positionId] = _position;

        emit Unwind(_market.getMarket(), _positionId, _userOi, _userDebt);

        // TODO: think through edge case of underwater position ... and fee adjustments ...
        uint _feeAmount = _userNotional.mulUp(_market.getFee());

        uint _userValueAdjusted = _userNotional - _feeAmount;
        if (_userValueAdjusted > _userDebt) _userValueAdjusted -= _userDebt;
        else _userValueAdjusted = _feeAmount = 0;

        fees += _feeAmount; // adds to fee pot, which is transferred on update

        // mint/burn excess PnL = valueAdjusted - cost
        if (_userCost < _userValueAdjusted) {

            // ovl.transfer(msg.sender, _userCost);
            // ovl.mint(msg.sender, _userValueAdjusted - _userCost);

            ovl.transferMint(
                msg.sender, 
                _userCost, 
                _userValueAdjusted - _userCost
            );

        } else {

            // ovl.transfer(msg.sender, _userValueAdjusted);
            // ovl.burn(msg.sender _userCost - _userValueAdjusted);

            ovl.transferBurn(
                msg.sender, 
                _userValueAdjusted, 
                _userCost - _userValueAdjusted
            );

        }

        IOverlayV1Market(_market.getMarket()).exitOI(
            _position.isLong,
            _userOi,
            _userOiShares,
            _userCost < _userValueAdjusted ? _userValueAdjusted - _userCost : 0,
            _userCost < _userValueAdjusted ? 0 : _userCost - _userValueAdjusted
        );

        }

        _burn(msg.sender, _positionId, _shares);

    }

    /**
    @notice Liquidates an existing position.
    @dev Interacts with an Overlay Market to exit all open interest
    associated with a liquidatable positoin.
    @param _positionId ID of the position being liquidated.
    @param _rewardsTo Address to send liquidation reward to.
    */
    function liquidate (
        uint256 _positionId,
        address _rewardsTo
    ) external {

        Position.Info memory _position = positions[_positionId];

        require(0 < _position.oiShares, "OVLV1:liquidated");

        bytes32 _market = marketLineup[_position.market];

        (   uint _oi,
            uint _oiShares,
            uint _priceFrame ) = IOverlayV1Market(_market.getMarket())
                .exitData(
                    _position.isLong,
                    _position.pricePoint
                );

        require(_position._isLiquidatable(
            _oi,
            _oiShares,
            _priceFrame,
            _market.getMarginMaintenance()
        ), "OVLV1:!liquidatable");

        uint _value = _position._value(
            _oi, 
            _oiShares, 
            _priceFrame
        );

        IOverlayV1Market(_market.getMarket()).exitOI(
            _position.isLong,
            _position._oi(_oi, _oiShares),
            _position.oiShares,
            0,
            _position.cost - _value
        );

        _position.oiShares = 0;
        _position.debt = 0;

        positions[_positionId] = _position;
    
        uint _toReward = _value.mulUp(_market.getMarginRewardRate());

        liquidations += _value - _toReward;

        emit Liquidate(
            _positionId,
            _oi,
            _toReward,
            _rewardsTo
        );

        // ovl.transfer(_rewardsTo, _toReward);
        // ovl.burn(address(this), _position.cost - _value);
        ovl.transferBurn(_rewardsTo, _toReward, _position.cost - _value);

    }


    /**
    @notice Retrieves required information from market contract 
    to calculate position value with.
    @dev Gets price frame, total open interest and 
    total open interest shares from an Overlay market.
    @param _positionId ID of position to determine value of.
    @return value_ Value of the position
    */
    function value (
        uint _positionId
    ) public view returns (
        uint256 value_
    ) {

        Position.Info memory _position = positions[_positionId];
        bytes32 _market = marketLineup[_position.market];

        (   uint _oi,
            uint _oiShares,
            uint _priceFrame ) = IOverlayV1Market(_market.getMarket())
            .positionInfo(
                _position.isLong,
                _position.pricePoint
            );

        value_ = _position._value(
            _oi,
            _oiShares,
            _priceFrame
        );

    }

}
