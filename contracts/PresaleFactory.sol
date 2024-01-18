// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Presale.sol";
import "./Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPresaleList {
    function addPresale(address _presale) external;
    function getPresales() external view returns (address[] memory);
}

contract PresaleFactory is Ownable {
    using SafeERC20 for IERC20;

    address public presaleListContract;
    uint public POOL_FEE = 0.001 ether;

    constructor(address _presaleList) {
        presaleListContract = _presaleList;
    }

    event PresaleCreated(address indexed presaleAddress, address indexed owner);

    function createPresale(
        Presale.PresaleInfo memory _presaleInfo,
        Presale.Pool memory _pool,
        Presale.Links memory _links
    ) external payable returns (address) {
        Presale presale = new Presale(_presaleInfo, _pool, _links);

        transferTokenToPresale(presale,address(_presaleInfo.tokenAddress));
        
        IPresaleList presaleList = IPresaleList(presaleListContract);
        presaleList.addPresale(address(presale));

        presale.transferOwnership(msg.sender);

        // take 1BNB for creating Pool // for testnet
        uint poolFee = getPoolFee();
        if(msg.value > 0 && poolFee == msg.value) {
            (bool _success,)= payable(_presaleInfo.launchpadOwner).call{value: msg.value }("");
            require(_success, "Transfer failed.");
        }else{
            revert("Pool fee is not valid");
        }

        emit PresaleCreated(address(presale), msg.sender);
        return address(presale);
    }

    function transferTokenToPresale(Presale presale,address _tokenAddress) internal {
        presale.deposit();
        uint256 presaleTokenToDeposit = presale.getTokensToDeposit();
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(presale), presaleTokenToDeposit);
        uint256 presaleContractbalance = IERC20(_tokenAddress).balanceOf(address(presale));
        require(presaleContractbalance == presaleTokenToDeposit,"Presale contract balance is not equal to presale tokens");
    }

    function setPresaleListAddress(address _presaleList) external onlyOwner() {
        presaleListContract = _presaleList;
    }

    function setPoolFee(uint _poolFee) external onlyOwner() {
        POOL_FEE = _poolFee;
    }

    // getPoolFee according to chain
    function getPoolFee() internal view returns (uint) {
        return POOL_FEE;
    }
}
