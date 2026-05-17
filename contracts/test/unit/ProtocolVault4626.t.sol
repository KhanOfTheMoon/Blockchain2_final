// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ProtocolVault4626} from "../../src/vault/ProtocolVault4626.sol";

contract MockVaultUnitAsset is ERC20 {
    constructor() ERC20("Mock Asset", "ASSET") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ProtocolVault4626Test is Test {
    ProtocolVault4626 internal vault;
    MockVaultUnitAsset internal asset;

    address internal user1 = address(0x1);
    address internal user2 = address(0x2);

    uint256 internal constant INITIAL_BALANCE = 100_000 ether;

    function setUp() public {
        asset = new MockVaultUnitAsset();
        vault = new ProtocolVault4626(asset, "Protocol Vault", "PV");

        asset.transfer(user1, INITIAL_BALANCE);
        asset.transfer(user2, INITIAL_BALANCE);
    }

    function test_Deposit_MintsSharesAndTransfersAssets() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets);

        vm.startPrank(user1);
        asset.approve(address(vault), assets);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualShares = vault.deposit(assets, user1);

        vm.stopPrank();

        assertEq(actualShares, expectedShares, "deposit should match previewDeposit");
        assertGt(actualShares, 0, "deposit should mint positive shares");
        assertEq(asset.balanceOf(user1), assetBalanceBefore - assets, "assets should be transferred");
        assertEq(vault.balanceOf(user1), shareBalanceBefore + actualShares, "shares should be minted");
        assertEq(vault.totalAssets(), assets, "vault totalAssets should increase");
    }

    function test_Deposit_ToDifferentReceiver() public {
        uint256 assets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), assets);

        uint256 shares = vault.deposit(assets, user2);

        vm.stopPrank();

        assertEq(vault.balanceOf(user1), 0, "sender should not receive shares");
        assertEq(vault.balanceOf(user2), shares, "receiver should receive shares");
        assertEq(asset.balanceOf(address(vault)), assets, "vault should receive assets");
    }

    function test_Mint_PullsCorrectAssetsAndMintsExactShares() public {
        uint256 sharesToMint = 100 ether;
        uint256 expectedAssets = vault.previewMint(sharesToMint);

        vm.startPrank(user1);
        asset.approve(address(vault), expectedAssets);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualAssets = vault.mint(sharesToMint, user1);

        vm.stopPrank();

        assertEq(actualAssets, expectedAssets, "mint should match previewMint");
        assertEq(asset.balanceOf(user1), assetBalanceBefore - actualAssets, "assets should be pulled");
        assertEq(vault.balanceOf(user1), shareBalanceBefore + sharesToMint, "exact shares should be minted");
    }

    function test_Mint_ToDifferentReceiver() public {
        uint256 sharesToMint = 100 ether;
        uint256 expectedAssets = vault.previewMint(sharesToMint);

        vm.startPrank(user1);
        asset.approve(address(vault), expectedAssets);

        uint256 actualAssets = vault.mint(sharesToMint, user2);

        vm.stopPrank();

        assertEq(actualAssets, expectedAssets, "mint should pull previewMint assets");
        assertEq(vault.balanceOf(user1), 0, "sender should not receive shares");
        assertEq(vault.balanceOf(user2), sharesToMint, "receiver should receive shares");
    }

    function test_Withdraw_BurnsCorrectSharesAndReturnsAssets() public {
        uint256 depositAssets = 100 ether;
        uint256 withdrawAssets = 50 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);

        uint256 expectedSharesBurned = vault.previewWithdraw(withdrawAssets);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualSharesBurned = vault.withdraw(withdrawAssets, user1, user1);

        vm.stopPrank();

        assertEq(actualSharesBurned, expectedSharesBurned, "withdraw should match previewWithdraw");
        assertEq(asset.balanceOf(user1), assetBalanceBefore + withdrawAssets, "assets should be returned");
        assertEq(vault.balanceOf(user1), shareBalanceBefore - actualSharesBurned, "shares should be burned");
    }

    function test_Withdraw_ToDifferentReceiver() public {
        uint256 depositAssets = 100 ether;
        uint256 withdrawAssets = 50 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);

        uint256 receiverBalanceBefore = asset.balanceOf(user2);

        vault.withdraw(withdrawAssets, user2, user1);

        vm.stopPrank();

        assertEq(asset.balanceOf(user2), receiverBalanceBefore + withdrawAssets, "receiver should get assets");
    }

    function test_Redeem_BurnsSharesAndReturnsPreviewAssets() public {
        uint256 depositAssets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);

        uint256 mintedShares = vault.deposit(depositAssets, user1);
        uint256 sharesToRedeem = mintedShares / 2;

        uint256 expectedAssets = vault.previewRedeem(sharesToRedeem);

        uint256 assetBalanceBefore = asset.balanceOf(user1);
        uint256 shareBalanceBefore = vault.balanceOf(user1);

        uint256 actualAssets = vault.redeem(sharesToRedeem, user1, user1);

        vm.stopPrank();

        assertEq(actualAssets, expectedAssets, "redeem should match previewRedeem");
        assertEq(asset.balanceOf(user1), assetBalanceBefore + actualAssets, "assets should be returned");
        assertEq(vault.balanceOf(user1), shareBalanceBefore - sharesToRedeem, "shares should be burned");
    }

    function test_Redeem_ToDifferentReceiver() public {
        uint256 depositAssets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);

        uint256 mintedShares = vault.deposit(depositAssets, user1);
        uint256 sharesToRedeem = mintedShares / 2;

        uint256 expectedAssets = vault.previewRedeem(sharesToRedeem);
        uint256 receiverBalanceBefore = asset.balanceOf(user2);

        uint256 actualAssets = vault.redeem(sharesToRedeem, user2, user1);

        vm.stopPrank();

        assertEq(actualAssets, expectedAssets, "redeem should return preview assets");
        assertEq(asset.balanceOf(user2), receiverBalanceBefore + actualAssets, "receiver should get assets");
    }

    function test_MaxWithdraw_RespectsOwnerShares() public {
        uint256 depositAssets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);
        vm.stopPrank();

        uint256 maxWithdraw = vault.maxWithdraw(user1);

        assertEq(maxWithdraw, depositAssets, "maxWithdraw should equal deposited assets in 1:1 state");
    }

    function test_MaxRedeem_RespectsOwnerShares() public {
        uint256 depositAssets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        uint256 mintedShares = vault.deposit(depositAssets, user1);
        vm.stopPrank();

        uint256 maxRedeem = vault.maxRedeem(user1);

        assertEq(maxRedeem, mintedShares, "maxRedeem should equal owner shares");
    }

    function test_RevertWhen_WithdrawMoreThanMax() public {
        uint256 depositAssets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, user1);

        vm.expectRevert();
        vault.withdraw(depositAssets + 1, user1, user1);

        vm.stopPrank();
    }

    function test_RevertWhen_RedeemMoreThanMax() public {
        uint256 depositAssets = 100 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), depositAssets);
        uint256 mintedShares = vault.deposit(depositAssets, user1);

        vm.expectRevert();
        vault.redeem(mintedShares + 1, user1, user1);

        vm.stopPrank();
    }

    function test_ConvertToShares_AndConvertToAssets_AreAccurateInInitialState() public view {
        assertEq(vault.convertToShares(100 ether), 100 ether, "initial conversion assets to shares");
        assertEq(vault.convertToAssets(100 ether), 100 ether, "initial conversion shares to assets");
    }

    function test_TotalAssets_EqualsActualVaultAssetBalance() public {
        uint256 assets = 50 ether;

        vm.startPrank(user1);
        asset.approve(address(vault), assets);
        vault.deposit(assets, user1);
        vm.stopPrank();

        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)), "totalAssets should match balance");
    }

    function test_PreviewFunctions_AreConsistentAfterDeposit() public {
        vm.startPrank(user1);
        asset.approve(address(vault), 100 ether);
        vault.deposit(100 ether, user1);
        vm.stopPrank();

        assertEq(vault.previewDeposit(10 ether), vault.convertToShares(10 ether), "previewDeposit mismatch");
        assertEq(vault.previewRedeem(10 ether), vault.convertToAssets(10 ether), "previewRedeem mismatch");
        assertGe(vault.previewMint(10 ether), vault.convertToAssets(10 ether), "previewMint should round up");
        assertGe(vault.previewWithdraw(10 ether), vault.convertToShares(10 ether), "previewWithdraw should round up");
    }
}
