// SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./Ownable.sol";
import "./Whitelist.sol";
import "./IPresaleList.sol";

import "hardhat/console.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function addLiquidityETH(address token,uint256 amountTokenDesired,uint256 amountTokenMin,uint256 amountETHMin,address to,uint256 deadline) external payable returns (uint256 amountToken,uint256 amountETH,uint256 liquidity);
    function WETH() external pure returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPinkLock {
   function lock(address owner, address token,bool isLpToken,uint256 amount,uint256 unlockDate,string memory description) external returns (uint256 lockId);
   function unlock(uint256 lockId) external;
}

interface IERC20Metadata {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
}

contract Presale is Ownable, Whitelist, ReentrancyGuard {
  using SafeERC20 for IERC20;

  bool public isWhitelist;
  bool public isTokenDeposited;
  bool public isInitialized;
  bool public isFinished;
  bool public burnToken;
  bool public isRefund;
  uint256 public ethRaised; // total eth raised
  uint256 public presaleTokens; // tokens for presale
  uint8 private FEE = 5; // 5% of eth raised
  uint8 private EMERGENCY_WITHDRAW_FEE = 10; // 10% of contributor balance
  address public immutable teamWallet;  // wallet of the team (platform fees address)
  address public immutable weth; // weth address for uniswap
  address public immutable launchpadOwner; // launchpad owner address
  address public immutable presaleList; // presale list cont. address
  uint256 public pinkLockId;
 

  struct Pool {
    uint256 saleRate; // 1 BNB = ? tokens -> for presale
    uint256 listingRate;  // 1 BNB = ? tokens -> for listing after presale
    uint256 softCap;
    uint256 hardCap;
    uint256 minBuy;
    uint256 maxBuy;
    uint8 liquidityPercent;
    uint256 lockPeriod; // lock period after listing
    uint256 startTime; // unix
    uint256 endTime; // unix
  }

  struct Links {
    string logo;
    string website;
    string facebook;
    string twitter;
    string github;
    string telegram;
    string instagram;
    string reddit;
    string discord;
    string description;
  }

  struct PresaleInfo {
    address tokenAddress;
    address pinkLock;
    address uniswapv2Router;
    address teamWallet;
    address launchpadOwner;
    bool burnToken;
    bool isWhitelist;
  }

  Pool public pool;
  Links public links;
  IPinkLock public pinkLock; // lp token address
  IERC20 public tokenInstance;  
  IUniswapV2Router02 public UniswapV2Router02;
  IUniswapV2Factory public UniswapV2Factory;

  mapping(address => uint256) public contributorBalance; // contributor address => eth contributed

  // constructor
  constructor(PresaleInfo memory presaleInfo, Pool memory newPool, Links memory _links, address _presaleList) {
    if (presaleInfo.teamWallet == address(0)) revert InvalidTeamWalletAddress();
    if (presaleInfo.launchpadOwner == address(0)) revert InvalidLaunchpadOwnerAddress();
    if (presaleInfo.uniswapv2Router == address(0)) revert InvalidRouterAddress();
    if (presaleInfo.tokenAddress == address(0)) revert InvalidTokenAddress();
    if (presaleInfo.pinkLock == address(0)) revert InvalidPinkLockAddress();
    if (_presaleList == address(0)) revert InvalidPresaleListAddress();

    // Error handling for pool
    if (newPool.endTime <= newPool.startTime) revert InvalidEndTime();
    if (newPool.minBuy <= 0) revert MinBuyTooLow();
    if (newPool.saleRate <= 0) revert SaleRateTooLow();
    if (newPool.startTime < block.timestamp) revert InvalidStartTime();
    if (newPool.listingRate <= 0) revert ListingRateTooLow();
    if (newPool.maxBuy <= newPool.minBuy) revert MaxBuyTooLow();
    if (newPool.softCap < newPool.hardCap / 4) revert SoftCapTooLow();
    if (newPool.liquidityPercent <= 50 || newPool.liquidityPercent > 100) revert InvalidLiquidityPercent();


    ethRaised = 0;
    isRefund = false;
    burnToken = false;
    isFinished = false;
    isInitialized = true;

    presaleList = _presaleList; // presale list contract address
    burnToken = presaleInfo.burnToken;
    teamWallet = presaleInfo.teamWallet;
    launchpadOwner = presaleInfo.launchpadOwner;
    isWhitelist = presaleInfo.isWhitelist;
    pinkLock = IPinkLock(presaleInfo.pinkLock);
    tokenInstance = IERC20(presaleInfo.tokenAddress);
    UniswapV2Router02 = IUniswapV2Router02(presaleInfo.uniswapv2Router);

    weth = UniswapV2Router02.WETH();
    UniswapV2Factory = IUniswapV2Factory(UniswapV2Router02.factory());

    address lpAddress = UniswapV2Factory.getPair(address(tokenInstance), weth);
    require(tokenInstance.balanceOf(lpAddress) == 0, "Pair already has liquidity");
    tokenInstance.approve(presaleInfo.uniswapv2Router, tokenInstance.totalSupply());

    // initialize the sale
    pool = newPool;
    links = _links;
  }
 

  // modifiers 
  modifier onlyActive(){
   require(block.timestamp >= pool.startTime && block.timestamp < pool.endTime, "Sale must be active");
    _;
  }

  modifier onlyOwnerAndLaunchpadOwner() {
    require(_msgSender() == owner() || _msgSender() == launchpadOwner,"Caller must be owner");
    _;
  }

  modifier onlyLaunchpadOwner(){
    require(_msgSender() == launchpadOwner,"Caller must be launchpad owner");
    _;
  }

  modifier onlyInActive(){
    require(block.timestamp < pool.startTime || block.timestamp > pool.endTime || ethRaised >= pool.hardCap, "Sale must be inactive");
    _;
  }

  modifier onlyRefund() {
    require(isRefund == true ||(block.timestamp > pool.endTime && ethRaised < pool.softCap), "Refund unavailable");
    _;
  }

  // events   
  event Deposited(address indexed _initiator, uint256 _amount);
  event Bought(address indexed _buyer, uint256 _amount);
  event Refunded(address indexed _refunder, uint256 _amount);
  event Claimed(address indexed _participent, uint256 _amount);
  event Withdraw(address indexed _initiator, uint256 _amount);
  event EmergencyWithdraw(address indexed _initiator, uint256 _amount);
  event Cancelled(address indexed _initiator, address indexed token, address indexed presale);
  event BurnRemainder(address indexed _initiator, uint256 _amount);
  event RefundRemainder(address indexed _initiator, uint256 _amount);
  event Liquified(address indexed _token,address indexed _router, address indexed _pair);

  // errors
  error InvalidTeamWalletAddress();
  error InvalidLaunchpadOwnerAddress();
  error InvalidRouterAddress();
  error InvalidTokenAddress();
  error InvalidPinkLockAddress();
  error InvalidPresaleListAddress();
  error InvalidEndTime();
  error MinBuyTooLow();
  error SaleRateTooLow();
  error InvalidStartTime();
  error ListingRateTooLow();
  error MaxBuyTooLow();
  error SoftCapTooLow();
  error InvalidLiquidityPercent();
  error SoftCapNotReached();
  error SaleNotStarted();
  error RefundAlreadyDone();
  error SaleAlreadyFinished();
  /*
    * @dev function to deposit tokens into the contract
  */

  function deposit() external onlyOwner onlyInActive nonReentrant{
    require(isInitialized == true, "Sale is not initialized");
    require(isTokenDeposited == false,"Tokens already deposited");

    presaleTokens = pool.hardCap * pool.saleRate / (10 ** 18);
    uint256 totalDeposit = getTokensToDeposit();
    isTokenDeposited = true;

    emit Deposited(msg.sender, totalDeposit);
  }

  /*
    * @dev function to finish the sale
  */
  function finishSale() external onlyOwner onlyInActive nonReentrant{
    if (ethRaised < pool.softCap) revert SoftCapNotReached();
    if (block.timestamp <= pool.startTime) revert SaleNotStarted();
    if (isRefund) revert RefundAlreadyDone();
    if (isFinished) revert SaleAlreadyFinished();

    isFinished = true;
    // getting used amount of tokens
    uint256 tokensForSale = ethRaised * pool.saleRate / (10 ** 18);
    uint256 tokensForLiquidity = ethRaised * pool.listingRate * pool.liquidityPercent / 100;
    tokensForLiquidity =tokensForLiquidity / (10 ** 18);
    tokensForLiquidity = tokensForLiquidity - (tokensForLiquidity * FEE / 100);

    // check the token balance on pair
    address lpAddress = UniswapV2Factory.getPair(address(tokenInstance), weth);
    require(tokenInstance.balanceOf(lpAddress) == 0, "Pair already has liquidity");

    // transfer tokens to liquidity
    uint256 liquidityETH =  _getLiquidityETH();
    (uint256 amountToken, uint256 amountETH,) = UniswapV2Router02.addLiquidityETH{value : liquidityETH}(address(tokenInstance), tokensForLiquidity, tokensForLiquidity, liquidityETH, address(this), block.timestamp);
    require(amountToken == tokensForLiquidity && amountETH == liquidityETH, "Liquidity add failed");
    
    // lock liquidity
    lockLiquidity();

    // transfer fees and share
    transferFeesAndShare();

    // if hardcap is not reached then burn or refund the remain tokens
    handleRemainingTokens(tokensForSale, tokensForLiquidity);
  }

  /*
    * @dev function to release lp tokens
  */
  function releaseLpTokens() external onlyOwner onlyInActive{
    require(isFinished == true, "Sale is not finished");
    pinkLock.unlock(pinkLockId);
    // transfer lp tokens to owner
    address lpToken = UniswapV2Factory.getPair(address(tokenInstance), weth);
    uint256 lpTokenBalance = IERC20(lpToken).balanceOf(address(this));
    IERC20(lpToken).safeTransfer(owner(), lpTokenBalance);
  }

  /*
    * @dev function to cancel the sale
  */
  function cancelSale() external onlyOwnerAndLaunchpadOwner onlyActive nonReentrant{
    require(ethRaised < pool.hardCap, "Hard cap reached");
    require(isFinished == false, "Sale is already finished");
    pool.endTime = 0;
    isRefund = true;

    uint256 tokenBalance = tokenInstance.balanceOf(address(this));
    if(tokenBalance > 0){
      safeTransferWithCheck(owner(), tokenBalance);
      emit Withdraw(owner(), tokenBalance);
    }
    emit Cancelled(msg.sender, address(tokenInstance),address(this));
  }

  /*
    * @dev function to refund
  */

  function refund() external onlyInActive onlyRefund nonReentrant{
    uint256 refundAmount = contributorBalance[msg.sender];
    require(refundAmount > 0, "No refund available");
    if(address(this).balance > refundAmount){
      if(refundAmount > 0){
        contributorBalance[msg.sender] = 0;
        sendEther(msg.sender, refundAmount);
        emit Refunded(msg.sender, refundAmount);
      }
    }
  }

  /*
    * @dev function to claim tokens after listing
  */
  function claimTokens() external onlyInActive nonReentrant{
    require(isFinished , "Sale is still active");
    
    uint256 tokensAmount = _getUserTokens(msg.sender);
    require(tokensAmount > 0, "No tokens to claim");
    contributorBalance[msg.sender] = 0;
    safeTransferWithCheck(_msgSender(), tokensAmount);
    emit Claimed(msg.sender, tokensAmount);
  }

  /*
    * @dev function to withdraw tokens or refund
  */
  function withdrawTokens() external onlyOwnerAndLaunchpadOwner onlyInActive onlyRefund nonReentrant{
    uint256 tokenBalance = tokenInstance.balanceOf(address(this));
    if(tokenBalance > 0){
      uint256 tokenDeposit = getTokensToDeposit();
      tokenInstance.safeTransfer(owner(), tokenDeposit);
      emit Withdraw(owner(), tokenDeposit);
    }
  }

  /*
    * @dev Emergency withdraw function
    * if user wants to cancelBuy and get refund for his amount
    * 10% fee will be deducted for emergency withdraw
  */
  function emergencyWithdraw() external onlyActive nonReentrant{
    uint256 refundAmount = contributorBalance[msg.sender];
    require(refundAmount > 0, "No refund available");
    if(address(this).balance > refundAmount){
      if(refundAmount > 0){
        uint256 deductedAmount = refundAmount * EMERGENCY_WITHDRAW_FEE / 100;
        refundAmount = refundAmount - deductedAmount;

        contributorBalance[msg.sender] = 0;
        payable(owner()).transfer(deductedAmount);
        payable(msg.sender).transfer(refundAmount);
        emit Refunded(msg.sender, refundAmount);
      }
    }
  }

  /*
    * @dev function to buy tokens
  */
  function buyTokens() public payable onlyActive nonReentrant{
    require(isTokenDeposited,"Tokens not deposited");
    require(isRefund == false,"Sale has been cancelled");

    uint256 _amount = msg.value;
    _checkSaleRequirements(msg.sender, _amount);
    uint256 tokensAmount = _getUserTokens(msg.sender);
    ethRaised += _amount;
    presaleTokens -= tokensAmount;
    contributorBalance[msg.sender] += _amount;

    // add user contribution to presale list
    IPresaleList(presaleList).addPresaleContributions(msg.sender, address(this));
    emit Bought(msg.sender, _amount);
  }

  // check sale requirements
  function _checkSaleRequirements(address _contributor,uint256 _amount) private {
    if(isWhitelist){
      require(whitelists[_contributor] == true, "User not whitelisted");
    }
    require(_contributor != address(0), "Invalid contributor address.");
    require(_amount >= pool.minBuy,"Amount is less than min buy.");
    require(_amount + contributorBalance[_contributor] <= pool.maxBuy,"Max buy limit exceeded.");
    require(ethRaised + _amount <= pool.hardCap,"Hardcap reached.");
  }

  // function to get how many tokens he needs to deposit;
  function getTokensToDeposit() public view returns(uint256) {
    uint256 tokensForSale = pool.hardCap * pool.saleRate / (10 ** 18);
    uint256 tokensForLiquidity = _getLiquidityTokensToDeposit();
    return (tokensForSale + tokensForLiquidity);
  }

  // function to get info of the pool
  struct PresaleData {
    Pool pool;
    string logo;
    string tokenName;
    string tokenSymbol;
    uint256 ethRaised;
    uint256 presaleTokens;
    address tokenAddress;
    address owner;
    bool isWhitelist;
    bool isFinished;
    bool burnToken;
    bool isRefund;
  }

  function getPresaleData() external view returns (PresaleData memory) {
    IERC20Metadata token = IERC20Metadata(address(tokenInstance));
    return PresaleData({
      pool: pool,
      ethRaised: ethRaised,
      tokenName: token.name(),
      tokenSymbol: token.symbol(),
      tokenAddress: address(tokenInstance),
      presaleTokens: presaleTokens,
      owner: owner(),
      isWhitelist: isWhitelist,
      isFinished: isFinished,
      burnToken: burnToken,
      isRefund: isRefund,
      logo: links.logo
    });
  }

  /*
    * @dev private functions
   */

  function lockLiquidity() private {
    address lpToken = UniswapV2Factory.getPair(address(tokenInstance), weth);
    uint256 liquidityAmount = IERC20(lpToken).balanceOf(address(this));
    IERC20(lpToken).approve(address(pinkLock), liquidityAmount);
    
    uint256 unlockDate = block.timestamp + (pool.lockPeriod * 1 minutes);
    pinkLockId = pinkLock.lock(address(this), lpToken, true, liquidityAmount, unlockDate, "Liquidity Lock");

    emit Liquified(address(this), address(UniswapV2Router02), lpToken);
  }
  
  // trasfer fees and share
  function transferFeesAndShare() private {
    uint256 fees = _getTeamFee();
    uint256 creatorShare = _getOwnerShare();

    sendEther(owner(), creatorShare);
    sendEther(teamWallet, fees);
  }

  function handleRemainingTokens(uint256 tokensForSale, uint256 tokensForLiquidity) private {
    if (ethRaised < pool.hardCap) {
      uint256 remainTokens = getTokensToDeposit() - tokensForSale - tokensForLiquidity;
      if (burnToken) {
        tokenInstance.safeTransfer(address(0), remainTokens);
        emit BurnRemainder(msg.sender, remainTokens);
      } else {
        safeTransferWithCheck(owner(), remainTokens);
      }
    }
  }

  function safeTransferWithCheck(address recipient, uint256 amount) private {
    uint256 balanceBefore = tokenInstance.balanceOf(recipient);
    tokenInstance.safeTransfer(recipient, amount);
    uint256 balanceAfter = tokenInstance.balanceOf(recipient);
    if (balanceBefore + amount != balanceAfter) revert("Token getting tax on transfer, please exclude this contract from tax");
    emit RefundRemainder(recipient, amount);
  }

  /*
    * @dev internal function
  */
  // get team fees
  function _getTeamFee() internal view returns(uint256) {
     return (ethRaised * FEE / 100);
  }

  // get owner share
  function _getOwnerShare() internal view returns(uint256) {
    uint256 teamFee = _getTeamFee();
    uint256 liquidityEthFee = _getLiquidityETH();
    uint256 share = ethRaised - (teamFee + liquidityEthFee);
    return share;
  }

  function _getLiquidityETH() internal view returns(uint256) {
    uint256 liquidityETH = ethRaised * pool.liquidityPercent / 100;
    return liquidityETH;
  }

  function _getUserTokens(address _contributor) internal view returns(uint256) {
    uint256 tokens = contributorBalance[_contributor] * pool.saleRate / (10 ** 18);
    return tokens;
  }

  // get liquidityTokens to deposit 
  function _getLiquidityTokensToDeposit() internal view returns(uint256) {
    uint256 tokens = pool.hardCap * pool.liquidityPercent * pool.listingRate / 100;
    tokens = tokens - (tokens * FEE / 100);
    return tokens / (10 ** 18);
  }

  function sendEther(address to, uint256 amount) internal{
    (bool success, ) = payable(to).call{value: amount}("");
    require(success, "Failed to send Ether");
  }

  // setter functions
  function setWhitelist(bool _isWhitelist) external onlyOwner{
    isWhitelist = _isWhitelist;
  }

  function setPoolTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
    require(block.timestamp < pool.endTime, "Sale is already finished");
    require(_startTime > block.timestamp, "Invalid start time.");
    require(_endTime > _startTime, "Invalid end time.");
    pool.startTime = _startTime;
    pool.endTime = _endTime;
  }

  function setSocialLinks(Links memory _links) external onlyOwner {
    links = _links;
  }

  function setFee(uint8 _fee) external onlyLaunchpadOwner {
    require(_fee > 0 && _fee <= 10, "Invalid fee");
    FEE = _fee;
  }

  function setEmergencyWithdrawFee(uint8 _fee) external onlyLaunchpadOwner {
    require(_fee > 0 && _fee <= 10, "Invalid fee");
    EMERGENCY_WITHDRAW_FEE = _fee;
  }

  // fallback security emergency withdraw
  function withdrawEth () external onlyLaunchpadOwner returns (bool) {
    uint256 balance = address(this).balance;
    (bool success, ) = payable(msg.sender).call{
        value: balance
    }("");
    return success;
  }

  // this function is to withdraw BEP20 tokens sent to this address by mistake
  function withdrawBEP20 (address _tokenAddress) external onlyLaunchpadOwner returns (bool) {
    IERC20 token = IERC20(_tokenAddress);
    uint256 balance = token.balanceOf(address(this));
    bool success = token.transfer(msg.sender, balance);
    return success;
  }
}

