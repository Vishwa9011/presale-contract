// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import "./Ownable.sol";

contract PresaleList is Ownable {
  address[] public presales;

  function addPresale(address _presale) external {
    presales.push(_presale);
  }
  
  function getPresales() external view returns (address[] memory) {
    return presales;
  }
}
