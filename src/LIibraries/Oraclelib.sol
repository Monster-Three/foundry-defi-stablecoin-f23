//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Oracle
 * @author Adam
 * @notice This library is uesd to check the Chainlink Oracle for stale data.
 * If a price is stale, the function will revert, and render the DSCEnigne unusable - this is by design.
 * We want the DSCEnigne to freeze if the price is stale
 *
 * So if the Chainlink network explodes and you have a lot of money in that protocol....
 */

//库函数的作用？
library Oracle {
    error Oraclelib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatesRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert Oraclelib__StalePrice();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
