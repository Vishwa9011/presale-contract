// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract PresaleList {
  address[] public presales;

  function addPresale(address _presale) external {
    presales.push(_presale);
  }

  function removePresale(address _presale) external {
    for (uint256 i = 0; i < presales.length; i++) {
      if (presales[i] == _presale) {
        delete presales[i];
      }
    }
  }
  
  function getPresales() external view returns (address[] memory) {
    return presales;
  }
}
