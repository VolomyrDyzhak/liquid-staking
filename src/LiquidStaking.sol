// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract LiquidStaking is ERC20, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public totalPooledEth;

    event Deposited(address indexed user, uint256 ethIn, uint256 sharesOut);
    event Withdrawn(address indexed user, uint256 sharesIn, uint256 ethOut);
    event RewardsReported(uint256 amount, uint256 newRate);

    constructor(address admin) ERC20("Staked ETH Simple", "sETH") {
        require(admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function exchangeRate() public view returns (uint256) {
        if (totalSupply() == 0) return 1e18;
        return (totalPooledEth * 1e18) / totalSupply();
    }

    function deposit() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Empty deposit");
        uint256 shares = totalSupply() == 0 ? msg.value : (msg.value * totalSupply()) / totalPooledEth;
        require(shares > 0, "Zero shares");
        totalPooledEth += msg.value;
        _mint(msg.sender, shares);
        emit Deposited(msg.sender, msg.value, shares);
    }

    // slither-disable-start low-level-calls
    function withdraw(uint256 shares) external nonReentrant whenNotPaused {
        require(shares > 0 && balanceOf(msg.sender) >= shares, "Insufficient balance");
        uint256 amount = (shares * totalPooledEth) / totalSupply();
        require(amount <= address(this).balance, "Insufficient liquidity");
        _burn(msg.sender, shares);
        totalPooledEth -= amount;

        // Intentional: call instead of transfer (2300 gas limit).
        // Protected by nonReentrant and checks-effects-interactions.
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");
        emit Withdrawn(msg.sender, shares, amount);
    }
    // slither-disable-end low-level-calls

    function reportRewards() external payable onlyRole(ORACLE_ROLE) {
        totalPooledEth += msg.value;
        emit RewardsReported(msg.value, exchangeRate());
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
