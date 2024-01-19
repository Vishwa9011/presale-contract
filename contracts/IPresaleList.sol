// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPresaleList {
    function addPresale(address _presale) external;
    function getPresales() external view returns (address[] memory);
    function addPresaleContributions(address _user, address _presale) external;
}
