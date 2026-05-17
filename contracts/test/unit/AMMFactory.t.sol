// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AMMFactory} from "../../src/amm/AMMFactory.sol";
import {AMMPool} from "../../src/amm/AMMPool.sol";
import {PoolAlreadyExists, ZeroAddress} from "../../src/utils/Errors.sol";

contract MockERC20FactoryTest is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract AMMFactoryTest is Test {
    AMMFactory factory;
    MockERC20FactoryTest tokenA;
    MockERC20FactoryTest tokenB;
    MockERC20FactoryTest tokenC;

    function setUp() public {
        factory = new AMMFactory();
        tokenA = new MockERC20FactoryTest("Token A", "TKA");
        tokenB = new MockERC20FactoryTest("Token B", "TKB");
        tokenC = new MockERC20FactoryTest("Token C", "TKC");
    }

    function test_CreatePool_WithCREATE() public {
        (address pool, address lpToken) =
            factory.createPool(address(tokenA), address(tokenB), "LP Token", "LP");

        assertNotEq(pool, address(0), "Pool address should not be zero");
        assertNotEq(lpToken, address(0), "LP token address should not be zero");

        AMMPool ammPool = AMMPool(pool);

        assertEq(factory.getPool(address(ammPool.token0()), address(ammPool.token1())), pool);
        assertEq(address(ammPool.lpToken()), lpToken);
    }

    function test_CreatePool_StoresTokensInSortedOrder() public {
        (address pool,) = factory.createPool(address(tokenB), address(tokenA), "LP Token", "LP");

        AMMPool ammPool = AMMPool(pool);

        assertLt(uint160(address(ammPool.token0())), uint160(address(ammPool.token1())));
        assertEq(factory.getPool(address(ammPool.token0()), address(ammPool.token1())), pool);
    }

    function test_CreatePool_RejectsZeroTokenAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        factory.createPool(address(0), address(tokenB), "LP Token", "LP");

        vm.expectRevert(ZeroAddress.selector);
        factory.createPool(address(tokenA), address(0), "LP Token", "LP");
    }

    function test_CreatePool_RejectsIdenticalTokens() public {
        vm.expectRevert(ZeroAddress.selector);
        factory.createPool(address(tokenA), address(tokenA), "LP Token", "LP");
    }

    function test_CreatePool_RejectsDuplicatePoolSameOrder() public {
        factory.createPool(address(tokenA), address(tokenB), "LP Token", "LP");

        vm.expectRevert(PoolAlreadyExists.selector);
        factory.createPool(address(tokenA), address(tokenB), "LP Token 2", "LP2");
    }

    function test_CreatePool_RejectsDuplicatePoolReverseOrder() public {
        factory.createPool(address(tokenA), address(tokenB), "LP Token", "LP");

        vm.expectRevert(PoolAlreadyExists.selector);
        factory.createPool(address(tokenB), address(tokenA), "LP Token 2", "LP2");
    }

    function test_CreatePoolDeterministic_WithCREATE2() public {
        bytes32 salt = keccak256(abi.encodePacked("test_salt"));

        (address pool, address lpToken) =
            factory.createPoolDeterministic(address(tokenA), address(tokenB), "LP Token", "LP", salt);

        assertNotEq(pool, address(0), "Pool address should not be zero");
        assertNotEq(lpToken, address(0), "LP token address should not be zero");

        AMMPool ammPool = AMMPool(pool);

        assertEq(factory.getPool(address(ammPool.token0()), address(ammPool.token1())), pool);
        assertEq(address(ammPool.lpToken()), lpToken);
    }

    function test_PredictDeterministicAddress_MatchesActualDeployment() public {
        bytes32 salt = keccak256(abi.encodePacked("prediction_test"));

        address predicted =
            factory.predictDeterministicAddress(address(tokenA), address(tokenB), "LP Token", "LP", salt);

        (address actual,) =
            factory.createPoolDeterministic(address(tokenA), address(tokenB), "LP Token", "LP", salt);

        assertEq(predicted, actual, "Predicted address should match actual deployment");
    }

    function test_PredictDeterministicAddress_SameForReversedTokens() public {
        bytes32 salt = keccak256(abi.encodePacked("reverse_prediction"));

        address predictedAB =
            factory.predictDeterministicAddress(address(tokenA), address(tokenB), "LP Token", "LP", salt);

        address predictedBA =
            factory.predictDeterministicAddress(address(tokenB), address(tokenA), "LP Token", "LP", salt);

        assertEq(predictedAB, predictedBA, "Prediction should be independent of token order");
    }

    function test_CreatePoolDeterministic_RejectsDuplicatePoolSameOrder() public {
        bytes32 salt = keccak256(abi.encodePacked("dup_test"));

        factory.createPoolDeterministic(address(tokenA), address(tokenB), "LP Token", "LP", salt);

        vm.expectRevert(PoolAlreadyExists.selector);
        factory.createPoolDeterministic(address(tokenA), address(tokenB), "LP Token 2", "LP2", salt);
    }

    function test_CreatePoolDeterministic_RejectsDuplicatePoolReverseOrder() public {
        bytes32 salt = keccak256(abi.encodePacked("dup_reverse_test"));

        factory.createPoolDeterministic(address(tokenA), address(tokenB), "LP Token", "LP", salt);

        vm.expectRevert(PoolAlreadyExists.selector);
        factory.createPoolDeterministic(address(tokenB), address(tokenA), "LP Token 2", "LP2", salt);
    }
}
