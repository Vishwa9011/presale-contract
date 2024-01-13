// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Presale.sol";
import "./Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPresaleList {
    function addPresale(address _presale) external;
    function getPresales() external view returns (address[] memory);
}

contract PresaleFactory is Ownable {
    address public presaleListContract;

    constructor(address _presaleList) {
        presaleListContract = _presaleList;
    }

    event PresaleCreated(address indexed presaleAddress, address indexed owner);

    function createPresale(
        IERC20 _tokenAddress,
        uint8 _tokenDecimals,
        address _weth,
        address _uniswapv2Router,
        address _uniswapv2Factory,
        address _teamWallet,
        bool _burnToken,
        bool _isWhitelist,
        Presale.Pool memory _pool
    ) external onlyOwner() returns (address) {
        Presale presale = new Presale(_tokenAddress,_tokenDecimals,_weth,_uniswapv2Router,_uniswapv2Factory,_teamWallet,_burnToken,_isWhitelist,_pool);

        uint256 presaleTokenToDeposit = presale.getTokensToDeposit();
        require(IERC20(_tokenAddress).transferFrom(msg.sender, address(presale), presaleTokenToDeposit),"Token transfer failed");
        presale.setPresaleTokens(presaleTokenToDeposit);

        uint256 presaleContractbalance = IERC20(_tokenAddress).balanceOf(address(presale));
        require(presaleContractbalance == presaleTokenToDeposit,"Presale contract balance is not equal to presale tokens");

        IPresaleList presaleList = IPresaleList(presaleListContract);
        presaleList.addPresale(address(presale));

        presale.transferOwnership(msg.sender);

        emit PresaleCreated(address(presale), msg.sender);
        return address(presale);
    }

    function setPresaleListAddress(address _presaleList) external onlyOwner() {
        presaleListContract = _presaleList;
    }
}
