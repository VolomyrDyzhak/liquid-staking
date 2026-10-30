// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LiquidStaking} from "../src/LiquidStaking.sol";

contract Deploy is Script {
    function run() external returns (LiquidStaking staking) {
        // The deployer becomes admin and pauser. The oracle defaults to the
        // deployer too, unless ORACLE_ADDRESS is set in the environment.
        address oracle = vm.envOr("ORACLE_ADDRESS", msg.sender);

        vm.startBroadcast();
        staking = new LiquidStaking(msg.sender);
        staking.grantRole(staking.PAUSER_ROLE(), msg.sender);
        staking.grantRole(staking.ORACLE_ROLE(), oracle);
        vm.stopBroadcast();

        console.log("LiquidStaking deployed at:", address(staking));
        console.log("Admin / pauser:", msg.sender);
        console.log("Oracle:", oracle);
    }
}
