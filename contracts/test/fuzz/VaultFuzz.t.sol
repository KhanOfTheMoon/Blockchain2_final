// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ProtocolVault4626} from "../../src/vault/ProtocolVault4626.sol";

contract MockVaultAssetFuzz is ERC20 {
    constructor() ERC20("Mock Asset", "ASSET") {
        _mint(msg.sender, 1_000_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultFuzzTest is Test {
    ProtocolVault4626 internal vault;
    MockVaultAssetFuzz internal asset;

    address internal user1 = address(0x1);
    address internal user2 = address(0x2);

    uint256 internal constant MAX_FUZZ_AMOUNT = 100_000 ether;

    function setUp() public {
        asset = new MockVaultAssetFuzz();
        vault = new ProtocolVault4626(asset, "Protocol Vault", "PV");

        asset.transfer(user1, MAX_FUZZ_AMOUNT);
        asset.transfer(user2, MAX_FUZZ_AMOUNT);
    }

    function testFuzz_DepositMatchesPreview(uint256 assets) public {
        assets = bound(assets, 1, 10_000 ether);

        uint256 expectedShares = vault.previewDeposit(assets);

        vm.startPrank(user1);
        asset.approve(address(vault), assets);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualShares = vault.deposit(assets, user1);

        vm.stopPrank();

        assertEq(actualShares, expectedShares, "deposit should match previewDeposit");
        assertEq(
            asset.balanceOf(user1), assetBalanceBefore - assets, "assets should be transferred"
        );
        assertEq(
            vault.balanceOf(user1), shareBalanceBefore + actualShares, "shares should be minted"
        );
        assertEq(vault.totalAssets(), assets, "vault should hold deposited assets");
    }

    function testFuzz_MintMatchesPreview(uint256 shares) public {
        shares = bound(shares, 1, 10_000 ether);

        uint256 expectedAssets = vault.previewMint(shares);

        vm.startPrank(user1);
        asset.approve(address(vault), expectedAssets);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualAssets = vault.mint(shares, user1);

        vm.stopPrank();

        assertEq(actualAssets, expectedAssets, "mint should match previewMint");
        assertEq(
            asset.balanceOf(user1),
            assetBalanceBefore - actualAssets,
            "assets should be transferred"
        );
        assertEq(
            vault.balanceOf(user1), shareBalanceBefore + shares, "exact shares should be minted"
        );
    }

    function testFuzz_WithdrawMatchesPreview(uint256 depositAssets, uint256 withdrawAssets) public {
        depositAssets = bound(depositAssets, 2, 10_000 ether);

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);

        uint256 maxWithdraw = vault.maxWithdraw(user1);
        withdrawAssets = bound(withdrawAssets, 1, maxWithdraw);

        uint256 expectedSharesBurned = vault.previewWithdraw(withdrawAssets);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualSharesBurned = vault.withdraw(withdrawAssets, user1, user1);

        vm.stopPrank();

        assertEq(actualSharesBurned, expectedSharesBurned, "withdraw should match previewWithdraw");
        assertEq(
            asset.balanceOf(user1), assetBalanceBefore + withdrawAssets, "assets should be returned"
        );
        assertEq(
            vault.balanceOf(user1),
            shareBalanceBefore - actualSharesBurned,
            "shares should be burned"
        );
    }

    function testFuzz_RedeemMatchesPreview(uint256 depositAssets, uint256 redeemShares) public {
        depositAssets = bound(depositAssets, 1, 10_000 ether);

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        uint256 mintedShares = vault.deposit(depositAssets, user1);

        redeemShares = bound(redeemShares, 1, mintedShares);

        uint256 expectedAssets = vault.previewRedeem(redeemShares);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualAssets = vault.redeem(redeemShares, user1, user1);

        vm.stopPrank();

        assertEq(actualAssets, expectedAssets, "redeem should match previewRedeem");
        assertEq(
            asset.balanceOf(user1), assetBalanceBefore + actualAssets, "assets should be returned"
        );
        assertEq(
            vault.balanceOf(user1), shareBalanceBefore - redeemShares, "shares should be burned"
        );
    }

    function testFuzz_CannotWithdrawMoreThanMax(uint256 depositAssets, uint256 extraAssets) public {
        depositAssets = bound(depositAssets, 1, 10_000 ether);
        extraAssets = bound(extraAssets, 1, 10_000 ether);

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);

        uint256 tooMuch = vault.maxWithdraw(user1) + extraAssets;

        vm.expectRevert();
        vault.withdraw(tooMuch, user1, user1);

        vm.stopPrank();
    }

    function testFuzz_CannotRedeemMoreThanMax(uint256 depositAssets, uint256 extraShares) public {
        depositAssets = bound(depositAssets, 1, 10_000 ether);
        extraShares = bound(extraShares, 1, 10_000 ether);

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);

        uint256 tooManyShares = vault.maxRedeem(user1) + extraShares;

        vm.expectRevert();
        vault.redeem(tooManyShares, user1, user1);

        vm.stopPrank();
    }
}
