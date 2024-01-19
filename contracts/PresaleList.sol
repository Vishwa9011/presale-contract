// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "./Ownable.sol";
import "./Presale.sol";
import "./Whitelist.sol";

interface IPresale{
  function contributorBalance(address) external view returns (uint);
  function pool() external view returns (Presale.Pool memory);
  function tokenInstance() external view returns (IERC20);
  function ethRaised() external view returns (uint);
  function getPresaleData() external view returns (Presale.PresaleData memory);
}

contract PresaleList is Ownable, Whitelist {
  address[] public presales;

  mapping(address => address[]) public userPresaleContributions; // user => presales[] where user has contributed

  function addPresale(address _presale) external onlyWhitelisted {
    require(_presale != address(0), "PresaleList: Presale is the zero address");
    presales.push(_presale);
  }

  function addPresaleContributions(address _user, address _presale) external {
    require(_user != address(0), "PresaleList: User is the zero address");
    require(_presale != address(0), "PresaleList: Presale is the zero address");

    IPresale presale = IPresale(_presale);
    require(presale.contributorBalance(_user) > 0, "PresaleList: User has no contributions");
    
    // check if user has already contributed to this presale
    uint _length = userPresaleContributions[_user].length;
    for (uint i = 0; i < _length; i++){
      if (userPresaleContributions[_user][i] == _presale){
        return;
      }
    }
    userPresaleContributions[_user].push(_presale);
  }

  struct PresaleData2 {
    address presale;
    Presale.PresaleData data;
  }

  function getPresaleContributions(address _user) external view returns(PresaleData2[] memory){
    uint _length = userPresaleContributions[_user].length;
    PresaleData2[] memory presaleData = new PresaleData2[](_length);
    for (uint i = 0; i < _length; i++){
      IPresale presale = IPresale(userPresaleContributions[_user][i]);
      presaleData[i] = PresaleData2(userPresaleContributions[_user][i], presale.getPresaleData());
    }
    return presaleData;
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
