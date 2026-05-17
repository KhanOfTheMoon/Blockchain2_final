// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    AggregatorV3Interface
} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceOracle {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable stalePeriod;

    event OracleConfigured(address indexed feed, uint256 stalePeriod);

    error ZeroAddress();
    error InvalidStalePeriod();
    error InvalidPrice();
    error InvalidRound(uint80 roundId, uint80 answeredInRound, uint256 updatedAt);
    error PriceStale(uint256 updatedAt, uint256 staleAfter);
    error InvalidDecimals(uint8 decimals);

    constructor(address feed_, uint256 stalePeriod_) {
        if (feed_ == address(0)) revert ZeroAddress();
        if (stalePeriod_ == 0) revert InvalidStalePeriod();

        feed = AggregatorV3Interface(feed_);
        stalePeriod = stalePeriod_;

        emit OracleConfigured(feed_, stalePeriod_);
    }

    function latestPrice() external view returns (uint256 normalizedPrice) {
        return _latestPrice();
    }

    function getPrice() external view returns (uint256 normalizedPrice) {
        return _latestPrice();
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return feed.latestRoundData();
    }

    function _latestPrice() internal view returns (uint256 normalizedPrice) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            feed.latestRoundData();

        if (answer <= 0) revert InvalidPrice();

        if (
            roundId == 0 || updatedAt == 0 || updatedAt > block.timestamp
                || answeredInRound < roundId
        ) {
            revert InvalidRound(roundId, answeredInRound, updatedAt);
        }

        uint256 staleAfter = updatedAt + stalePeriod;
        if (block.timestamp > staleAfter) {
            revert PriceStale(updatedAt, staleAfter);
        }

        uint8 decimals_ = feed.decimals();
        if (decimals_ > 36) revert InvalidDecimals(decimals_);

        if (decimals_ == 18) {
            normalizedPrice = uint256(answer);
        } else if (decimals_ < 18) {
            normalizedPrice = uint256(answer) * (10 ** (18 - decimals_));
        } else {
            normalizedPrice = uint256(answer) / (10 ** (decimals_ - 18));
        }
    }
}
