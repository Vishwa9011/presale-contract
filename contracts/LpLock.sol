// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract LiquidityLock is ReentrancyGuard {
  using SafeERC20 for IERC20;

  IERC20 public lpToken;
  address public owner;
  uint256 public unlockTime;

  constructor(IERC20 _lpToken, uint256 _unlockTime) {
    owner = msg.sender;
    lpToken = IERC20(_lpToken);
    unlockTime = _unlockTime;
  }

  function deposit(uint256 amount) external nonReentrant() {
    require(msg.sender == owner,"Only owner can deposit lpTokens");
    lpToken.transferFrom(msg.sender, address(this), amount);
  }

  function withdraw() external nonReentrant() {
    require(msg.sender == owner, "Only owner can release lpTokens");
    require(block.timestamp >= unlockTime,  "LpTokens are locked");
    lpToken.transfer(owner, lpToken.balanceOf(address(this)));
  }
} 