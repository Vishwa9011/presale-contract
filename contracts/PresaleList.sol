// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "./Ownable.sol";
import "./Presale.sol";


contract PresaleList is Ownable {
  address[] public presales;

  function addPresale(address _presale) external {
    presales.push(_presale);
  }
  
  function getPresales() external view returns (address[] memory) {
    return presales;
  }
}
