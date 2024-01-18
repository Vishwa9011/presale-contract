// SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./Ownable.sol";
import "./Whitelist.sol";

interface IUniswapV2Router02 {
    function addLiquidityETH(address token,uint amountTokenDesired,uint amountTokenMin,uint amountETHMin,address to,uint deadline) external payable returns (uint amountToken,uint amountETH,uint liquidity);
    function WETH() external pure returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IPinkLock {
   function lock(address owner,address token,bool isLpToken,uint256 amount,uint256 unlockDate,string memory description) external returns (uint256 lockId);
   function unlock(uint256 lockId) external;
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
  uint8 public tokenDecimals; // token decimals
  uint8 constant private FEE = 5; // 5% of eth raised
  uint8 constant private EMERGENCY_WITHDRAW_FEE = 10; // 10% of contributor balance
  uint8 constant private POOL_FEE = 1;
  address public immutable teamWallet;  // wallet of the team (platform fees address)
  address public immutable weth; // weth address for uniswap
  address public immutable launchpadOwner; // launchpad owner address
  uint public pinkLockId;

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
    uint8 tokenDecimals;
    address pinkLock;
    address weth;
    address uniswapv2Router;
    address uniswapv2Factory;
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
  constructor(PresaleInfo memory presaleInfo, Pool memory newPool, Links memory _links) {
    require(presaleInfo.weth != address(0), "Invalid weth address");
    require(presaleInfo.teamWallet != address(0), "Invalid team wallet address");
    require(presaleInfo.launchpadOwner != address(0), "Invalid launchpad owner address");
    require(presaleInfo.uniswapv2Router != address(0), "Invalid router address");
    require(presaleInfo.uniswapv2Factory != address(0), "Invalid factory address");
    require(presaleInfo.tokenAddress != address(0), "Invalid token address");
    require(presaleInfo.tokenDecimals >= 0 && presaleInfo.tokenDecimals <= 18, "Invalid token decimals");

    // require statements for pool
    require(newPool.endTime > newPool.startTime, "Invalid end time.");
    require(newPool.minBuy > 0, "Min buy must be greater than 0.");
    require(newPool.saleRate > 0, "Sale rate must be greater than 0.");
    require(newPool.startTime >= block.timestamp, "Invalid start time.");
    require(newPool.listingRate > 0, "Listing rate must be greater than 0.");
    require(newPool.maxBuy > newPool.minBuy, "Max buy must be greater than min buy.");
    require(newPool.softCap >= newPool.hardCap / 4, "Soft cap must be at least 25% of hard cap.");
    require(newPool.liquidityPercent > 50 && newPool.liquidityPercent <= 100, "Liquidity percent must be between 51 and 100.");

    ethRaised = 0;
    isRefund = false;
    burnToken = false;
    isFinished = false;
    isInitialized = true;

    weth = presaleInfo.weth;
    burnToken = presaleInfo.burnToken;
    teamWallet = presaleInfo.teamWallet;
    launchpadOwner = presaleInfo.launchpadOwner;
    isWhitelist = presaleInfo.isWhitelist;
    tokenDecimals = presaleInfo.tokenDecimals;
    pinkLock = IPinkLock(presaleInfo.pinkLock);
    tokenInstance = IERC20(presaleInfo.tokenAddress);
    UniswapV2Router02 = IUniswapV2Router02(presaleInfo.uniswapv2Router);
    UniswapV2Factory = IUniswapV2Factory(presaleInfo.uniswapv2Factory);

    require(UniswapV2Factory.getPair(address(tokenInstance), weth) == address(0), "Pair already exists");
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
    require(_msgSender() == owner() ,"Caller must be owner");
    _;
  }

  modifier onlyInActive(){
    require(block.timestamp < pool.startTime || block.timestamp > pool.endTime || ethRaised >= pool.hardCap, "Sale must be inactive");
    _;
  }

  modifier onlyRefund() {
    require(isRefund == true ||(block.timestamp > pool.endTime && ethRaised <= pool.hardCap), "Refund unavailable");
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

  /*
    * @dev function to deposit tokens into the contract
  */

  function deposit() external onlyOwner onlyInActive nonReentrant{
    require(isInitialized == true, "Sale is not initialized");
    require(isTokenDeposited == false,"Tokens already deposited");

    presaleTokens = pool.hardCap * pool.saleRate / (10 ** 18) / (10 ** (18 - tokenDecimals));
    uint256 totalDeposit = getTokensToDeposit();
    isTokenDeposited = true;

    emit Deposited(msg.sender, totalDeposit);
  }

  /*
    * @dev function to finish the sale
  */
  function finishSale() external onlyOwner onlyInActive nonReentrant{
    require(ethRaised >= pool.softCap, "Soft cap not reached");
    require(block.timestamp > pool.startTime, "Can not finish before sale start");
    require(isRefund == false,"Refund already done");
    require(isFinished == false, "Sale is already finished");

    isFinished = true;
    // getting used amount of tokens
    uint256 tokensForSale = ethRaised * pool.saleRate / (10 ** 18) / (10 ** (18 - tokenDecimals));
    uint256 tokensForLiquidity = ethRaised * pool.listingRate * pool.liquidityPercent / 100;
    tokensForLiquidity =tokensForLiquidity / (10 ** 18) / (10 ** (18 - tokenDecimals));
    tokensForLiquidity = tokensForLiquidity - (tokensForLiquidity * FEE / 100);

    // transfer tokens to liquidity
    uint256 liquidityETH =  _getLiquidityETH();
    (uint amountToken, uint amountETH,) = UniswapV2Router02.addLiquidityETH{value : liquidityETH}(address(tokenInstance), tokensForLiquidity, tokensForLiquidity, liquidityETH, address(this), block.timestamp);
    require(amountToken == tokensForLiquidity && amountETH == liquidityETH, "Liquidity add failed");
    
    // lock liquidity
    address lpToken = UniswapV2Factory.getPair(address(tokenInstance), weth);
    IERC20(lpToken).approve(address(pinkLock), tokensForLiquidity);
    uint liquidityAmount = IERC20(lpToken).balanceOf(address(this));
    
    IPinkLock lock = IPinkLock(pinkLock);
    uint256 unlockDate = block.timestamp + (pool.lockPeriod * 1 minutes);
    pinkLockId = lock.lock(address(this), lpToken, true, liquidityAmount, unlockDate, "Liquidity Lock");

    emit Liquified(address(this), address(UniswapV2Router02), lpToken);

    // transfer fees(eth) to team 
    uint256 fees = _getTeamFee();
    sendEther(teamWallet,fees);

    // transfer eth to owner
    uint256 creatorShare = _getOwnerShare();
    if(creatorShare > 0){
      sendEther(owner(), creatorShare);
    }

    // if hardcap is not reached then burn or refund the remain tokens
    if(ethRaised < pool.hardCap){
        uint256 remainTokens = getTokensToDeposit() - tokensForSale - tokensForLiquidity;
      if(burnToken){
        tokenInstance.safeTransfer(address(0), remainTokens);
        emit BurnRemainder(msg.sender, remainTokens);
      }else{
        tokenInstance.safeTransfer(msg.sender, remainTokens);
        emit RefundRemainder(msg.sender, remainTokens);
      }
    }
  }

  /*
    * @dev function to release lp tokens
  */
  function releaseLpTokens() external onlyOwner onlyInActive{
    require(isFinished == true, "Sale is not finished");
    pinkLock.unlock(pinkLockId);
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
      uint256 tokenDeposit = getTokensToDeposit();
      tokenInstance.safeTransfer(owner(), tokenDeposit);
      emit Withdraw(owner(), tokenDeposit);
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
    tokenInstance.safeTransfer(msg.sender, tokensAmount);
    emit Claimed(msg.sender, tokensAmount);
  }

  /*
    * @dev function to withdraw tokens or refund
  */
  function withdrawTokens() external onlyOwnerAndLaunchpadOwner onlyInActive onlyRefund  nonReentrant{
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
    emit Bought(msg.sender, _amount);
  }

  // check sale requirements
  function _checkSaleRequirements(address _contributor,uint256 _amount) internal view {
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
    uint256 tokensForSale = pool.hardCap * pool.saleRate / (10 ** 18) / (10 ** (18 - tokenDecimals));
    uint256 tokensForLiquidity = _getLiquidityTokensToDeposit();
    return (tokensForSale + tokensForLiquidity);
  }

  // function to get info of the pool
  struct PresaleData {
    Pool pool;
    uint256 ethRaised;
    uint256 presaleTokens;
    address tokenAddress;
    uint256 tokenDecimals;
    address owner;
    bool isWhitelist;
    bool isFinished;
    bool burnToken;
    bool isRefund;
  }

  function getPresaleData() external view returns (PresaleData memory) {
    return PresaleData({
      pool: pool,
      ethRaised: ethRaised,
      tokenAddress: address(tokenInstance),
      presaleTokens: presaleTokens,
      tokenDecimals: tokenDecimals,
      owner: owner(),
      isWhitelist: isWhitelist,
      isFinished: isFinished,
      burnToken: burnToken,
      isRefund: isRefund
    });
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
    uint256 tokens = contributorBalance[_contributor] * pool.saleRate / (10 ** 18) / (10 ** (18 - tokenDecimals));
    return tokens;
  }

  // get liquidityTokens to deposit 
  function _getLiquidityTokensToDeposit() internal view returns(uint256) {
    uint256 tokens = pool.hardCap * pool.liquidityPercent * pool.listingRate / 100;
    tokens = tokens - (tokens * FEE / 100);
    return tokens / (10 ** 18) / (10 ** (18 - tokenDecimals));
  }

  function sendEther(address to, uint amount) internal{
    (bool success, ) = payable(to).call{value: amount}("");
    require(success, "Failed to send Ether");
  }

  // setter functions
  function setWhitelist(bool _isWhitelist) external onlyOwner{
    isWhitelist = _isWhitelist;
  }

  function setPoolStartTime(uint _startTime, uint _endTime) external onlyOwner onlyInActive{
    require(_startTime > block.timestamp, "Invalid start time.");
    require(_endTime > _startTime, "Invalid end time.");
    pool.startTime = _startTime;
    pool.endTime = _endTime;
  }

  function setSocialLinks(Links memory _links) external onlyOwner {
    links = _links;
  }

}

