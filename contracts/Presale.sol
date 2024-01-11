// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        // solhint-disable-next-line
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Whitelist is Ownable {
  mapping(address => bool) public whitelists;

  function addWhitelist(address _address) external onlyOwner() {
    require(_address != address(0), "Invalid address");
    require(whitelists[_address] == false, "Already whitelisted");

    whitelists[_address] = true;
  }

  function addMultipleWhitelist(address[] memory _addresses) external onlyOwner() {
    for(uint256 i = 0; i < _addresses.length; i++){
      whitelists[_addresses[i]] = true;
    }
  }

  function removeWhitelist(address _address) external onlyOwner() {
    require(_address != address(0), "Invalid address");
    require(whitelists[_address] == true, "User not whitelisted");

    whitelists[_address] = false;
  }

  function removeMultipleWhitelist(address[] memory _addresses) external onlyOwner(){
    for(uint256 i = 0; i < _addresses.length; i++){
      whitelists[_addresses[i]] = false;
    }
  }
}

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
  uint256 public tokenDecimals; // token decimals
  uint8 constant private FEE = 5; // 5% of eth raised
  uint8 constant private EMERGENCY_WITHDRAW_FEE = 10; // 10% of contributor balance
  address public teamWallet;  // wallet of the team (platform fees address)
  address public creatorWallet; // wallet of the creator of the presale
  address weth; // weth address for uniswap

  struct Pool {
    uint256 saleRate; // 1 BNB = ? tokens -> for presale
    uint256 listingRate;  // 1 BNB = ? tokens -> for listing after presale
    uint256 softCap;
    uint256 hardCap;
    uint256 minBuy;
    uint256 maxBuy;
    uint256 liquidityPercent;
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
  constructor(
    IERC20 _tokenAddress,
    uint256 _tokenDecimals, 
    address _weth,
    address _uniswapv2Router,
    address _uniswapv2Factory,
    address _teamWallet,
    bool _burnToken,
    bool _isWhitelist
  ) {
    require(_weth != address(0), "Invalid weth address");
    require(_teamWallet != address(0), "Invalid team wallet address");
    require(_uniswapv2Router != address(0), "Invalid router address");
    require(_uniswapv2Factory != address(0), "Invalid factory address");
    require(_tokenAddress != IERC20(address(0)), "Invalid token address");
    require(_tokenDecimals >= 0 && _tokenDecimals <= 18, "Invalid token decimals");

    isInitialized = false;
    isFinished = false;
    burnToken = false;
    isRefund = false;
    ethRaised = 0;

    weth = _weth;
    burnToken = _burnToken;
    teamWallet = _teamWallet;
    isWhitelist = _isWhitelist;
    creatorWallet = msg.sender;
    tokenDecimals = _tokenDecimals;
    tokenInstance = IERC20(_tokenAddress);
    UniswapV2Router02 = IUniswapV2Router02(_uniswapv2Router);
    UniswapV2Factory = IUniswapV2Factory(_uniswapv2Factory);

    require(UniswapV2Factory.getPair(address(tokenInstance),weth) == address(0), "Pair already exists");
    tokenInstance.approve(_uniswapv2Router, tokenInstance.totalSupply());
  }


  // modifiers 
  modifier onlyActive(){
    require(block.timestamp >= pool.startTime && block.timestamp <= pool.endTime, "Sale must be active");
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

  event Liquified(address indexed _token,address indexed _router, uint256 _amount);

  /*
    * @dev function to initialize the sale
  */

  function initSale(
    uint256 _startTime,
    uint256 _endTime,
    uint256 _saleRate,
    uint256 _listingRate,
    uint256 _softCap,
    uint256 _hardCap,
    uint256 _minBuy,
    uint256 _maxBuy,
    uint256 _liquidityPercent,
    uint256 _lockPeriod 
  ) external onlyOwner() {

    require(isInitialized == false, "Sale is already initialized");
    require(_startTime >= block.timestamp, "Invalid start time.");
    require(_endTime > _startTime, "Invalid end time.");
    require(_softCap >= _hardCap / 4, "Soft cap must be at least 25% of hard cap.");
    require(_liquidityPercent > 50 && _liquidityPercent <= 100, "Liquidity percent must be between 51 and 100.");
    require(_saleRate > 0, "Sale rate must be greater than 0.");
    require(_listingRate > 0, "Listing rate must be greater than 0.");
    require(_minBuy > 0, "Min buy must be greater than 0.");
    require(_maxBuy > _minBuy, "Max buy must be greater than min buy.");

    Pool memory newPool = Pool({
      saleRate: _saleRate,
      listingRate: _listingRate,
      softCap: _softCap,
      hardCap: _hardCap,
      minBuy: _minBuy,
      maxBuy: _maxBuy,
      liquidityPercent: _liquidityPercent,
      lockPeriod: _lockPeriod,
      startTime: _startTime,
      endTime: _endTime
    });
    
    pool = newPool;
    isInitialized = true;
  }

  /*
    * @dev function to deposit tokens into the contract
  */

  function deposit() external onlyOwner() onlyInActive(){
    require(isInitialized == true, "Sale is not initialized");
    require(isTokenDeposited == false,"Tokens already deposited");

    presaleTokens = pool.hardCap * pool.saleRate / (10 ** 18);
    uint256 totalDeposit = _getTokensToDeposit();
    isTokenDeposited = true;

    require(tokenInstance.transferFrom(msg.sender, address(this),totalDeposit),"Deposit Failed");
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
    uint256 tokensForSale = ethRaised * pool.saleRate / (10 ** 18);
    uint256 tokensForLiquidity = ethRaised * pool.listingRate * pool.liquidityPercent / 100;
    tokensForLiquidity = tokensForLiquidity - (tokensForLiquidity * FEE / 100) / (10 ** 18);

    // transfer tokens to liquidity
    uint256 liquidityETH =  _getLiquidityETH();
    UniswapV2Router02.addLiquidityETH{value : liquidityETH}(address(tokenInstance), tokensForLiquidity, tokensForLiquidity, liquidityETH,owner(), block.timestamp + (pool.lockPeriod * 1 minutes));
    emit Liquified(address(this), address(UniswapV2Router02),liquidityETH);
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
        uint256 remainTokens = _getTokensToDeposit() - tokensForSale - tokensForLiquidity;
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
    * @dev function to cancel the sale
  */
  function cancelSale() external onlyOwner() onlyActive(){
    require(ethRaised < pool.hardCap, "Hard cap reached");
    require(isFinished == false, "Sale is already finished");
    pool.endTime = 0;
    isRefund = true;

    uint256 tokenBalance = tokenInstance.balanceOf(address(this));
    if(tokenBalance > 0){
      uint256 tokenDeposit = _getTokensToDeposit();
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
      uint256 tokenDeposit = _getTokensToDeposit();
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
    * @dev function to set whitelist
  */

  function setWhitelist(bool _isWhitelist) external onlyOwner(){
    isWhitelist = _isWhitelist;
  }

  /*
    * @dev function to buy tokens
  */
  function buyTokens(address _contributor) public payable onlyActive(){
    require(isTokenDeposited,"Tokens not deposited");

    uint256 _amount = msg.value;
    _checkSaleRequirements(_contributor, _amount);
    uint256 tokensAmount = _amount * pool.saleRate;
    ethRaised += _amount;
    presaleTokens -= tokensAmount;
    contributorBalance[_contributor] += _amount;
    emit Bought(_contributor, _amount);
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



  /*
    * @dev internal function
  */

  // adjust decimals;
  function _adjustDecimals(uint256 _amount) internal pure returns(uint256) {
    uint256 adjustedAmount = _amount / (10 ** 18);
    return adjustedAmount;
  }

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
    uint256 tokens = contributorBalance[_contributor] * pool.saleRate;
    return tokens;
  }

  // get liquidityTokens to deposit 
  function _getLiquidityTokensToDeposit() internal view returns(uint256) {
    uint256 tokens = pool.hardCap * pool.liquidityPercent * pool.listingRate / 100;
    tokens = tokens - (tokens * FEE / 100);
    return tokens / (10 ** 18);
  }

  // function to get how many tokens he needs to deposit;
  function _getTokensToDeposit() internal view returns(uint256) {
    uint256 tokensForSale = pool.hardCap * pool.saleRate / (10 ** 18);
    uint256 tokensForLiquidity = _getLiquidityTokensToDeposit();
    return tokensForSale + tokensForLiquidity;
  }

}