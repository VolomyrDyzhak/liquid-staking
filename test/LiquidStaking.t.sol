// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {LiquidStaking} from "../src/LiquidStaking.sol";

contract LiquidStakingTest is Test {
    LiquidStaking staking;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        staking = new LiquidStaking(address(this));
        staking.grantRole(staking.ORACLE_ROLE(), address(this));
        staking.grantRole(staking.PAUSER_ROLE(), address(this));
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_firstDepositMintsOneToOne() public {
        vm.prank(alice);
        staking.deposit{value: 10 ether}();
        assertEq(staking.balanceOf(alice), 10 ether);
        assertEq(staking.exchangeRate(), 1 ether);
    }

    function test_rewardsIncreaseRate() public {
        vm.prank(alice);
        staking.deposit{value: 10 ether}();
        staking.reportRewards{value: 1 ether}();
        assertEq(staking.exchangeRate(), 1.1 ether);
    }

    function test_secondDepositorGetsFewerShares() public {
        vm.prank(alice);
        staking.deposit{value: 10 ether}();
        staking.reportRewards{value: 1 ether}();
        vm.prank(bob);
        staking.deposit{value: 11 ether}();
        assertEq(staking.balanceOf(bob), 10 ether);
    }

    function test_withdrawReturnsPrincipalPlusRewards() public {
        vm.prank(alice);
        staking.deposit{value: 10 ether}();
        staking.reportRewards{value: 1 ether}();
        vm.prank(alice);
        staking.withdraw(10 ether);
        assertEq(alice.balance, 101 ether);
    }

    function test_revertsOnZeroDeposit() public {
        vm.prank(alice);
        vm.expectRevert("Deposito vacio");
        staking.deposit{value: 0}();
    }

    function test_onlyOracleReportsRewards() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert();
        staking.reportRewards{value: 1 ether}();
    }

    function testFuzz_depositWithdrawWithoutRewards(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        vm.startPrank(alice);
        staking.deposit{value: amount}();
        staking.withdraw(staking.balanceOf(alice));
        vm.stopPrank();
        assertEq(alice.balance, 100 ether);
    }

    function test_zeroSharesDepositReverts() public {
        vm.prank(alice);
        staking.deposit{value: 10 ether}();
        staking.reportRewards{value: 1 ether}(); // ratio 1.1

        vm.prank(bob);
        vm.expectRevert("Shares cero");
        staking.deposit{value: 1}(); // 1 wei -> 0 shares por redondeo
    }

    function test_extremeRateDoesNotSwallowDeposit() public {
        vm.prank(alice);
        staking.deposit{value: 1}(); // 1 wei -> 1 share
        staking.reportRewards{value: 10 ether}(); // ratio enorme

        vm.prank(bob);
        vm.expectRevert("Shares cero");
        staking.deposit{value: 5 ether}(); // 5 ETH -> 0 shares
    }

    function test_pausedBlocksDeposit() public {
        staking.pause();
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        staking.deposit{value: 1 ether}();
    }

    function test_pausedBlocksWithdraw() public {
        vm.prank(alice);
        staking.deposit{value: 1 ether}();
        staking.pause();
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        staking.withdraw(1 ether);
    }

    function test_onlyPauserCanPause() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.pause();
    }

    function test_unpauseRestoresOperation() public {
        staking.pause();
        staking.unpause();
        vm.prank(alice);
        staking.deposit{value: 1 ether}();
        assertEq(staking.balanceOf(alice), 1 ether);
    }
}
