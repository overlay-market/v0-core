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

        IBalancerFeed.Query[] memory queries = new IBalancerFeed.Query[](3);


        // NOTE: token0 is the quote and token1 is the base

        queries[0] = IBalancerFeed.Query( IBalancerFeed.Variable.PAIR_PRICE, 600, 0 );
        queries[1] = IBalancerFeed.Query( IBalancerFeed.Variable.PAIR_PRICE, 3600, 0 );
        queries[2] = IBalancerFeed.Query( IBalancerFeed.Variable.INVARIANT, 600, 0 );

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

    function depth () public view returns (uint256 depth_) {
        
        bytes32 _id = id();

        (   address[] memory _tokens,, ) = vault.getPoolTokens(_id);

        uint256[] memory _weights = balancer.getNormalizedWeights();

        uint _w0;
        uint _w1;
        address _t0;
        address _t1;

        if (_weights[0] < _weights[1]) {

            _w0 = _weights[0];
            _t0 = _tokens[0];
            _w1 = _weights[1];
            _t1 = _tokens[1];

        } else {

            _w0 = _weights[1];
            _t0 = _tokens[1];
            _w1 = _weights[0];
            _t1 = _tokens[0];

        }

    }

}