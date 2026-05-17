// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/token/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;

    // Checklist:
    // - initial supply minting
    // - delegation changes voting power
    // - permit signatures
    // - voting snapshots after transfers
    // - revert paths for disabled minting

    function setUp() public {
        token = new GovernanceToken();
    }

    function test_InitialSupply() public {
        assertEq(token.balanceOf(address(this)), token.INITIAL_SUPPLY());
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.name(), "Governance Token");
        assertEq(token.symbol(), "GOV");
    }

    function test_DelegationSupport() public {
        address delegatee = address(0x123);
        
        // Initially no voting power since not delegated
        assertEq(token.getVotes(address(this)), 0);
        
        // Delegate to another address
        token.delegateVotingPower(delegatee);
        assertEq(token.delegates(address(this)), delegatee);
        assertEq(token.getVotes(delegatee), token.INITIAL_SUPPLY());
        
        // Self-delegation
        token.delegateVotingPower(address(this));
        assertEq(token.delegates(address(this)), address(this));
        assertEq(token.getVotes(address(this)), token.INITIAL_SUPPLY());
    }

    function test_PermitFlow() public {
        address holder = vm.addr(0x123456789);
        address spender = address(0x888);
        uint256 amount = 100 ether;
        
        token.transfer(holder, amount);
        
        // Create permit signature
        uint256 nonce = token.nonces(holder);
        uint256 deadline = block.timestamp + 1 days;
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 typeHash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(typeHash, holder, spender, amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x123456789, digest);
        
        // Apply permit
        token.permit(holder, spender, amount, deadline, v, r, s);
        
        assertEq(token.allowance(holder, spender), amount);
    }

    function test_VotingSnapshotAfterTransfer() public {
        address recipient = address(0x456);
        uint256 transferAmount = 100_000 ether;
        
        // Delegate initial holder
        token.delegateVotingPower(address(this));
        assertEq(token.getVotes(address(this)), token.INITIAL_SUPPLY());
        
        // Transfer tokens
        token.transfer(recipient, transferAmount);
        
        // Initial holder voting power decreases
        assertEq(token.getVotes(address(this)), token.INITIAL_SUPPLY() - transferAmount);
        
        // Recipient has no voting power until delegated
        assertEq(token.getVotes(recipient), 0);
        
        // Recipient self-delegates
        vm.prank(recipient);
        token.delegateVotingPower(recipient);
        
        assertEq(token.getVotes(recipient), transferAmount);
    }

    function test_MintDisabled() public {
        vm.expectRevert(GovernanceToken.MintDisabled.selector);
        token.mint(address(this), 100 ether);
    }
}
