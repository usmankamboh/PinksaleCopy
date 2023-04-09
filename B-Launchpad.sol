// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.0;
import "IBEP20 code/Context.sol";
import "IBEP20 code/Ownable.sol";
import "IBEP20 code/Address.sol";
import "IBEP20 code/SafeMath.sol";
import "IBEP20 code/IBEP20.sol";
import "IBEP20 code/SafeBEP20.sol";
import "IBEP20 code/ReentrancyGuard.sol";
import "IBEP20 code/AggregatorV3Interface.sol";
import "IBEP20 code/IUniswapV2Pair.sol";
import "IBEP20 code/IUniswapV2Router01.sol";
import "IBEP20 code/IUniswapV2Router02.sol";
import "IBEP20 code/TrueLocker.sol";
    contract Launchpad is ReentrancyGuard, Context, Ownable {
    AggregatorV3Interface internal priceFeed;
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    uint256 public rate;
    uint public  startTime; // start sale time
    uint public  endTime; // end sale time
    IBEP20 private _token;
    address private _wallet;
    address private bnbAddress = 0xa92BdA9ED4f93F3FE6Db2b57fAA0b40e2810D976;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 private _price;
    uint256 private _weiRaised;
    uint256 public minPurchase;
    uint256 public maxPurchase;
    uint256 public availableTokens;
    uint256 public totalBnbFees = 0;     // withdrawable values
    uint256 public remainingBnbFees = 0;
    uint256 public depositId;
    uint256[] public allDepositIds;
    uint256 public lpFeePercent = 1;   // for statistic
    uint256 public bnbFee = 1 ether; // base 1000, 0.5% = value * 5 / 1000
    address[] tokenAddressesWithFees;
    bool public presaleResult;
    mapping(uint256 => Items) public lockedToken;
    mapping(address => uint256[]) public depositsByWithdrawalAddress;
    mapping(address => uint256[]) public depositsByTokenAddress;
    event TokensLocked(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime);
    mapping (address => bool) Claimed;
    mapping (address => uint256) CoinPaid;
    mapping (address => uint256) TokenBought;
    mapping (address => uint256) valDrop;
    mapping (address => uint256) public tokensFees;
    mapping (address => bool) private _isBlacklisted;
    mapping(address => mapping(address => uint256)) public walletTokenBalance;
    // PancakeSwap(Uniswap) Router and Pair Address
    IUniswapV2Router02 public immutable uniswapV2Router;
    event TokensPurchased(address indexed purchaser, address indexed buyer, uint256 value, uint256 amount);
    event DropSent(address[]  receiver, uint256[]  amount);
    event AirdropClaimed(address receiver, uint256 amount);
    event WhitelistSetted(address[] recipient, uint256[] amount);
    event SwapETHForBNB(uint256 amountIn, address[] path);
    event SwapBNBForETH(uint256 amount, address[] path);
    event TokensLocked(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime, uint256 depositId);
    event TokensWithdrawn(address indexed tokenAddress, address indexed receiver, uint256 amount);
      struct Items {
        address tokenAddress;
        address withdrawalAddress;
        uint256 tokenAmount;
        uint256 unlockTime;
        bool withdrawn;
    }
    /*modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }*/
    constructor (uint256 _rate, address wallet, IBEP20 token) {
        require(_rate > 0, "Pre-Sale: rate is 0");
        require(wallet != address(0), "Pre-Sale: wallet is the zero address");
        require(address(token) != address(0), "Pre-Sale: token is the zero address");
        rate = _rate;
        _wallet = wallet;
        _token = token;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x0000000000000000000000000000000000000000);
        uniswapV2Router = _uniswapV2Router;
        priceFeed = AggregatorV3Interface(0x0000000000000000000000000000000000000000);
    }
    receive() external payable {
        if(endTime > 0 && block.timestamp < endTime){
            buyTokens(_msgSender());
        } else {
            revert("Pre-Sale is closed");
        }
    }
    // Swap ETH with BNB(BUSD) token
    function swapETHForBNB(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = bnbAddress;
        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            _wallet, // Wallet address to recieve BNB
            block.timestamp.add(300)
        );
        emit SwapETHForBNB(amount, path);
    }
    function swapBNBForETH(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = bnbAddress;
        path[1] = uniswapV2Router.WETH();
        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            _wallet, // Wallet address to recieve BNB
            block.timestamp.add(300)
        );
        emit SwapBNBForETH(amount, path);
    
    }
    function lockTokens(
        address _tokenAddress,
        uint256 _amount,
        uint256 _unlockTime,
        bool _feeInBnb
    ) external payable returns (uint256 _id) {
        require(_amount > 0, 'Tokens amount must be greater than 0');
        require(_unlockTime < 10000000000, 'Unix timestamp must be in seconds, not milliseconds');
        require(_unlockTime > block.timestamp, 'Unlock time must be in future');
        require(!_feeInBnb || msg.value > bnbFee, 'BNB fee not provided');
        require(IBEP20(_tokenAddress).approve(address(this), _amount), 'Failed to approve tokens');
        require(IBEP20(_tokenAddress).transferFrom(msg.sender, address(this), _amount), 'Failed to transfer tokens to locker');
        uint256 lockAmount = _amount;
        if (_feeInBnb) {
            totalBnbFees = totalBnbFees.add(msg.value);
            remainingBnbFees = remainingBnbFees.add(msg.value);
        } else {
            uint256 fee = lockAmount.mul(lpFeePercent).div(1000);
            lockAmount = lockAmount.sub(fee);

            if (tokensFees[_tokenAddress] == 0) {
                tokenAddressesWithFees.push(_tokenAddress);
            }
            tokensFees[_tokenAddress] = tokensFees[_tokenAddress].add(fee);
        }

        walletTokenBalance[_tokenAddress][msg.sender] = walletTokenBalance[_tokenAddress][msg.sender].add(_amount);
        address _withdrawalAddress = msg.sender;
        _id = ++depositId;
        lockedToken[_id].tokenAddress = _tokenAddress;
        lockedToken[_id].withdrawalAddress = _withdrawalAddress;
        lockedToken[_id].tokenAmount = lockAmount;
        lockedToken[_id].unlockTime = _unlockTime;
        lockedToken[_id].withdrawn = false;
        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
        depositsByTokenAddress[_tokenAddress].push(_id);
        emit TokensLocked(_tokenAddress, msg.sender, _amount, _unlockTime, depositId);
    }
    //Start Pre-Sale
    function startSale(uint endDate, uint startDate,uint _minPurchase, uint _maxPurchase, uint256 _softCap, uint256 _hardCap) external onlyOwner iloNotActive() {
        require(endDate > block.timestamp, 'Pre-Sale: duration should be > 0');
        require(_minPurchase > 0, 'Pre-Sale: _minPurchase should > 0');
        startTime = startDate;
        endTime = endDate;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        softCap = _softCap;
        hardCap = _hardCap;
    }
    function stopSale() external onlyOwner iloActive() {
        endTime = 0;
        if(_weiRaised > softCap) {
          presaleResult = true;
        } else {
          presaleResult = false;
          _prepareRefund(_wallet);
        }
    }
    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
    //Pre-Sale
    function buyTokens(address buyer) public nonReentrant iloActive payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(buyer, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        _weiRaised = _weiRaised.add(weiAmount);
        availableTokens = availableTokens - tokens;
        Claimed[buyer] = false;
        CoinPaid[buyer] = weiAmount;
        TokenBought[buyer] = tokens;
        emit TokensPurchased(_msgSender(), buyer, weiAmount, tokens);
        _forwardFunds();
    }
    function _preValidatePurchase(address buyer, uint256 weiAmount) internal view {
        require(buyer != address(0), "Pre-Sale: buyer is the zero address");
        require(weiAmount != 0, "Pre-Sale: weiAmount is 0");
        require(weiAmount >= minPurchase, 'have to send at least: minPurchase');
        require(weiAmount <= maxPurchase, 'have to send max: maxPurchase');
        this;
    }
    function claimToken(address buyer) public iloNotActive() {
      require(Claimed[buyer] == false, "Pre-Sale: You did claim your tokens!");
      Claimed[buyer] = true;
      _processPurchase(buyer, TokenBought[buyer]);
    }
    function claimRefund(address buyer) public iloNotActive() {
       if(presaleResult == false) {
          require(Claimed[buyer] == false, "Pre-Sale: Only member can refund coins!");
          Claimed[buyer] = true;
          payable(buyer).transfer(CoinPaid[buyer]);
      }
    }
    function _deliverTokens(address buyer, uint256 tokenAmount) internal {
        _token.transfer(buyer, tokenAmount);
    }
    function _forwardFunds() internal {
        swapETHForBNB(msg.value);
    }
    function _prepareRefund(address _walletAddress) internal {
        uint256 bnbBalance = IBEP20(bnbAddress).balanceOf(_walletAddress);
        swapBNBForETH(bnbBalance);
    }
     function blacklistAddress(address account) public onlyOwner {
        _isBlacklisted[account] = true;
    }
    function whitelistAddress(address account) public onlyOwner {
        _isBlacklisted[account] = false;
    }
    function _processPurchase(address buyer, uint256 tokenAmount) internal {
        _deliverTokens(buyer, tokenAmount);
    }
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(rate).div(1000000);
    }
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, 'Pre-Sale: Contract has no money');
        payable(_wallet).transfer(address(this).balance);
    }
    function getToken() public view returns (IBEP20) {
        return _token;
    }
    function setRate(uint256 newRate) public onlyOwner {
        rate = newRate;
    }
   function setAvailableTokens(uint256 amount) public onlyOwner {
       availableTokens = amount;
   }
    function weiRaised() public view returns (uint256) {
       return _weiRaised;
    }
    modifier iloActive() {
        require(endTime > 0 && block.timestamp < endTime , "Pre-Sale: ILO must be active");
        //require(endTime > 0 && block.timestamp < endTime && availableTokens > 0, "Pre-Sale: ILO must be active");
        _;
    }
    modifier iloNotActive() {
        require(endTime < block.timestamp, 'Pre-Sale:  should not be active');
        _;
    }
}