// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint8 private immutable _decimals;
    uint80 private _roundId;
    uint256 private _startedAt;
    uint256 private _updatedAt;
    uint80 private _answeredInRound;

    string private _description;
    uint256 private _version;

    event PriceUpdated(
        uint80 indexed roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    error RoundNotFound();

    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals = decimals_;
        _description = "MockAggregator";
        _version = 1;

        _roundId = 1;
        _answer = initialAnswer;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        _answeredInRound = _roundId;

        emit PriceUpdated(_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function setPrice(int256 newAnswer) external {
        _roundId += 1;
        _answer = newAnswer;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        _answeredInRound = _roundId;

        emit PriceUpdated(_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;

        emit PriceUpdated(_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function setRoundData(
        uint80 roundId_,
        int256 answer_,
        uint256 startedAt_,
        uint256 updatedAt_,
        uint80 answeredInRound_
    ) external {
        _roundId = roundId_;
        _answer = answer_;
        _startedAt = startedAt_;
        _updatedAt = updatedAt_;
        _answeredInRound = answeredInRound_;

        emit PriceUpdated(_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function setAnsweredInRound(uint80 answeredInRound_) external {
        _answeredInRound = answeredInRound_;

        emit PriceUpdated(_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
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
        if (roundId != _roundId) revert RoundNotFound();

        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }
}
