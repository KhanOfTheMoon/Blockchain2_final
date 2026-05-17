// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceOracle {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable stalePeriod;

    event OracleUpdated(address indexed feed, uint256 stalePeriod);

    error ZeroAddress();
    error InvalidPrice();
    error PriceStale(uint256 updatedAt, uint256 staleAfter);

    constructor(address feed_, uint256 stalePeriod_) {
        if (feed_ == address(0)) revert ZeroAddress();
        feed = AggregatorV3Interface(feed_);
        stalePeriod = stalePeriod_;
        emit OracleUpdated(feed_, stalePeriod_);
    }

    /// @notice Returns the latest normalized price scaled to 1e18.
    /// @dev Reverts when the Chainlink answer is stale, zero, or negative.
    function latestPrice() external view returns (uint256 normalizedPrice) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (block.timestamp > updatedAt + stalePeriod) {
            revert PriceStale(updatedAt, updatedAt + stalePeriod);
        }

        uint8 decimals_ = feed.decimals();
        if (decimals_ == 18) {
            normalizedPrice = uint256(answer);
        } else if (decimals_ < 18) {
            normalizedPrice = uint256(answer) * (10 ** (18 - decimals_));
        } else {
            normalizedPrice = uint256(answer) / (10 ** (decimals_ - 18));
        }
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return feed.latestRoundData();
    }
}
