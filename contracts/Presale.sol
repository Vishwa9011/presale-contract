// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import "./Ownable.sol";
import "./Whitelist.sol";
import "./LpLock.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(address token,uint amountTokenDesired,uint amountTokenMin,uint amountETHMin,address to,uint deadline) external 
    payable returns (uint amountToken,uint amountETH,uint liquidity);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract Presale is Ownable, Whitelist {
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
  address public immutable teamWallet;  // wallet of the team (platform fees address)
  address public immutable creatorWallet; // wallet of the creator of the presale
  address public immutable weth; // weth address for uniswap
  address public lpLock; // lp lock contract address

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

  Pool public pool;
  IERC20 public tokenInstance;  
  IUniswapV2Router02 public UniswapV2Router02;
  IUniswapV2Factory public UniswapV2Factory;


  mapping(address => uint256) public contributorBalance; // contributor address => eth contributed

  // constructor
  constructor(IERC20 _tokenAddress,uint8 _tokenDecimals, address _weth, address _uniswapv2Router, address _uniswapv2Factory, address _teamWallet, bool _burnToken, bool _isWhitelist, Pool memory newPool) {
    require(_weth != address(0), "Invalid weth address");
    require(_teamWallet != address(0), "Invalid team wallet address");
    require(_uniswapv2Router != address(0), "Invalid router address");
    require(_uniswapv2Factory != address(0), "Invalid factory address");
    require(_tokenAddress != IERC20(address(0)), "Invalid token address");
    require(_tokenDecimals >= 0 && _tokenDecimals <= 18, "Invalid token decimals");

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

    weth = _weth;
    burnToken = _burnToken;
    teamWallet = _teamWallet;
    isWhitelist = _isWhitelist;
    creatorWallet = msg.sender;
    tokenDecimals = _tokenDecimals;
    tokenInstance = IERC20(_tokenAddress);
    UniswapV2Router02 = IUniswapV2Router02(_uniswapv2Router);
    UniswapV2Factory = IUniswapV2Factory(_uniswapv2Factory);

    require(UniswapV2Factory.getPair(address(tokenInstance), weth) == address(0), "Pair already exists");
    tokenInstance.approve(_uniswapv2Router, tokenInstance.totalSupply());

    // initialize the sale
    pool = newPool;
  }
 

  // modifiers 
  modifier onlyActive(){
   require(block.timestamp >= pool.startTime && block.timestamp < pool.endTime, "Sale must be active");
    _;
  }

  modifier onlyInActive(){
    require(block.timestamp < pool.startTime || block.timestamp > pool.endTime || ethRaised >= pool.hardCap, "Sale must be inactive");
    _;
  }

  modifier onlyRefund(){
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

  function deposit() external onlyOwner() onlyInActive(){
    require(isInitialized == true, "Sale is not initialized");
    require(isTokenDeposited == false,"Tokens already deposited");

    presaleTokens = pool.hardCap * pool.saleRate / (10 ** 18) / (10 ** (18 - tokenDecimals));
    uint256 totalDeposit = getTokensToDeposit();
    isTokenDeposited = true;

    require(tokenInstance.transferFrom(msg.sender, address(this), totalDeposit),"Deposit Failed");
    emit Deposited(msg.sender, totalDeposit);
  }

  /*
    * @dev function to finish the sale
  */
  function finishSale() external onlyOwner() onlyInActive(){
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
    (uint amountToken, uint amountETH,) = UniswapV2Router02.addLiquidityETH{value : liquidityETH}(address(tokenInstance), tokensForLiquidity, tokensForLiquidity, liquidityETH, owner(), block.timestamp);
    require(amountToken == tokensForLiquidity && amountETH == liquidityETH, "Liquidity add failed");
    
    // lock liquidity
    address lpToken = UniswapV2Factory.getPair(address(tokenInstance), UniswapV2Router02.WETH());
    
    LiquidityLock lock = new LiquidityLock(IERC20(lpToken), block.timestamp + (pool.lockPeriod * 1 minutes));
    lpToken.approve(address(lock), lpToken.totalSupply());

    // transfer liquidity tokens to lock contract
    lpToken.transfer(address(lock), lpToken.balanceOf(address(this)));

    emit Liquified(address(this), address(UniswapV2Router02), UniswapV2Factory.getPair(address(tokenInstance), weth));
    

    // transfer fees(eth) to team 
    uint256 fees = _getTeamFee();
    payable(teamWallet).transfer(fees);

    // transfer eth to owner
    uint256 creatorShare = _getOwnerShare();
    if(creatorShare > 0){
      payable(creatorWallet).transfer(creatorShare);
    }

    // if hardcap is not reached then burn or refund the remain tokens
    if(ethRaised < pool.hardCap){
        uint256 remainTokens = getTokensToDeposit() - tokensForSale - tokensForLiquidity;
      if(burnToken){
        require(tokenInstance.transfer(address(0), remainTokens),"Burn Failed");
        emit BurnRemainder(msg.sender, remainTokens);
      }else{
        require(tokenInstance.transfer(msg.sender, remainTokens),"Refund Failed");
        emit RefundRemainder(msg.sender, remainTokens);
      }
    }
  }

  /*
    * @dev function to release lp tokens
  */

  function releaseLpTokens() external onlyOwner() onlyInActive(){
    LiquidityLock lock = LiquidityLock(lpLock);
    lock.withdraw();
  }

  /*
    * @dev function to cancel the sale
  */
  function cancelSale() external onlyOwner() onlyActive(){
    require(ethRaised < pool.hardCap, "Hard cap reached");
    require(isFinished == false, "Sale is already finished");
    pool.endTime = 0;
    isRefund = true;

    uint256 tokenBalance = tokenInstance.balanceOf(address(this));
    if(tokenBalance > 0){
      uint256 tokenDeposit = getTokensToDeposit();
      require(tokenInstance.transfer(msg.sender, tokenDeposit),"Withdraw Failed");
      emit Withdraw(msg.sender, tokenDeposit);
    }
    emit Cancelled(msg.sender, address(tokenInstance),address(this));
  }


  /*
    * @dev function to refund
  */

  function refund() external onlyInActive() onlyRefund(){
    uint256 refundAmount = contributorBalance[msg.sender];
    require(refundAmount > 0, "No refund available");
    if(address(this).balance > refundAmount){
      if(refundAmount > 0){
        contributorBalance[msg.sender] = 0;
        address payable refunder = payable(msg.sender);
        refunder.transfer(refundAmount);
        emit Refunded(msg.sender, refundAmount);
      }
    }
  }

  /*
    * @dev function to claim tokens after listing
  */

  function claimTokens() external onlyInActive(){
    require(isFinished , "Sale is still active");
    
    uint256 tokensAmount = _getUserTokens(msg.sender);
    require(tokensAmount > 0, "No tokens to claim");
    contributorBalance[msg.sender] = 0;
    require(tokenInstance.transfer(msg.sender, tokensAmount), "Claim Failed");
    emit Claimed(msg.sender, tokensAmount);
  }

  /*
    * @dev function to withdraw tokens or refund
  */
  function withdrawTokens() external onlyOwner() onlyInActive() onlyRefund(){
    uint256 tokenBalance = tokenInstance.balanceOf(address(this));
    if(tokenBalance > 0){
      uint256 tokenDeposit = getTokensToDeposit();
      require(tokenInstance.transfer(msg.sender, tokenDeposit),"Withdraw Failed");
      emit Withdraw(msg.sender, tokenDeposit);
    }
  }

  /*
    * @dev Emergency withdraw function
    * if user wants to cancelBuy and get refund for his amount
    * 10% fee will be deducted for emergency withdraw
  */
  function emergencyWithdraw() external onlyActive(){
    uint256 refundAmount = contributorBalance[msg.sender];
    require(refundAmount > 0, "No refund available");
    if(address(this).balance > refundAmount){
      if(refundAmount > 0){
        uint256 deductedAmount = refundAmount * EMERGENCY_WITHDRAW_FEE / 100;
        refundAmount = refundAmount - deductedAmount;

        contributorBalance[msg.sender] = 0;
        payable(creatorWallet).transfer(deductedAmount);
        payable(msg.sender).transfer(refundAmount);
        emit Refunded(msg.sender, refundAmount);
      }
    }
  }


  /*
    * @dev function to buy tokens
  */
  function buyTokens() public payable onlyActive(){
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


  // setter functions

  function setWhitelist(bool _isWhitelist) external onlyOwner(){
    isWhitelist = _isWhitelist;
  }

  function setPoolStartTime(uint256 _startTime) external onlyOwner() onlyInActive(){
    require(_startTime >= block.timestamp, "Invalid start time.");
    require(_startTime < pool.endTime, "Invalid start time.");
    pool.startTime = _startTime;
  }

  function setPoolEndTime(uint256 _endTime) external onlyOwner() onlyInActive(){
    require(_endTime > pool.startTime, "Invalid end time.");
    pool.endTime = _endTime;
  }

  function setPresaleTokens(uint256 _presaleTokens) external onlyOwner() onlyInActive(){
    require(presaleTokens ==0, "Presale tokens already set.");
    require(_presaleTokens > 0, "Invalid presale tokens.");
    presaleTokens = _presaleTokens;
  }
}

