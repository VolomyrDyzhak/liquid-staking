// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidStaking is ERC20, Ownable, ReentrancyGuard {
    uint256 public totalPooledEth;

    event Deposited(address indexed user, uint256 ethIn, uint256 sharesOut);
    event Withdrawn(address indexed user, uint256 sharesIn, uint256 ethOut);
    event RewardsReported(uint256 amount, uint256 newRate);

    constructor() ERC20("Staked ETH Simple", "sETH") Ownable(msg.sender) {}

    function exchangeRate() public view returns (uint256) {
        if (totalSupply() == 0) return 1e18;
        return (totalPooledEth * 1e18) / totalSupply();
    }

    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Deposito vacio");
        uint256 shares = totalSupply() == 0
            ? msg.value
            : (msg.value * totalSupply()) / totalPooledEth;
        totalPooledEth += msg.value;
        _mint(msg.sender, shares);
        emit Deposited(msg.sender, msg.value, shares);
    }

    function withdraw(uint256 shares) external nonReentrant {
        require(
            shares > 0 && balanceOf(msg.sender) >= shares,
            "Saldo insuficiente"
        );
        uint256 amount = (shares * totalPooledEth) / totalSupply();
        require(amount <= address(this).balance, "Sin liquidez");
        _burn(msg.sender, shares);
        totalPooledEth -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "Fallo el envio");
        emit Withdrawn(msg.sender, shares, amount);
    }

    function reportRewards() external payable onlyOwner {
        totalPooledEth += msg.value;
        emit RewardsReported(msg.value, exchangeRate());
    }
}
