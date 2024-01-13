// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityLock {
  IERC20 public lpToken;
  address public owner;
  uint256 public unlockTime;

  constructor(address _lpToken, uint256 _unlockTime) {
    owner = msg.sender;
    lpToken = IERC20(_lpToken);
    unlockTime = _unlockTime;
  }

  function deposit(uint256 amount) external {
    require(msg.sender == owner,"Only owner can deposit lpTokens");
    lpToken.transferFrom(msg.sender, address(this), amount);
  }

  function withdraw() external {
    require(msg.sender == owner, "Only owner can release lpTokens");
    require(block.timestamp >= unlockTime,  "LpTokens are locked");
    lpToken.transfer(owner, lpToken.balanceOf(address(this)));
  }
} 