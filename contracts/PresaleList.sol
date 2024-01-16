// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "./Ownable.sol";
import "./Presale.sol";
import "./Whitelist.sol";

contract PresaleList is Ownable, Whitelist {
  address[] public presales;

  function addPresale(address _presale) external onlyWhitelisted {
    presales.push(_presale);
  }
  
  function getPresales() external view returns (address[] memory) {
    return presales;
  }
}
