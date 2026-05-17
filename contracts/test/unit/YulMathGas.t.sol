// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {YulMath} from "../../src/utils/YulMath.sol";

contract YulMathGasTest is Test {
    function test_Sqrt_SolidityAndYulMatch_Zero() public pure {
        assertEq(YulMath.sqrtSolidity(0), YulMath.sqrtYul(0), "sqrt zero mismatch");
    }

    function test_Sqrt_SolidityAndYulMatch_One() public pure {
        assertEq(YulMath.sqrtSolidity(1), YulMath.sqrtYul(1), "sqrt one mismatch");
    }

    function test_Sqrt_SolidityAndYulMatch_PerfectSquares() public pure {
        uint256[5] memory values = [
            uint256(4),
            uint256(9),
            uint256(100),
            uint256(10_000),
            uint256(1_000_000)
        ];

        for (uint256 i = 0; i < values.length; i++) {
            assertEq(
                YulMath.sqrtSolidity(values[i]),
                YulMath.sqrtYul(values[i]),
                "sqrt perfect square mismatch"
            );
        }
    }

    function test_Sqrt_SolidityAndYulMatch_LargeNumbers() public pure {
        uint256[4] memory values = [
            uint256(1e18),
            uint256(1e30),
            uint256(1e36),
            type(uint128).max
        ];

        for (uint256 i = 0; i < values.length; i++) {
            assertEq(
                YulMath.sqrtSolidity(values[i]),
                YulMath.sqrtYul(values[i]),
                "sqrt large number mismatch"
            );
        }
    }

    function test_Sqrt_SolidityAndYulMatch_MaxUint() public pure {
        uint256 x = type(uint256).max;

        assertEq(YulMath.sqrtSolidity(x), YulMath.sqrtYul(x), "sqrt max uint mismatch");
    }

    function testFuzz_Sqrt_SolidityAndYulMatch(uint256 x) public pure {
        uint256 soliditySqrt = YulMath.sqrtSolidity(x);
        uint256 yulSqrt = YulMath.sqrtYul(x);

        assertEq(soliditySqrt, yulSqrt, "sqrt fuzz mismatch");
    }

    function testFuzz_Sqrt_ResultIsRoundedDown(uint256 x) public pure {
        uint256 result = YulMath.sqrtYul(x);

        assertLe(result, type(uint128).max, "sqrt result cannot exceed uint128 max");

        uint256 lowerBound = result * result;
        assertLe(lowerBound, x, "sqrt result squared should be <= x");

        if (result < type(uint128).max) {
            uint256 next = result + 1;
            assertGt(next * next, x, "sqrt should be rounded down");
        }
    }

    function test_Min_SolidityAndYulMatch_Equal() public pure {
        assertEq(YulMath.minSolidity(5, 5), YulMath.minYul(5, 5), "min equal mismatch");
        assertEq(YulMath.minYul(5, 5), 5, "min equal result mismatch");
    }

    function test_Min_SolidityAndYulMatch_FirstSmaller() public pure {
        assertEq(YulMath.minSolidity(3, 7), YulMath.minYul(3, 7), "min first smaller mismatch");
        assertEq(YulMath.minYul(3, 7), 3, "min first smaller result mismatch");
    }

    function test_Min_SolidityAndYulMatch_SecondSmaller() public pure {
        assertEq(YulMath.minSolidity(10, 4), YulMath.minYul(10, 4), "min second smaller mismatch");
        assertEq(YulMath.minYul(10, 4), 4, "min second smaller result mismatch");
    }

    function test_Min_SolidityAndYulMatch_WithZero() public pure {
        assertEq(YulMath.minSolidity(0, 100), YulMath.minYul(0, 100), "min zero mismatch");
        assertEq(YulMath.minYul(0, 100), 0, "min zero result mismatch");
    }

    function test_Min_SolidityAndYulMatch_LargeNumbers() public pure {
        uint256 a = type(uint256).max;
        uint256 b = type(uint256).max - 1;

        assertEq(YulMath.minSolidity(a, b), YulMath.minYul(a, b), "min large mismatch");
        assertEq(YulMath.minYul(a, b), b, "min large result mismatch");
    }

    function testFuzz_Min_SolidityAndYulMatch(uint256 a, uint256 b) public pure {
        uint256 solidityMin = YulMath.minSolidity(a, b);
        uint256 yulMin = YulMath.minYul(a, b);

        assertEq(solidityMin, yulMin, "min fuzz mismatch");
        assertEq(solidityMin, a < b ? a : b, "min result incorrect");
    }

    function test_AddThenMultiply_SolidityAndYulMatch() public pure {
        uint256[3] memory aVals = [uint256(10), uint256(100), uint256(1_000)];
        uint256[3] memory bVals = [uint256(20), uint256(50), uint256(5_000)];
        uint256[3] memory cVals = [uint256(5), uint256(2), uint256(10)];

        for (uint256 i = 0; i < 3; i++) {
            uint256 solidityResult = YulMath.addThenMultiply(aVals[i], bVals[i], cVals[i]);
            uint256 yulResult = YulMath.addThenMultiplyYul(aVals[i], bVals[i], cVals[i]);

            assertEq(solidityResult, yulResult, "addThenMultiply mismatch");
            assertEq(solidityResult, (aVals[i] + bVals[i]) * cVals[i], "manual result mismatch");
        }
    }

    function testFuzz_AddThenMultiply_SolidityAndYulMatch(uint256 a, uint256 b, uint256 c)
        public
        pure
    {
        a = bound(a, 0, 1e18);
        b = bound(b, 0, 1e18);
        c = bound(c, 0, 1e18);

        uint256 solidityResult = YulMath.addThenMultiply(a, b, c);
        uint256 yulResult = YulMath.addThenMultiplyYul(a, b, c);

        assertEq(solidityResult, yulResult, "addThenMultiply fuzz mismatch");
    }

    function test_GasComparison_Sqrt() public {
        uint256 testValue = 10_000 ether;

        uint256 gasBefore = gasleft();
        uint256 solidityResult = YulMath.sqrtSolidity(testValue);
        uint256 solidityGas = gasBefore - gasleft();

        gasBefore = gasleft();
        uint256 yulResult = YulMath.sqrtYul(testValue);
        uint256 yulGas = gasBefore - gasleft();

        assertEq(solidityResult, yulResult, "sqrt gas comparison result mismatch");

        emit log_named_uint("Solidity sqrt gas", solidityGas);
        emit log_named_uint("Yul sqrt gas", yulGas);
    }

    function test_GasComparison_Min() public {
        uint256 a = 1000 ether;
        uint256 b = 500 ether;

        uint256 gasBefore = gasleft();
        uint256 solidityResult = YulMath.minSolidity(a, b);
        uint256 solidityGas = gasBefore - gasleft();

        gasBefore = gasleft();
        uint256 yulResult = YulMath.minYul(a, b);
        uint256 yulGas = gasBefore - gasleft();

        assertEq(solidityResult, yulResult, "min gas comparison result mismatch");

        emit log_named_uint("Solidity min gas", solidityGas);
        emit log_named_uint("Yul min gas", yulGas);
    }

    function test_GasComparison_AddThenMultiply() public {
        uint256 a = 1000 ether;
        uint256 b = 500 ether;
        uint256 c = 2 ether;

        uint256 gasBefore = gasleft();
        uint256 solidityResult = YulMath.addThenMultiply(a, b, c);
        uint256 solidityGas = gasBefore - gasleft();

        gasBefore = gasleft();
        uint256 yulResult = YulMath.addThenMultiplyYul(a, b, c);
        uint256 yulGas = gasBefore - gasleft();

        assertEq(solidityResult, yulResult, "addThenMultiply gas comparison result mismatch");

        emit log_named_uint("Solidity addThenMultiply gas", solidityGas);
        emit log_named_uint("Yul addThenMultiply gas", yulGas);
    }
}
