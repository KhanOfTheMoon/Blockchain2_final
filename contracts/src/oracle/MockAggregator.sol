// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint8 private _decimals;
    uint80 private _roundId;
    uint256 private _startedAt;
    uint256 private _updatedAt;
    string private _description;
    uint256 private _version;

    event PriceUpdated(int256 answer, uint256 updatedAt);

    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals = decimals_;
        _description = "MockAggregator";
        _version = 1;
        _answer = initialAnswer;
        _roundId = 1;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
    }

    function setPrice(int256 newAnswer) external {
        _answer = newAnswer;
        _roundId += 1;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        emit PriceUpdated(newAnswer, block.timestamp);
    }

    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
        emit PriceUpdated(_answer, updatedAt_);
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function version() external view override returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 roundId)
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        require(roundId == _roundId, "MockAggregator: round not found");
        return (_roundId, _answer, _startedAt, _updatedAt, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, _answer, _startedAt, _updatedAt, _roundId);
    }
}
