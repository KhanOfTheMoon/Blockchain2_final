// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/governance/Treasury.sol";

contract AccessControlCaseStudyTest is Test {
    address private timelock = address(0x7E10);
    address private attacker = address(0xBAD);
    address payable private recipient = payable(address(0xBEEF));

    Treasury private treasury;

    function setUp() public {
        treasury = new Treasury(timelock);
        vm.deal(address(treasury), 1 ether);
    }

    function test_TimelockOnlyTreasuryAccess() public {
        vm.prank(attacker);
        vm.expectRevert(Treasury.NotTimelock.selector);
        treasury.withdrawETH(recipient, 1 ether);

        vm.prank(timelock);
        treasury.withdrawETH(recipient, 1 ether);

        assertEq(recipient.balance, 1 ether);
    }

    function test_DeployerHasNoTreasuryBackdoor() public {
        vm.expectRevert(Treasury.NotTimelock.selector);
        treasury.withdrawETH(recipient, 1 ether);
    }
}
