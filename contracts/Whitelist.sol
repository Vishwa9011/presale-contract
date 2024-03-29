//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Ownable.sol";

abstract contract Whitelist is Ownable {
  mapping(address => bool) public whitelists;

  // modifier onlyWhitelisted() 
  modifier onlyWhitelisted() virtual {
    require(whitelists[msg.sender] == true, "User not whitelisted");
    _;
  }

  function addWhitelist(address _address) external onlyOwner() {
    require(_address != address(0), "Invalid address");
    require(whitelists[_address] == false, "Already whitelisted");

    whitelists[_address] = true;
  }

  function addMultipleWhitelist(address[] memory _addresses) external onlyOwner() {
    for(uint256 i = 0; i < _addresses.length; i++){
      whitelists[_addresses[i]] = true;
    }
  }

  function removeWhitelist(address _address) external onlyOwner() {
    require(_address != address(0), "Invalid address");
    require(whitelists[_address] == true, "User not whitelisted");

    whitelists[_address] = false;
  }

  function removeMultipleWhitelist(address[] memory _addresses) external onlyOwner(){
    for(uint256 i = 0; i < _addresses.length; i++){
      whitelists[_addresses[i]] = false;
    }
  }
}
