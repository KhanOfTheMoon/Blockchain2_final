// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Small arithmetic helpers used to compare normal Solidity vs inline Yul gas costs.
library YulMath {
    /// @notice Pure Solidity reference implementation for future gas benchmarking.
    function addThenMultiply(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return (a + b) * c;
    }

    /// @notice Equivalent inline assembly version for the gas comparison report.
    /// @dev Keep this function side-by-side with the Solidity version for benchmark tests.
    function addThenMultiplyYul(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        assembly {
            result := mul(add(a, b), c)
        }
    }
}
