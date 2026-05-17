// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdInvariant, Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ProtocolVault4626} from "../../src/vault/ProtocolVault4626.sol";

contract MockVaultAssetInvariant is ERC20 {
    constructor() ERC20("Mock Asset", "ASSET") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultHandler is Test {
    ProtocolVault4626 public vault;
    MockVaultAssetInvariant public asset;

    uint256 public totalDepositedOrMintedAssets;
    uint256 public totalWithdrawnOrRedeemedAssets;

    constructor(ProtocolVault4626 vault_, MockVaultAssetInvariant asset_) {
        vault = vault_;
        asset = asset_;
    }

    function deposit(uint256 assets) external {
        assets = bound(assets, 1, 100 ether);

        asset.mint(address(this), assets);
        asset.approve(address(vault), assets);

        uint256 shares = vault.deposit(assets, address(this));

        if (shares > 0) {
            totalDepositedOrMintedAssets += assets;
        }
    }

    function mint(uint256 shares) external {
        shares = bound(shares, 1, 100 ether);

        uint256 requiredAssets = vault.previewMint(shares);

        asset.mint(address(this), requiredAssets);
        asset.approve(address(vault), requiredAssets);

        uint256 actualAssets = vault.mint(shares, address(this));

        totalDepositedOrMintedAssets += actualAssets;
    }

    function withdraw(uint256 assets) external {
        uint256 maxAssets = vault.maxWithdraw(address(this));
        if (maxAssets == 0) return;

        assets = bound(assets, 1, maxAssets);

        uint256 withdrawnAssets = assets;
        vault.withdraw(withdrawnAssets, address(this), address(this));

        totalWithdrawnOrRedeemedAssets += withdrawnAssets;
    }

    function redeem(uint256 shares) external {
        uint256 maxShares = vault.maxRedeem(address(this));
        if (maxShares == 0) return;

        shares = bound(shares, 1, maxShares);

        uint256 expectedAssets = vault.previewRedeem(shares);
        uint256 actualAssets = vault.redeem(shares, address(this), address(this));

        assertEq(actualAssets, expectedAssets, "redeem should match previewRedeem");

        totalWithdrawnOrRedeemedAssets += actualAssets;
    }
}

contract VaultInvariantTest is StdInvariant, Test {
    ProtocolVault4626 internal vault;
    MockVaultAssetInvariant internal asset;
    VaultHandler internal handler;

    function setUp() public {
        asset = new MockVaultAssetInvariant();
        vault = new ProtocolVault4626(asset, "Protocol Vault", "PV");

        handler = new VaultHandler(vault, asset);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = VaultHandler.deposit.selector;
        selectors[1] = VaultHandler.mint.selector;
        selectors[2] = VaultHandler.withdraw.selector;
        selectors[3] = VaultHandler.redeem.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_TotalAssetsEqualsActualVaultBalance() public view {
        assertEq(
            vault.totalAssets(),
            asset.balanceOf(address(vault)),
            "totalAssets must equal actual asset balance"
        );
    }

    function invariant_OnlyHandlerOwnsShares() public view {
        assertEq(
            vault.totalSupply(),
            vault.balanceOf(address(handler)),
            "all shares should belong to handler in this invariant test"
        );
    }

    function invariant_AssetsNeverExceedDepositsMinusWithdrawals() public view {
        uint256 expectedUpperBound =
            handler.totalDepositedOrMintedAssets() - handler.totalWithdrawnOrRedeemedAssets();

        assertLe(
            vault.totalAssets(),
            expectedUpperBound,
            "vault assets should not exceed tracked net deposits"
        );
    }

    function invariant_ConversionsAreMonotonic() public view {
        uint256 sharesFromTenAssets = vault.convertToShares(10 ether);
        uint256 sharesFromTwentyAssets = vault.convertToShares(20 ether);

        assertGe(
            sharesFromTwentyAssets,
            sharesFromTenAssets,
            "more assets should not convert to fewer shares"
        );

        uint256 assetsFromTenShares = vault.convertToAssets(10 ether);
        uint256 assetsFromTwentyShares = vault.convertToAssets(20 ether);

        assertGe(
            assetsFromTwentyShares,
            assetsFromTenShares,
            "more shares should not convert to fewer assets"
        );
    }

    function invariant_TotalSupplyAndAssetsMoveTogether() public view {
        if (vault.totalSupply() == 0) {
            assertEq(vault.totalAssets(), 0, "zero supply should leave no managed assets");
        } else {
            assertGt(vault.totalAssets(), 0, "positive supply should have positive assets");
        }
    }
}
