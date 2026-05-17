// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableVaultV1} from "../../src/vault/UpgradeableVaultV1.sol";
import {UpgradeableVaultV2} from "../../src/vault/UpgradeableVaultV2.sol";

contract UpgradeableVaultTest is Test {
    bytes32 private constant ERC1967_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    address private owner = address(this);
    address private timelock = address(0x7E10);
    address private attacker = address(0xBAD);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    UpgradeableVaultV1 private implementationV1;
    UpgradeableVaultV1 private proxyAsV1;
    ERC1967Proxy private proxy;

    function setUp() public {
        implementationV1 = new UpgradeableVaultV1();
        bytes memory initData = abi.encodeCall(UpgradeableVaultV1.initialize, (owner));
        proxy = new ERC1967Proxy(address(implementationV1), initData);
        proxyAsV1 = UpgradeableVaultV1(address(proxy));
    }

    function test_V1IsDeployedBehindProxy() public {
        assertEq(_implementationOf(address(proxy)), address(implementationV1));
        assertEq(proxyAsV1.owner(), owner);

        // Implementation contract should not be initialized; owner() should be zero address
        assertEq(implementationV1.owner(), address(0));
    }

    function test_V1InitialStateIsSetCorrectly() public {
        assertEq(proxyAsV1.totalDeposits(), 0);
        assertEq(proxyAsV1.depositCap(), type(uint256).max);
        assertEq(proxyAsV1.owner(), owner);
    }

    function test_DepositWithdrawAccountingThroughProxy() public {
        vm.prank(alice);
        proxyAsV1.deposit(100);

        vm.prank(bob);
        proxyAsV1.deposit(60);

        assertEq(proxyAsV1.totalDeposits(), 160);
        assertEq(proxyAsV1.balances(alice), 100);
        assertEq(proxyAsV1.balances(bob), 60);

        vm.prank(alice);
        proxyAsV1.withdraw(40);

        assertEq(proxyAsV1.totalDeposits(), 120);
        assertEq(proxyAsV1.balances(alice), 60);
        assertEq(proxyAsV1.balances(bob), 60);
    }

    function test_UnauthorizedAccountCannotUpgrade() public {
        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();
        bytes memory initData = abi.encodeCall(UpgradeableVaultV2.initializeV2, (25));

        vm.prank(attacker);
        vm.expectRevert();
        proxyAsV1.upgradeToAndCall(address(implementationV2), initData);

        assertEq(_implementationOf(address(proxy)), address(implementationV1));
    }

    function test_AuthorizedOwnerCanUpgradeToV2() public {
        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();

        proxyAsV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeCall(UpgradeableVaultV2.initializeV2, (25))
        );

        assertEq(_implementationOf(address(proxy)), address(implementationV2));
        assertEq(UpgradeableVaultV2(address(proxy)).withdrawalFeeBps(), 25);
    }

    function test_TimelockOwnerCanUpgradeToV2() public {
        UpgradeableVaultV1 timelockOwnedProxy = _deployProxyWithOwner(timelock);
        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();

        vm.prank(attacker);
        vm.expectRevert();
        timelockOwnedProxy.upgradeToAndCall(
            address(implementationV2),
            abi.encodeCall(UpgradeableVaultV2.initializeV2, (10))
        );

        vm.prank(timelock);
        timelockOwnedProxy.upgradeToAndCall(
            address(implementationV2),
            abi.encodeCall(UpgradeableVaultV2.initializeV2, (10))
        );

        UpgradeableVaultV2 proxyAsV2 = UpgradeableVaultV2(address(timelockOwnedProxy));
        assertEq(proxyAsV2.owner(), timelock);
        assertEq(proxyAsV2.withdrawalFeeBps(), 10);
    }

    function test_UpgradeToV2PreservesV1Storage() public {
        vm.prank(alice);
        proxyAsV1.deposit(100);
        vm.prank(bob);
        proxyAsV1.deposit(55);
        proxyAsV1.setDepositCap(1_000);

        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();
        proxyAsV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeCall(UpgradeableVaultV2.initializeV2, (30))
        );

        UpgradeableVaultV2 proxyAsV2 = UpgradeableVaultV2(address(proxy));
        assertEq(proxyAsV2.totalDeposits(), 155);
        assertEq(proxyAsV2.balances(alice), 100);
        assertEq(proxyAsV2.balances(bob), 55);
        assertEq(proxyAsV2.depositCap(), 1_000);
        assertEq(proxyAsV2.owner(), owner);
        assertEq(proxyAsV2.withdrawalFeeBps(), 30);
    }

    function test_V2NewFunctionalityWorksAfterUpgrade() public {
        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();
        proxyAsV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeCall(UpgradeableVaultV2.initializeV2, (5))
        );

        UpgradeableVaultV2 proxyAsV2 = UpgradeableVaultV2(address(proxy));
        proxyAsV2.setWithdrawalFeeBps(75);

        assertEq(proxyAsV2.withdrawalFeeBps(), 75);
    }

    function test_V2DoesNotResetBalancesOwnerOrConfig() public {
        vm.prank(alice);
        proxyAsV1.deposit(44);
        proxyAsV1.setDepositCap(500);

        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();
        proxyAsV1.upgradeToAndCall(address(implementationV2), "");

        UpgradeableVaultV2 proxyAsV2 = UpgradeableVaultV2(address(proxy));
        assertEq(proxyAsV2.totalDeposits(), 44);
        assertEq(proxyAsV2.balances(alice), 44);
        assertEq(proxyAsV2.depositCap(), 500);
        assertEq(proxyAsV2.owner(), owner);
        assertEq(proxyAsV2.withdrawalFeeBps(), 0);
    }

    function test_UpgradeAuthorizationCannotBeBypassedViaV2Initializer() public {
        UpgradeableVaultV2 implementationV2 = new UpgradeableVaultV2();

        vm.prank(attacker);
        vm.expectRevert();
        implementationV2.initializeV2(99);

        proxyAsV1.upgradeToAndCall(address(implementationV2), "");
        UpgradeableVaultV2 proxyAsV2 = UpgradeableVaultV2(address(proxy));

        vm.prank(attacker);
        vm.expectRevert();
        proxyAsV2.initializeV2(99);

        vm.prank(attacker);
        vm.expectRevert();
        proxyAsV2.setWithdrawalFeeBps(99);
    }

    function _deployProxyWithOwner(address initialOwner) private returns (UpgradeableVaultV1 vaultProxy) {
        UpgradeableVaultV1 implementation = new UpgradeableVaultV1();
        bytes memory initData = abi.encodeCall(UpgradeableVaultV1.initialize, (initialOwner));
        ERC1967Proxy deployedProxy = new ERC1967Proxy(address(implementation), initData);
        vaultProxy = UpgradeableVaultV1(address(deployedProxy));
    }

    function _implementationOf(address proxyAddress) private view returns (address implementation) {
        implementation = address(uint160(uint256(vm.load(proxyAddress, ERC1967_IMPLEMENTATION_SLOT))));
    }
}
