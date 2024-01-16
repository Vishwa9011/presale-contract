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
        IERC20 _tokenAddress,
        uint8 _tokenDecimals,
        address _weth,
        address _uniswapv2Router,
        address _uniswapv2Factory,
        address _teamWallet,
        address _launchpadOwner,
        bool _burnToken,
        bool _isWhitelist,
        Presale.Pool memory _pool
    ) external onlyOwner() payable returns (address) {
        Presale presale = new Presale(_tokenAddress,_tokenDecimals,_weth,_uniswapv2Router,_uniswapv2Factory,_teamWallet,_launchpadOwner,_burnToken,_isWhitelist,_pool);

        transferTokenToPresale(presale,address(_tokenAddress));
        
        IPresaleList presaleList = IPresaleList(presaleListContract);
        presaleList.addPresale(address(presale));

        presale.transferOwnership(msg.sender);

        // take 1BNB for creating Pool // for testnet
        uint poolFee = getPoolFee();
        if(msg.value > 0 && poolFee == msg.value) {
            (bool _success,)= payable(_launchpadOwner).call{value: msg.value }("");
            require(_success, "Transfer failed.");
        }else{
            revert("Pool fee is not valid");
        }

        emit PresaleCreated(address(presale), msg.sender);
        return address(presale);
    }

    function transferTokenToPresale(Presale presale,address _tokenAddress) internal {
        uint256 presaleTokenToDeposit = presale.getTokensToDeposit();
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(presale), presaleTokenToDeposit);
        presale.setPresaleTokens(presaleTokenToDeposit);

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
