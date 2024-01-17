// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "./Ownable.sol";
import "./Presale.sol";
import "./Whitelist.sol";

interface IPresale{
  function pool() external view returns (Presale.Pool memory);
  function tokenInstance() external view returns (IERC20);
  function ethRaised() external view returns (uint);
  function getPresaleData() external view returns (Presale.PresaleData memory);
}

contract PresaleList is Ownable, Whitelist {
  address[] public presales;

  function addPresale(address _presale) external onlyWhitelisted {
    require(_presale != address(0), "PresaleList: Presale is the zero address");
    presales.push(_presale);
  }


  struct PresaleData2 {
    address presale;
    Presale.PresaleData data;
  }

  function getPresales() external view returns (PresaleData2[] memory) {
    PresaleData2[] memory presaleData = new PresaleData2[](presales.length);
    for (uint256 i = 0; i < presales.length; i++) {
      IPresale presale = IPresale(presales[i]);
      presaleData[i] = PresaleData2(presales[i], presale.getPresaleData());
    }
    return presaleData;
  }

}
