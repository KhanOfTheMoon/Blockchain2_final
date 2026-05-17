// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DemoToken} from "../src/token/DemoToken.sol";
import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {AMMPool} from "../src/amm/AMMPool.sol";

contract CreateAmmPool is Script {
    address constant GOVERNANCE_TOKEN = 0x8BaCd978227c916d8D2B23b833C9fc8b6790b892;
    address constant AMM_FACTORY = 0x66fc88804a37B7f15d616202Ca0dA57D073eFc69;

    uint256 constant INITIAL_GOV_LIQUIDITY = 1_000 ether;
    uint256 constant INITIAL_DEMO_LIQUIDITY = 1_000 ether;

    function run()
        external
        returns (
            address demoToken,
            address pool,
            address lpToken
        )
    {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        DemoToken demo = new DemoToken(deployer);
        demoToken = address(demo);

        AMMFactory factory = AMMFactory(AMM_FACTORY);

        (pool, lpToken) = factory.createPool(
            GOVERNANCE_TOKEN,
            demoToken,
            "GOV-DEMO LP Token",
            "GOVDEMO-LP"
        );

        IERC20(GOVERNANCE_TOKEN).approve(pool, INITIAL_GOV_LIQUIDITY);
        IERC20(demoToken).approve(pool, INITIAL_DEMO_LIQUIDITY);

        AMMPool(pool).addLiquidity(
            INITIAL_GOV_LIQUIDITY,
            INITIAL_DEMO_LIQUIDITY,
            1,
            1,
            block.timestamp + 1 hours
        );

        vm.stopBroadcast();

        console.log("DemoToken:", demoToken);
        console.log("AMMPool:", pool);
        console.log("LPToken:", lpToken);
    }
}
