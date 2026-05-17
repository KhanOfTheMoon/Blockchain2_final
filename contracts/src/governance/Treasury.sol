// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Treasury {
    using SafeERC20 for IERC20;

    address public immutable timelock;

    event EthReceived(address indexed sender, uint256 amount);
    event EthWithdrawn(address indexed to, uint256 amount);
    event Erc20Withdrawn(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error NotTimelock();
    error EtherTransferFailed();

    constructor(address timelock_) {
        if (timelock_ == address(0)) revert ZeroAddress();
        timelock = timelock_;
    }

    modifier onlyTimelock() {
        if (msg.sender != timelock) revert NotTimelock();
        _;
    }

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    /// @notice Timelock-governed ERC20 withdrawal path.
    /// @dev Use SafeERC20 for compatibility with non-standard tokens.
    function withdrawERC20(IERC20 token, address to, uint256 amount) external onlyTimelock {
        if (to == address(0)) revert ZeroAddress();
        token.safeTransfer(to, amount);
        emit Erc20Withdrawn(address(token), to, amount);
    }

    /// @notice Timelock-governed ETH withdrawal path.
    /// @dev Uses call instead of transfer/send to avoid stipend assumptions.
    function withdrawETH(address payable to, uint256 amount) external onlyTimelock {
        if (to == address(0)) revert ZeroAddress();
        (bool success,) = to.call{value: amount}("");
        if (!success) revert EtherTransferFailed();
        emit EthWithdrawn(to, amount);
    }
}
