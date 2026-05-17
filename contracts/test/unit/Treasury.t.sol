// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/token/GovernanceToken.sol";
import {Treasury} from "../../src/governance/Treasury.sol";

contract TreasuryTest is Test {
    address private timelock = address(0x7E10);
    address private deployer = address(0xD3P10);
    address payable private recipient = payable(address(0xBEEF));

    Treasury private treasury;
    GovernanceToken private token;

    function setUp() public {
        treasury = new Treasury(timelock);
        token = new GovernanceToken();
    }

    function test_ReceiveEth() public {
        vm.deal(deployer, 1 ether);

        vm.prank(deployer);
        (bool success,) = address(treasury).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(treasury).balance, 1 ether);
    }

    function test_DeployerCannotWithdrawEthDirectly() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(deployer);
        vm.expectRevert(Treasury.NotTimelock.selector);
        treasury.withdrawETH(recipient, 1 ether);
    }

    function test_TimelockCanWithdrawEth() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(timelock);
        treasury.withdrawETH(recipient, 0.4 ether);

        assertEq(recipient.balance, 0.4 ether);
        assertEq(address(treasury).balance, 0.6 ether);
    }

    function test_TimelockCanWithdrawERC20() public {
        token.transfer(address(treasury), 100 ether);

        vm.prank(timelock);
        treasury.withdrawERC20(token, recipient, 40 ether);

        assertEq(token.balanceOf(recipient), 40 ether);
        assertEq(token.balanceOf(address(treasury)), 60 ether);
    }

    function test_WithdrawToZeroAddressReverts() public {
        vm.prank(timelock);
        vm.expectRevert(Treasury.ZeroAddress.selector);
        treasury.withdrawETH(payable(address(0)), 0);
    }
}
