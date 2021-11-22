// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IBalancerFeed.sol";
import "../interfaces/IBalancerVault.sol";


contract BalancerQueries {

    IBalancerFeed immutable balancer;
    IBalancerVault immutable vault;

    constructor (
        address _oracleAddress,
        address _vault
    ) {

        balancer = IBalancerFeed(_oracleAddress);
        vault = IBalancerVault(_vault);

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

    function id () public view returns (bytes32 id_) {

        id_ = balancer.getPoolId();

    }

    function tokens () public view returns (address[] memory tokens_) {

        bytes32 _id = id();

        (  tokens_,, ) = vault.getPoolTokens(_id);

    }

}