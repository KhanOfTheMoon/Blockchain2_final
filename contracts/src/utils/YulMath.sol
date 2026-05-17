// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library YulMath {
    function sqrtSolidity(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        uint256 value = x;
        result = 1;

        if (value >> 128 > 0) {
            value >>= 128;
            result <<= 64;
        }

        if (value >> 64 > 0) {
            value >>= 64;
            result <<= 32;
        }

        if (value >> 32 > 0) {
            value >>= 32;
            result <<= 16;
        }

        if (value >> 16 > 0) {
            value >>= 16;
            result <<= 8;
        }

        if (value >> 8 > 0) {
            value >>= 8;
            result <<= 4;
        }

        if (value >> 4 > 0) {
            value >>= 4;
            result <<= 2;
        }

        if (value >> 2 > 0) {
            result <<= 1;
        }

        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;

            uint256 roundedDown = x / result;
            return result < roundedDown ? result : roundedDown;
        }
    }

    function sqrtYul(uint256 x) internal pure returns (uint256 result) {
        assembly {
            switch x
            case 0 {
                result := 0
            }
            default {
                result := 1
                let value := x

                if gt(shr(128, value), 0) {
                    value := shr(128, value)
                    result := shl(64, result)
                }

                if gt(shr(64, value), 0) {
                    value := shr(64, value)
                    result := shl(32, result)
                }

                if gt(shr(32, value), 0) {
                    value := shr(32, value)
                    result := shl(16, result)
                }

                if gt(shr(16, value), 0) {
                    value := shr(16, value)
                    result := shl(8, result)
                }

                if gt(shr(8, value), 0) {
                    value := shr(8, value)
                    result := shl(4, result)
                }

                if gt(shr(4, value), 0) {
                    value := shr(4, value)
                    result := shl(2, result)
                }

                if gt(shr(2, value), 0) {
                    result := shl(1, result)
                }

                result := shr(1, add(result, div(x, result)))
                result := shr(1, add(result, div(x, result)))
                result := shr(1, add(result, div(x, result)))
                result := shr(1, add(result, div(x, result)))
                result := shr(1, add(result, div(x, result)))
                result := shr(1, add(result, div(x, result)))
                result := shr(1, add(result, div(x, result)))

                let roundedDown := div(x, result)

                if gt(result, roundedDown) {
                    result := roundedDown
                }
            }
        }
    }

    function minSolidity(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function minYul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            result := a

            if gt(a, b) {
                result := b
            }
        }
    }

    function addThenMultiply(uint256 a, uint256 b, uint256 c)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = (a + b) * c;
        }
    }

    function addThenMultiplyYul(uint256 a, uint256 b, uint256 c)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            result := mul(add(a, b), c)
        }
    }
}
