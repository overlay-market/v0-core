// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/FixedPoint.sol";

// import "./OverlayV1Governance.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract OverlayV1Comptroller {

  using FixedPoint for uint256;

  uint256 private constant INVERSE_E = 0x51AF86713316A9A;
  uint256 private constant ONE = 1e18;
  struct Roller {
    uint32 time;
    uint112 ying; // long pressure for impact; brrrrd for brrrrd
    uint112 yang; // short pressure for impact; anti brrrrd for brrrrd
  }

  Roller[60] public impactRollers;

  uint32 public immutable impactWindow;
  uint constant impactChord = 60;
  uint256 internal staticCap;
  uint256 public impactCycloid;
  uint256 public lmbda;

  Roller[7] public brrrrdRollers;

  uint constant brrrrdChord = 7;

  uint256 public brrrrdExpected;
  uint256 public brrrrdCycloid;

  uint32 public brrrrdFiling;
  uint112[2] public brrrrdAccumulator;

  uint32 public brrrrdWindowMicro;
  uint32 public brrrrdWindowMacro;

  constructor (
    uint256 _impactWindow
  ) {

    impactWindow = uint32(_impactWindow);

    impactRollers[0] = Roller({
      time: uint32(block.timestamp),
      ying: 0,
      yang: 0
    });

    brrrrdRollers[0] = Roller({
      time: uint32(block.timestamp),
      ying: 0,
      yang: 0
    });

  }

  function setImpactRoller(
    uint _index,
    Roller memory _roller
  ) internal {

    impactRollers[_index] = _roller;

  }

  function setBrrrrdRoller (
    uint _index,
    Roller memory _roller
  ) internal {

    brrrrdRollers[_index] = _roller;

  }

  function getImpactRoller (
    uint _index
  ) internal view returns (
  Roller memory roller_
  ) {

    roller_ = impactRollers[_index];

  }

  function getBrrrrdRoller (
    uint _index
  ) internal view returns (
  Roller memory roller_
  ) {

    roller_ = brrrrdRollers[_index];

  }

  /**
  @dev Called by internal contract function: intake
  @param _brrrr TODO
  @param _antiBrrrr TODO
  @param _brrrrdCycloid TODO
  @param _brrrrdFiling TODO
  @return brrrrdCycloid_ TODO
  @return brrrrdFiling_ TODO
  */
  function brrrr (
    uint _brrrr,
    uint _antiBrrrr,
    uint8 _brrrrdCycloid,
    uint32 _brrrrdFiling
  ) internal returns (
  uint8 brrrrdCycloid_,
  uint32 brrrrdFiling_
  ) {

    uint32 _now = uint32(block.timestamp);

    if ( _now > _brrrrdFiling ) { // time to roll in the brrrrr

      Roller memory _roller = brrrrdRollers[_brrrrdCycloid];

      uint _lastMoment = _roller.time;

      // TODO: Bug? Should assign brrrrdFiling to new value?
      _roller.time = _brrrrdFiling;
      _roller.ying += brrrrdAccumulator[0];
      _roller.yang += brrrrdAccumulator[1];

      brrrrdCycloid_ = roll(
        setBrrrrdRoller, 
        _roller, 
        brrrrdChord,
        _brrrrdCycloid,
        _lastMoment
      );

      brrrrdAccumulator[0] = uint112(_brrrr);
      brrrrdAccumulator[1] = uint112(_antiBrrrr);

      uint32 _brrrrdWindowMicro = brrrrdWindowMicro;

      brrrrdFiling_ = _brrrrdFiling + _brrrrdWindowMicro + ( 
                          ( ( _now - _brrrrdFiling ) / _brrrrdWindowMicro ) 
                          * _brrrrdWindowMicro );

    } else { // add to the brrrr accumulator

      brrrrdAccumulator[0] += uint112(_brrrr);
      brrrrdAccumulator[1] += uint112(_antiBrrrr);

      brrrrdFiling_ = _brrrrdFiling;
      brrrrdCycloid_ = _brrrrdCycloid;

    }

  }

  /**
    @dev Called by internal contract function: _oiCap
    @dev Calls internal contract function: scry
    @param _brrrrdCycloid TODO
    @returns brrrrd_ TODO
    @returns antiBrrrrd_ TODO
   */
  function getBrrrrd (
    uint8 _brrrrdCycloid
  ) public view returns (
  uint brrrrd_,
  uint antiBrrrrd_
  ) {

    // Call to internal contract
    (  ,Roller memory _rollerNow,
     Roller memory _rollerThen ) = scry(
     getBrrrrdRoller,
     brrrrdChord,
     _brrrrdCycloid,
     brrrrdWindowMacro
     );

     brrrrd_ = brrrrdAccumulator[0] + _rollerNow.ying - _rollerThen.ying;

     antiBrrrrd_ = brrrrdAccumulator[1] + _rollerNow.yang - _rollerThen.yang;

  }


  /**
  @notice Public function that takes in the open interest and applies Overlay's
  @notice monetary policy.
  @dev TODO: rename intake function or _intake function
  @dev The impact is a measure of the demand placed on the market over a
  @dev rolling window. It determines the amount of collateral to be burnt.
  @dev This is akin to slippage in an order book model.
  @dev Called by OverlayV1Market contract function: enterOI
  @dev Calls internal contract function: _intake
  @dev Calls internal contract function: roll
  @dev Calls internal contract function: brrrr
  @dev Calls Math contract function: mulUp
  @param _isLong Whether it is taking out oi on the long or short side
  @param _oi The amount of open interest attempting to be taken out
  @param _cap The current open interest cap
  @return impact_ A factor between zero and one to be applied to initial
  @return impactCycloid_  TODO
  @return brrrrdCycloid_ TODO
  @return brrrrdFiling_ TODO
   */
  function intake (
    bool _isLong,
    uint _oi,
    uint _cap,
    uint8 _impactCycloid,
    uint8 _brrrrdCycloid,
    uint32 _brrrrdFiling
  ) internal returns (
  uint impact_,
  uint8 impactCycloid_,
  uint8 brrrrdCycloid_,
  uint32 brrrrdFiling_
  ) {

    // Calls internal contract function
    (   Roller memory _rollerImpact,
     uint _lastMoment,
     uint _impact ) = _intake(
     _isLong, 
     _oi, 
     _cap,
     _impactCycloid
     );

    // Calls internal contract function
     impactCycloid_ = roll(
       setImpactRoller,
       _rollerImpact,
       impactChord,
       _impactCycloid,
       _lastMoment
     );

     // TODO: Can be consolidated in _intake.
     impact_ = _oi.mulUp(_impact);

     (   brrrrdCycloid_,
      brrrrdFiling_ ) = brrrr( 
      0, 
      impact_,
      _brrrrdCycloid,
      _brrrrdFiling
                             );

  }


  /**
    @notice Internal method to get historic impact data for impact factor.
    @dev Historic data is represented as a sum of pressure accumulating
    @dev over the impact window.
    @dev Pressure is the fraction of the open interest cap that any given
    @dev build tries to take out on one side.  It can range from zero to
    @dev infinity but will settle at a reasonable value otherwise any build
    @dev will burn all of its initial collateral and receive a worthless
    @dev position.
    @dev The sum of historic pressure is multiplied with lambda to yield the
    @dev power by which we raise the inverse of Euler's number in order to
    @dev determine the final impact.
    @dev Calls internal contract function: scry
    @dev Calls FixedPoint contract function: mulDown, divDown
    @param _isLong The side that open interest is being be taken out on
    @param _oi The amount of open interest
    @param _cap The open interest cap
    @return rollerNow_ The current roller for the impact rollers. Impact
    from this particular call is accumulated on it for writing to storage.
    @return lastMoment_ The timestamp of the previously written roller
    which to determine whether to write to the current or the next.
    @return impact_ The factor by which to take from initial collateral.
   */
  function _intake (
    bool _isLong,
    uint _oi,
    uint _cap,
    uint8 _impactCycloid
  ) internal view returns (
  Roller memory rollerNow_,
  uint lastMoment_,
  uint impact_
  ) {

    // Calls internal contract function
    (   uint _lastMoment,
     Roller memory _rollerNow,
     Roller memory _rollerThen ) = scry(
     getImpactRoller,
     impactChord,
     _impactCycloid,
     impactWindow );

     // Calls FixedPoint contract function
     uint _p = _oi.divDown(_cap);

     if (_isLong) _rollerNow.ying += uint112(_p);
     else _rollerNow.yang += uint112(_p);

     // Calls FixedPoint contract function
     uint _power = lmbda.mulDown(_isLong
       ? uint(_rollerNow.ying - _rollerThen.ying)
       : uint(_rollerNow.yang - _rollerThen.yang)
                                );

                                lastMoment_ = _lastMoment;
                                rollerNow_ = _rollerNow;
                                impact_ = _p != 0
                                  ? ONE.sub(INVERSE_E.powUp(_power))
                                  : 0;

  }


  /**
    @notice Internal function to compute cap.
    @dev Determines the cap relative to depth and dynamic or static
    @param _dynamic If printing has exceeded expectations and the
    cap is dynamic or static.
    @param _depth The depth of the market feed in OVL terms.
    @param _staticCap The static cap of the market.
    @param _brrrrd How much has been printed. Only passed if printing
    has occurred.
    @param _brrrrdExpected How much the market expects to print before
    engaging the dynamic cap. Only passed if printing has occurred.
    @dev Called by OverlayV1Market contract function: update
   */
  function _computeOiCap (
    bool _dynamic,
    uint _depth,
    uint _staticCap,
    uint _brrrrd,
    uint _brrrrdExpected
  ) internal pure returns (
  uint cap_
  ) {

    if (_dynamic) {

      uint _dynamicCap = ( 2e18 - _brrrrd.divDown(_brrrrdExpected) ).mulDown(_staticCap);
      cap_ = Math.min(_staticCap, Math.min(_dynamicCap, _depth));

    } else cap_ = Math.min(_staticCap, _depth);

  }

  function oiCap () public virtual view returns (uint cap_);

  /**
    @notice The open interest cap for the market.
    @dev Called by OverlayV1Market contract function: update
    @dev Calls internal contract function: getBrrrrd
    @param _depth TODO
    @param _brrrrdCycloid TODO
    @return cap_ The open interest cap for the market
   */
  function _oiCap (
    uint _depth,
    uint8 _brrrrdCycloid
  ) internal virtual view returns (
  uint cap_
  ) {

    // Calls internal contract function
    (   uint _brrrrd,
     uint _antiBrrrrd ) = getBrrrrd(_brrrrdCycloid);

     uint _brrrrdExpected = brrrrdExpected;

     bool _burnt;
     bool _expected;
     bool _surpassed;

     if (_brrrrd < _antiBrrrrd) _burnt = true;
     else {
       _brrrrd -= _antiBrrrrd;
       _expected = _brrrrd < _brrrrdExpected;
       _surpassed = _brrrrd > _brrrrdExpected * 2;
     }

     cap_ = _surpassed ? 0 : _burnt || _expected
       ? _computeOiCap(false, _depth, staticCap, 0, 0)
       : _computeOiCap(true, _depth, staticCap, _brrrrd, brrrrdExpected);

  }


  /**
    @notice The time weighted liquidity of the market feed in OVL terms.
    @return depth_ The amount of liquidity in the market feed in OVL terms.
   */
  function depth () public virtual view returns (uint depth_);

  /**
    @notice Performs arithmetic to turn market liquidity into OVL terms.
    @dev Derived from cnstant product formula X*Y=K and tailored 
    to Uniswap V3 selective liquidity provision.
    @param _marketLiquidity Amount of liquidity in market in ETH terms.
    @param _ovlPrice Price of OVL against ETH.
    @return depth_ Market depth in OVL terms.
   */
  function computeDepth (
    uint _marketLiquidity,
    uint _ovlPrice
  ) public virtual view returns (uint112 depth_);

  function pressure (
    bool _isLong,
    uint _oi,
    uint _cap
  ) public view virtual returns (uint pressure_);

  function _pressure (
    bool _isLong,
    uint _oi,
    uint _cap,
    uint8 _impactCycloid
  ) internal view returns (uint pressure_) {

    (  ,Roller memory _rollerNow,
     Roller memory _rollerThen ) = scry(
     getImpactRoller,
     impactChord,
     _impactCycloid,
     impactWindow );

     pressure_ = _isLong
       ? uint(_rollerNow.ying - _rollerThen.ying)
       : uint(_rollerNow.yang - _rollerThen.yang);

       pressure_ += _oi.divDown(_cap);

  }

  function impact (
    bool _isLong,
    uint _oi,
    uint _cap
  ) public view returns (uint impact_) {

    uint _p = pressure(_isLong, _oi, _cap);

    uint _power = lmbda.mulDown(_p);

    uint _impact = _p != 0
      ? ONE.sub(INVERSE_E.powUp(_power))
      : 0;

      impact_ = _oi.mulUp(_impact);

  }


  /**
    @notice The function that saves onto the respective roller array
    @dev This is multi purpose in that it can write to either the brrrrd
    @dev rollers or the impact rollers. It knows when to increment the cycloid
    @dev to point to the next roller index. It konws when it needs needs to
    @dev write to the next roller or if it can safely write to the current one.
    @dev If the current cycloid is the length of the array, then it sets to
    @dev zero.
    @dev Called by internal contract function: intake
    @param _setter Setter for either impact or brrrrd rollers
    @param _roller The current roller to be written
    @param _lastMoment Moment of last write to decide writing new or current
    @param _cycloid Current position circular buffer, points to most recent
    @return cycloid_ The next value of the cycloid
   */
  function roll (
    function ( uint, Roller memory ) internal _setter,
    Roller memory _roller,
    uint _chord,
    uint8 _cycloid,
    uint _lastMoment
  ) internal returns (
  uint8 cycloid_
  ) {

    if (_roller.time != _lastMoment) {

      _cycloid = _cycloid < _chord
        ? _cycloid + 1
        : 0;

    }

    _setter(_cycloid, _roller);

    cycloid_ = _cycloid;

  }


  /**
    @notice First part of retrieving historic roller values
    @dev Checks to see if the current roller is satisfactory and if not
    @dev searches deeper into the roller array.
    @dev Called by internal contract function: getBrrrrd
    @dev Calls internal contract function: scryRollers
    @param _getter The getter for either impact or brrrrd rollers
    @param _chord The length of roller array in question
    @param _cycloid The current impact or brrrrd cycloid
    @param _ago The target time
    @return lastMoment_ The time the most recent roller was written
    @return rollerNow_ The current roller with the time set to now
    @return rollerThen_ The roller closest and earlier to the target time
   */
  function scry (
    function (uint) internal view returns(Roller memory) _getter,
    uint _chord,
    uint _cycloid,
    uint32 _ago
  ) internal view returns (
  uint lastMoment_,
  Roller memory rollerNow_,
  Roller memory rollerThen_
  ) {

    uint32 _time = uint32(block.timestamp);

    rollerNow_ = _getter(_cycloid);

    lastMoment_ = rollerNow_.time;

    uint32 _target = _time - _ago;

    if (rollerNow_.time <= _target) {

      rollerNow_.time = _time;
      rollerThen_.ying = rollerNow_.ying;
      rollerThen_.yang = rollerNow_.yang;

      return ( lastMoment_, rollerNow_, rollerThen_ );

    } else if (_time != rollerNow_.time) rollerNow_.time = _time;

    // Calls internal contract function
    rollerThen_ = scryRollers(
      _getter, 
      _chord,
      _cycloid, 
      _target
    );

  }


  /**
    @dev Called by internal contract function: scry
    @dev Calls internal contract function: binarySearch
    @param _getter TODO
    @param _chord TODO
    @param _cycloid TODO
    @param _target TODO
    @return beforeOrAt_ TODO
   */
  function scryRollers (
    function (uint) internal view returns(Roller memory) _getter,
    uint _chord,
    uint _cycloid,
    uint32 _target
  ) internal view returns (
  Roller memory beforeOrAt_
  ) {

    // TODO: Should be made to be one index before cycloid 
    // since .time <= target was checked already in scry()
    // Also, could also decide on immediate binary search
    // by starting at oldest, or by starting in the middle
    // and directing binary search from there. However, we
    // need to ascertain the oldest to avoid infinitely 
    // recursing when a timestamp is never reached.
    beforeOrAt_ = _getter(_cycloid);

    // return early if target is at or after newest roller 
    if (beforeOrAt_.time <= _target) return beforeOrAt_;

    // now set before to the oldest roller
    _cycloid = ( _cycloid + 1 ) % _chord;

    beforeOrAt_ = _getter(_cycloid);

    if ( beforeOrAt_.time <= 1 ) beforeOrAt_ = _getter(0);

    if (_target <= beforeOrAt_.time) return beforeOrAt_;
    // Calls internal contract function
    else return binarySearch(
      _getter,
        uint16(_chord),
      uint16(_cycloid),
      uint32(_target)
    );

  }

  /**
    @notice TODO
    @dev Called by internal contract function: scryRollers
    @param _getter TODO
    @param _cycloid TODO
    @param _chord TODO
    @param _target TODO
    @return beforeOrAt_ TODO
   */
  function binarySearch(
    function (uint) internal view returns(Roller memory) _getter,
    uint16 _cycloid,
    uint16 _chord,
    uint32 _target
  ) private view returns (
  Roller memory beforeOrAt_
  ) {

    Roller memory _atOrAfter;

    uint256 l = (_cycloid + 1) % _chord; // oldest print
    uint256 r = l + _chord - 1; // newest print
    uint256 i;
    while (true) {
      i = (l + r) / 2;

      beforeOrAt_ = _getter(i % _chord);

      // we've landed on an uninitialized roller, keep searching
      if (beforeOrAt_.time <= 1) { l = i + 1; continue; }

      _atOrAfter = _getter((i + 1) % _chord);

      bool _targetAtOrAfter = beforeOrAt_.time <= _target;

      if (_targetAtOrAfter && _target <= _atOrAfter.time) break;

      if (!_targetAtOrAfter) r = i - 1;
      else l = i + 1;
    }
  }

}
