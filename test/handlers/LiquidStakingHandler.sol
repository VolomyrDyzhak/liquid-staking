// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LiquidStaking} from "../../src/LiquidStaking.sol";

contract LiquidStakingHandler is Test {
    LiquidStaking public staking;
    address[] public actors;

    constructor(LiquidStaking _staking) {
        staking = _staking;
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1 ether, 100 ether);
        vm.deal(actor, amount);
        vm.prank(actor);
        staking.deposit{value: amount}();
    }

    function withdraw(uint256 actorSeed, uint256 shares) external {
        address actor = actors[actorSeed % actors.length];
        uint256 bal = staking.balanceOf(actor);
        if (bal == 0) return;
        shares = bound(shares, 1, bal);
        vm.prank(actor);
        staking.withdraw(shares);
    }

    function reportRewards(uint256 amount) external {
        amount = bound(amount, 1, 10 ether);
        vm.deal(address(this), amount);
        staking.reportRewards{value: amount}();
    }

    function sumBalances() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            sum += staking.balanceOf(actors[i]);
        }
    }
}
