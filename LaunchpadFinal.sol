// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "IBEP20 code/Context.sol";
import "IBEP20 code/Ownable.sol";
import "IBEP20 code/Address.sol";
import "IBEP20 code/SafeBEP20.sol";
import "IBEP20 code/ReentrancyGuard.sol";
import "IBEP20 code/SafeMath.sol";
import "IBEP20 code/IBEP20.sol";
import "IBEP20 code/AggregatorV3Interface.sol";
import "IBEP20 code/IUniswapV2Router02.sol";
    contract DemoGreenPresale is ReentrancyGuard, Context, Ownable {
    AggregatorV3Interface internal priceFeed;
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    uint256 private MIN_LOCKTIME;
    IBEP20 private _token;
    address private _wallet;
    uint256 private _rate;
    uint256 private _weiRaised;
    uint256 public endILO;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public unlockableTime;
    uint public minPurchase;
    uint public maxPurchase;
    uint public availableTokensILO;
    uint256 public totalBnbFees ;     // withdrawable values
    uint256 public remainingBnbFees;
    uint256 public depositId;
    uint256[] public allDepositIds;
   // uint256 public lpFeePercent ;
    uint256 public bnbFee = 1 ether; 
    address[] tokenAddressesWithFees;
    address private bnbAddress;
    bool public presaleResult;
    //mapping(address => uint256[]) public depositsByWithdrawalAddress;
    //mapping(address => uint256[]) public depositsByTokenAddress;
    event TokensLocked(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime);
    mapping (address => bool) Claimed;
    mapping (address => uint256) CoinPaid;
    mapping (address => uint256) TokenBought;
    mapping (address => uint256) valDrop;
    mapping (address => uint256) public tokensFees;
    // mapping(address => mapping(address => uint256)) public walletTokenBalance;
    // PancakeSwap(Uniswap) Router and Pair Address
    IUniswapV2Router02 public immutable uniswapV2Router;
    //event DropSent(address[]  receiver, uint256[]  amount);
    //event AirdropClaimed(address receiver, uint256 amount);
    //event WhitelistSetted(address[] recipient, uint256[] amount);
    event SwapETHForBNB(uint256 amountIn, address[] path);
    event SwapBNBForETH(uint256 amount, address[] path);
    event TokensLocked(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime, uint256 depositId);
    //event TokensWithdrawn(address indexed tokenAddress, address indexed receiver, uint256 amount);
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    modifier iloActive() {
        require(endILO > 0 && block.timestamp < endILO && availableTokensILO > 0, "ILO must be active");
        _;
    }
    modifier iloNotActive() {
        require(endILO < block.timestamp, 'ILO should not be active');
        _;
    }
    struct Items {
        address tokenAddress;
       // address withdrawalAddress;
        uint256 tokenAmount;
       // uint256 unlockTime;
       // bool withdrawn;
    }
    constructor (uint256 rate, address wallet, IBEP20 token) {
        require(rate > 0, "Pre-Sale: rate is 0");
        require(wallet != address(0), "Pre-Sale: wallet is the zero address");
        require(address(token) != address(0), "Pre-Sale: token is the zero address");
        _rate = rate;
        _wallet = wallet;
        _token = token;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x0000000000000000000000000000000000000000);
        uniswapV2Router = _uniswapV2Router;
        priceFeed = AggregatorV3Interface(0x0000000000000000000000000000000000000000);
    }
      receive() external payable {
        if(endILO > 0 && block.timestamp < endILO){
            buyTokens(_msgSender());
        } else {
            revert("Pre-Sale is closed");
        }
    }
    /*function lock(uint256 endDate) public onlyOwner {
        require(unlockableTime == 0, "LOCK: this contract already lock tokens");
        require(endDate > block.timestamp + MIN_LOCKTIME, "LOCK: endDate should be more than 1 week later from now");
        unlockableTime = endDate;
    }
    function unlock() public onlyOwner {
        unlockableTime = 0;
    }*/
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
            _wallet, // Wallet address to recieve USDT
            block.timestamp.add(300)
        );
        emit SwapETHForBNB(amount, path);
    }
    function swapUSDTForETH(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = bnbAddress;
        path[1] = uniswapV2Router.WETH();
        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            _wallet, // Wallet address to recieve USDT
            block.timestamp.add(300)
        );
        emit SwapBNBForETH(amount, path);
    }
    
    /*function lockTokens(
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
    } */

    //Start Pre-Sale
    function startILO(uint endDate, uint _minPurchase, uint _maxPurchase, uint _availableTokens) external onlyOwner iloNotActive() {
        require(unlockableTime == 0, "ILO: Tokens in the contract had been locked.");
        require(endDate > block.timestamp, 'ILO: Duration should be greater than zero');
        require(_availableTokens > 0 && _availableTokens <= _token.totalSupply(), 'ILO: availableTokens should be greater than zero and <= totalSupply');
        require(_minPurchase > 0, 'ILO: _minPurchase should be greater than zero');
        endILO = endDate;
        availableTokensILO = _availableTokens;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
    }
    function stopILO() external onlyOwner iloActive(){
        endILO = 0;
    }
    function buyTokens(address beneficiary) public nonReentrant iloActive payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        _weiRaised = _weiRaised.add(weiAmount);
        availableTokensILO = availableTokensILO - tokens;
        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
        _forwardFunds();
    }
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        require(weiAmount >= minPurchase, 'have to send at least: minPurchase');
        require(weiAmount <= maxPurchase, 'have to send max: maxPurchase');
        this;
    }
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.transfer(beneficiary, tokenAmount);
    }
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {

        _deliverTokens(beneficiary, tokenAmount);
    }
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {

        return weiAmount.mul(_rate).div(100);
    }
    function _forwardFunds() internal {
        payable(_wallet).transfer(msg.value);
    }
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, 'Contract has no money');
        payable(_wallet).transfer(address(this).balance);
    }
    function getTokenAddress() public view returns (IBEP20) {
        return _token;
    }
    function getWalletAddress() public view returns (address) {
        return _wallet;
    }
    function getRate() public view returns (uint256) {
        return _rate;
    }
    function setRate(uint256 newRate) public onlyOwner {
        _rate = newRate;
    }
    function setAvailableTokens(uint256 amount) public onlyOwner {
        availableTokensILO = amount;
    }
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }
}