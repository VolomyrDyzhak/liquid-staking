// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {LiquidStaking} from "../src/LiquidStaking.sol";

contract LiquidStakingRolesTest is Test {
    LiquidStaking staking;
    address admin = makeAddr("admin");
    address oracle = makeAddr("oracle");
    address pauser = makeAddr("pauser");
    address alice = makeAddr("alice");

    // Stored before using vm.prank, because a call like
    // staking.ORACLE_ROLE() would consume the prank.
    bytes32 ORACLE;
    bytes32 PAUSER;
    bytes32 ADMIN_ROLE;

    function setUp() public {
        staking = new LiquidStaking(admin);
        ORACLE = staking.ORACLE_ROLE();
        PAUSER = staking.PAUSER_ROLE();
        ADMIN_ROLE = staking.DEFAULT_ADMIN_ROLE();
        vm.deal(oracle, 10 ether);
        vm.deal(admin, 10 ether);
        vm.deal(alice, 10 ether);
    }

    function _unauthorized(address who, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, who, role);
    }

    function test_adminStartsWithNoOperationalRoles() public view {
        assertTrue(staking.hasRole(ADMIN_ROLE, admin));
        assertFalse(staking.hasRole(ORACLE, admin));
        assertFalse(staking.hasRole(PAUSER, admin));
    }

    function test_adminCannotReportRewardsWithoutOracleRole() public {
        vm.prank(admin);
        vm.expectRevert(_unauthorized(admin, ORACLE));
        staking.reportRewards{value: 1 ether}();
    }

    function test_oracleCanReportRewards() public {
        vm.prank(admin);
        staking.grantRole(ORACLE, oracle);

        vm.prank(alice);
        staking.deposit{value: 10 ether}();
        vm.prank(oracle);
        staking.reportRewards{value: 1 ether}();

        assertEq(staking.exchangeRate(), 1.1 ether);
    }

    function test_nonOracleCannotReportRewards() public {
        vm.prank(alice);
        vm.expectRevert(_unauthorized(alice, ORACLE));
        staking.reportRewards{value: 1 ether}();
    }

    function test_pauserCanPause() public {
        vm.prank(admin);
        staking.grantRole(PAUSER, pauser);
        vm.prank(pauser);
        staking.pause();
        assertTrue(staking.paused());
    }

    function test_oracleCannotPause() public {
        vm.prank(admin);
        staking.grantRole(ORACLE, oracle);
        vm.prank(oracle);
        vm.expectRevert(_unauthorized(oracle, PAUSER));
        staking.pause();
    }

    function test_onlyAdminCanGrantRoles() public {
        vm.prank(alice);
        vm.expectRevert(_unauthorized(alice, ADMIN_ROLE));
        staking.grantRole(ORACLE, alice);
    }

    function test_revokedOracleCannotReportRewards() public {
        vm.startPrank(admin);
        staking.grantRole(ORACLE, oracle);
        staking.revokeRole(ORACLE, oracle);
        vm.stopPrank();

        vm.prank(oracle);
        vm.expectRevert(_unauthorized(oracle, ORACLE));
        staking.reportRewards{value: 1 ether}();
    }
}
