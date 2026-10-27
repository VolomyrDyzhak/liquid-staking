// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LiquidStaking} from "../../src/LiquidStaking.sol";
import {LiquidStakingHandler} from "../handlers/LiquidStakingHandler.sol";

contract LiquidStakingInvariantTest is Test {
    LiquidStaking staking;
    LiquidStakingHandler handler;

    function setUp() public {
        staking = new LiquidStaking(address(this));
        handler = new LiquidStakingHandler(staking);
        staking.grantRole(staking.ORACLE_ROLE(), address(handler));
        targetContract(address(handler));
    }

    function invariant_contractBalanceCoversPool() public view {
        assertGe(address(staking).balance, staking.totalPooledEth());
    }

    function invariant_rateNeverBelowOne() public view {
        assertGe(staking.exchangeRate(), 1e18);
    }

    function invariant_supplyEqualsSumOfBalances() public view {
        assertEq(staking.totalSupply(), handler.sumBalances());
    }
}
