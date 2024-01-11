// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Presale.sol";

interface PresaleList{
    function addPresale(address _presale) external;
    function removePresale(address _presale) external;
    function getPresales() external view returns (address[] memory);
}

contract PresaleFactory {

  address public presaleListContract = 0x3aEe8787aC34a8875C2d98B73C41333B6820C985;

  event PresaleCreated(address presaleAddress, address owner);

  function createPresale(IERC20 _tokenAddress,uint256 _tokenDecimals, address _weth,address _uniswapv2Router,address _uniswapv2Factory,address _teamWallet,bool _burnToken,bool _isWhitelist) external returns (address){
    Presale presale = new Presale(_tokenAddress,_tokenDecimals,_weth,_uniswapv2Router,_uniswapv2Factory,_teamWallet,_burnToken,_isWhitelist);

    PresaleList presaleList = PresaleList(presaleListContract);
    presaleList.addPresale(address(presale));

    emit PresaleCreated(address(presale), msg.sender);
    return address(presale);
  }

  function setPresaleList(address _presaleList) external {
    presaleListContract = _presaleList;
  }
}