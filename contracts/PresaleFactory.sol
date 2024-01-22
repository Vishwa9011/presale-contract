// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Presale.sol";
import "./Ownable.sol";
import "./Deployment.sol";
import "./IPresaleList.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract PresaleFactory is Ownable {
    using SafeERC20 for IERC20;

    address public presaleListContract;
    address public deploymentContract;
    uint public poolFee;

    constructor(address _presaleList, uint _poolFee) {
        presaleListContract = _presaleList;
        deploymentContract = address(new Deployment());
        poolFee = _poolFee;
    }

    // events
    event PresaleCreated(address indexed presaleAddress, address indexed owner);

    // errors
    error TransferFailed();
    error InvalidPoolFee();
    error PresaleBalanceMismatch(uint256 expected, uint256 actual);

    function createPresale(
        Presale.PresaleInfo memory _presaleInfo,
        Presale.Pool memory _pool,
        Presale.Links memory _links
    ) external payable returns (address) {
        if(msg.value != poolFee) revert InvalidPoolFee();

        Deployment deployment = Deployment(deploymentContract);

        Presale presale = deployment.deployContract(_presaleInfo, _pool, _links, presaleListContract);

        transferTokenToPresale(presale, address(_presaleInfo.tokenAddress));
        IPresaleList(presaleListContract).addPresale(address(presale));
        presale.transferOwnership(msg.sender);

        (bool _success,)= payable(_presaleInfo.launchpadOwner).call{value: msg.value }("");
        if(!_success) revert("Transfer failed");

        emit PresaleCreated(address(presale), msg.sender);
        return address(presale);
    }

    function transferTokenToPresale(Presale presale,address _tokenAddress) internal {
        presale.deposit();
        uint256 presaleTokenToDeposit = presale.getTokensToDeposit();
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(presale), presaleTokenToDeposit);

        uint256 presaleContractbalance = IERC20(_tokenAddress).balanceOf(address(presale));
        if(presaleContractbalance != presaleTokenToDeposit) {
            revert PresaleBalanceMismatch(presaleTokenToDeposit, presaleContractbalance);
        }
    }

    function setPresaleListAddress(address _presaleList) external onlyOwner() {
        presaleListContract = _presaleList;
    }

    function setDeploymentAddress(address _deployment) external onlyOwner() {
        deploymentContract = _deployment;
    }

    function setPoolFee(uint _poolFee) external onlyOwner() {
        poolFee = _poolFee;
    }
}
