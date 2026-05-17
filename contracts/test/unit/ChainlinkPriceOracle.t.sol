// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ChainlinkPriceOracle} from "../../src/oracle/ChainlinkPriceOracle.sol";
import {MockAggregator} from "../../src/oracle/MockAggregator.sol";
import {ZeroAddress, InvalidPrice} from "../../src/utils/Errors.sol";

contract ChainlinkPriceOracleTest is Test {
    ChainlinkPriceOracle oracle;
    MockAggregator aggregator;

    uint256 constant STALE_PERIOD = 1 hours;
    uint8 constant DECIMALS_6 = 6;
    uint8 constant DECIMALS_8 = 8;
    uint8 constant DECIMALS_18 = 18;

    function setUp() public {
        vm.warp(100 days);

        aggregator = new MockAggregator(DECIMALS_8, 100_00000000);
        oracle = new ChainlinkPriceOracle(address(aggregator), STALE_PERIOD);
    }

    function test_LatestPrice_ReturnsNormalizedPriceFrom8Decimals() public {
        uint256 price = oracle.latestPrice();

        assertEq(price, 100 * 1e18, "8-decimal price should be normalized to 18 decimals");
    }

    function test_LatestPrice_With18Decimals() public {
        MockAggregator agg18 = new MockAggregator(DECIMALS_18, 50 * 1e18);
        ChainlinkPriceOracle oracle18 = new ChainlinkPriceOracle(address(agg18), STALE_PERIOD);

        uint256 price = oracle18.latestPrice();

        assertEq(price, 50 * 1e18, "18-decimal price should remain unchanged");
    }

    function test_LatestPrice_With6Decimals() public {
        MockAggregator agg6 = new MockAggregator(DECIMALS_6, 200_000000);
        ChainlinkPriceOracle oracle6 = new ChainlinkPriceOracle(address(agg6), STALE_PERIOD);

        uint256 price = oracle6.latestPrice();

        assertEq(price, 200 * 1e18, "6-decimal price should be normalized to 18 decimals");
    }

    function test_LatestPrice_RejectsStalePrice() public {
        aggregator.setUpdatedAt(block.timestamp - STALE_PERIOD - 1);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.latestRoundData();
        uint256 staleAfter = updatedAt + STALE_PERIOD;

        vm.expectRevert(abi.encodeWithSelector(
            ChainlinkPriceOracle.PriceStale.selector,
            updatedAt,
            staleAfter
        ));
        oracle.latestPrice();
    }

    function test_LatestPrice_AcceptsRecentPrice() public {
        aggregator.setUpdatedAt(block.timestamp - STALE_PERIOD + 1);

        uint256 price = oracle.latestPrice();

        assertGt(price, 0, "Should accept recent price");
    }

    function test_LatestPrice_AcceptsBoundaryStaleTime() public {
        aggregator.setUpdatedAt(block.timestamp - STALE_PERIOD);

        uint256 price = oracle.latestPrice();

        assertGt(price, 0, "Should accept price exactly at stale boundary");
    }

    function test_LatestPrice_RejectsZeroPrice() public {
        aggregator.setPrice(0);

        vm.expectRevert(InvalidPrice.selector);
        oracle.latestPrice();
    }

    function test_LatestPrice_RejectsNegativePrice() public {
        aggregator.setPrice(-1);

        vm.expectRevert(InvalidPrice.selector);
        oracle.latestPrice();
    }

    function test_Constructor_RejectsZeroAggregator() public {
        vm.expectRevert(ZeroAddress.selector);
        new ChainlinkPriceOracle(address(0), STALE_PERIOD);
    }

    function test_LatestRoundData_PassthroughFromAggregator() public {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            oracle.latestRoundData();

        assertGt(roundId, 0, "Should return roundId");
        assertEq(answer, 100_00000000, "Should return raw aggregator answer");
        assertGt(updatedAt, 0, "Should return updatedAt");
        assertGe(answeredInRound, roundId, "answeredInRound should be valid");
    }

    function test_LatestPrice_WithMultipleUpdates() public {
        aggregator.setPrice(150_00000000);
        uint256 price1 = oracle.latestPrice();

        assertEq(price1, 150 * 1e18, "Should return updated price");

        aggregator.setPrice(75_00000000);
        uint256 price2 = oracle.latestPrice();

        assertEq(price2, 75 * 1e18, "Should return newly updated price");
    }

    function test_LatestPrice_WithLargeSafeDecimalValue() public {
        MockAggregator aggLarge = new MockAggregator(DECIMALS_8, 1_000_000_000_00000000);
        ChainlinkPriceOracle oracleLarge = new ChainlinkPriceOracle(address(aggLarge), STALE_PERIOD);

        uint256 price = oracleLarge.latestPrice();

        assertEq(price, 1_000_000_000 * 1e18, "Should normalize large safe price");
    }
}
