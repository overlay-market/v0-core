// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IBalancerFeed.sol";


contract BalancerQueries {

    IBalancerFeed immutable balancer;

    constructor (
        address _oracleAddress
    ) {

        balancer = IBalancerFeed(_oracleAddress);

    }

    function queryBalancer () public view returns (
        uint256 number
    ) { }

    function twa () public view returns (
        uint ten_,
        uint hour_,
        uint tenD_
    ) { 

        IBalancerFeed.OracleAverageQuery[] memory queries = new IBalancerFeed.OracleAverageQuery[](3);

        queries[0] = IBalancerFeed.OracleAverageQuery( IBalancerFeed.Variable.PAIR_PRICE, 600, 0 );
        queries[1] = IBalancerFeed.OracleAverageQuery( IBalancerFeed.Variable.PAIR_PRICE, 3600, 0 );
        queries[2] = IBalancerFeed.OracleAverageQuery( IBalancerFeed.Variable.INVARIANT, 600, 0 );

        uint256[] memory _results = balancer.getTimeWeightedAverage(queries);

        ten_ = _results[0];
        hour_ = _results[1];
        tenD_ = _results[2];

    }

    function weights () public view returns (uint256[] memory weights_) {

        weights_ = balancer.getNormalizedWeights();

    }

}