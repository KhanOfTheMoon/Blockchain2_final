// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract VerifyDeployment is Script {
    function run() external {
        address target = vm.envAddress("VERIFY_ADDRESS");
        string memory contractName = vm.envString("VERIFY_CONTRACT");
        string memory chain = vm.envString("VERIFY_CHAIN");

        string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string(""));
        string memory rpcUrl = vm.envOr("VERIFY_RPC_URL", string(""));

        string[] memory verifyCmd = _buildVerifyCommand(target, contractName, chain, apiKey);
        vm.ffi(verifyCmd);

        if (bytes(rpcUrl).length != 0) {
            string[] memory callCmd = new string[](6);
            callCmd[0] = "cast";
            callCmd[1] = "call";
            callCmd[2] = vm.toString(target);
            callCmd[3] = "name()(string)";
            callCmd[4] = "--rpc-url";
            callCmd[5] = rpcUrl;
            vm.ffi(callCmd);
        }
    }

    function _buildVerifyCommand(
        address target,
        string memory contractName,
        string memory chain,
        string memory apiKey
    ) private view returns (string[] memory cmd) {
        bool hasApiKey = bytes(apiKey).length != 0;
        uint256 len = hasApiKey ? 9 : 7;
        cmd = new string[](len);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(target);
        cmd[3] = contractName;
        cmd[4] = "--chain";
        cmd[5] = chain;
        cmd[6] = "--watch";
        if (hasApiKey) {
            cmd[7] = "--etherscan-api-key";
            cmd[8] = apiKey;
        }
    }
}
