// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MembershipNFT} from "../../src/token/MembershipNFT.sol";

contract MembershipNFTTest is Test {
    address private owner = address(this);
    address private alice = address(0xA11CE);
    address private newOwner = address(0xB0B);
    address private nonOwner = address(0xBAD);

    MembershipNFT private membership;

    function setUp() public {
        membership = new MembershipNFT();
    }

    function test_OwnerCanMint() public {
        uint256 tokenId = membership.safeMint(alice, "ipfs://membership/1");

        assertEq(tokenId, 0);
        assertEq(membership.ownerOf(tokenId), alice);
        assertEq(membership.nextTokenId(), 1);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        membership.safeMint(alice, "ipfs://membership/1");
    }

    function test_MintToZeroAddressReverts() public {
        vm.expectRevert(MembershipNFT.ZeroAddress.selector);
        membership.safeMint(address(0), "ipfs://membership/1");
    }

    function test_TokenMetadataWorks() public {
        uint256 tokenId = membership.safeMint(alice, "ipfs://membership/1");

        assertEq(membership.name(), "Membership NFT");
        assertEq(membership.symbol(), "MNFT");
        assertEq(membership.tokenURI(tokenId), "ipfs://membership/1");
    }

    function test_OwnershipTransferWorks() public {
        membership.transferOwnership(newOwner);

        assertEq(membership.owner(), newOwner);
    }

    function test_OldOwnerCannotMintAfterOwnershipTransfer() public {
        membership.transferOwnership(newOwner);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        membership.safeMint(alice, "ipfs://membership/1");
    }

    function test_NewOwnerCanMintAfterOwnershipTransfer() public {
        membership.transferOwnership(newOwner);

        vm.prank(newOwner);
        uint256 tokenId = membership.safeMint(alice, "ipfs://membership/1");

        assertEq(tokenId, 0);
        assertEq(membership.ownerOf(tokenId), alice);
    }

    function test_EmptyTokenUriReverts() public {
        vm.expectRevert(MembershipNFT.EmptyTokenUri.selector);
        membership.safeMint(alice, "");
    }

    function test_MintsUseUniqueSequentialTokenIds() public {
        uint256 firstTokenId = membership.safeMint(alice, "ipfs://membership/1");
        uint256 secondTokenId = membership.safeMint(alice, "ipfs://membership/2");

        assertEq(firstTokenId, 0);
        assertEq(secondTokenId, 1);
        assertEq(membership.tokenURI(firstTokenId), "ipfs://membership/1");
        assertEq(membership.tokenURI(secondTokenId), "ipfs://membership/2");
    }
}
