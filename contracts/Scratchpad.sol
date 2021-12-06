// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;


contract Scratchpad {

    event log(string k, uint v);
    
    struct Tempo {
        uint32 updated;
        uint32 compounded;
        uint8 impactCycloid;
        uint8 brrrrdCycloid;
        uint32 brrrrdFiling;
    }

    Tempo public tempo;

    constructor () { 

        uint32 _now = uint32(block.timestamp);

        tempo.updated = _now;
        tempo.compounded = _now;
        tempo.brrrrdFiling = _now;

    }


    function returnVals (
        uint32 _updated,
        uint32 _compounded,
        uint8 _cycloid
    ) public returns (
        uint cap_,
        uint32 updated_,
        uint32 compounded_
    ) {

        _updated = 55;
        _compounded = 65;

        cap_ = 5;
        updated_ = _updated;
        compounded_ = _compounded;

    }

    function failure () public {

        Tempo memory _tempo = tempo;
        uint thing;

        emit log("_tempo.compounded", _tempo.compounded);
        emit log("_tempo.updated", _tempo.updated);

        (   thing, 
            _tempo.updated, 
            _tempo.compounded ) = returnVals(
                _tempo.updated,
                _tempo.compounded,
                _tempo.brrrrdCycloid
            );

        emit log("_tempo.compounded after", _tempo.compounded);
        emit log("_tempo.updated after", _tempo.updated);

        tempo = _tempo;

        emit log("tempo.compounded after", tempo.compounded);
        emit log("tempo.updated after", tempo.updated);

    }

    function one () internal pure returns (uint) {
        return 1;
    }

    function two () internal pure returns (uint) { 
        return 2;
    }

    function curry (function() internal pure returns(uint) func) internal pure returns (uint) {
        return func();
    }

    function one_and_two () public pure returns (uint, uint) {

        return (
            curry(one),
            curry(two)
        );

    }

}