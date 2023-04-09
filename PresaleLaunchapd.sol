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
contract Launchpad is ReentrancyGuard, Context, Ownable {
    AggregatorV3Interface internal priceFeed;
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    uint256 public _rate;
    uint256 public  startTime; // start sale time
    uint256 public  endTime; // end sale time
    uint256 public minPurchase;
    uint256 public maxPurchase;
    uint256 public availableTokens;
     uint256 public softCap;
    uint256 public hardCap;
    uint256 public poolPercent;
    uint256 private _price;
    uint256 private _weiRaised;
    IBEP20 private _token;
    address private _wallet;
    address private bnbAddress = 0xa92BdA9ED4f93F3FE6Db2b57fAA0b40e2810D976;
    mapping (address => bool) Claimed;
    mapping (address => uint256) CoinPaid;
    mapping (address => uint256) TokenBought;
    mapping (address => uint256) valDrop;
    bool public presaleResult;
    // PancakeSwap(Uniswap) Router and Pair Address
    IUniswapV2Router02 public immutable uniswapV2Router;
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event DropSent(address[]  receiver, uint256[]  amount);
    event AirdropClaimed(address receiver, uint256 amount);
    event WhitelistSetted(address[] recipient, uint256[] amount);
    event SwapETHForBNB(uint256 amountIn, address[] path);
    event SwapBNBForETH(uint256 amount, address[] path);
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
        if(endTime > 0 && block.timestamp < endTime){
            buyTokens(_msgSender());
        } else {
            revert("Pre-Sale is closed");
        }
    }
    /**
    * Returns the latest price
    */
    function getLatestPrice() public view returns (int) {
        (uint80 roundID, int price,uint startedAt,uint timeStamp,uint80 answeredInRound) = priceFeed.latestRoundData();
        return price;
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
    //Start Pre-Sale
    function startSale(uint endDate, uint _minPurchase, uint _maxPurchase, uint _availableTokens, uint256 _softCap, uint256 _hardCap, uint256 _poolPercent) external onlyOwner iloNotActive() {
        require(endDate > block.timestamp, 'Pre-Sale: duration should be > 0');
        require(_availableTokens > 0 && _availableTokens <= _token.totalSupply(), 'Pre-Sale: availableTokens should be > 0 and <= totalSupply');
        require(_poolPercent >= 0 && _poolPercent < _token.totalSupply(), 'Pre-Sale: poolPercent should be >= 0 and < totalSupply');
        require(_minPurchase > 0, 'Pre-Sale: _minPurchase should > 0');
        startTime = block.timestamp;
        endTime = endDate;
        poolPercent = _poolPercent;
        availableTokens = _availableTokens.div(_availableTokens.mul(_poolPercent).div(10**2));
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
    function getEndTimestamp() public view returns (uint256) {
        require(endTime > 0, "Error: Presale has finished already");   
        return endTime;
    }
    function getStartTimestamp() public view returns (uint256) {
        require(startTime > 0, "Error: Presale has not started yet");   
        return startTime;
    }
    //Pre-Sale
    function buyTokens(address beneficiary) public nonReentrant iloActive payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        _weiRaised = _weiRaised.add(weiAmount);
        availableTokens = availableTokens - tokens;
        Claimed[beneficiary] = false;
        CoinPaid[beneficiary] = weiAmount;
        TokenBought[beneficiary] = tokens;
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
        _forwardFunds();
    }
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(beneficiary != address(0), "Pre-Sale: beneficiary is the zero address");
        require(weiAmount != 0, "Pre-Sale: weiAmount is 0");
        require(weiAmount >= minPurchase, 'have to send at least: minPurchase');
        require(weiAmount <= maxPurchase, 'have to send max: maxPurchase');
        this;
    }
    function claimToken(address beneficiary) public iloNotActive() {
      require(Claimed[beneficiary] == false, "Pre-Sale: You did claim your tokens!");
      Claimed[beneficiary] = true;
      _processPurchase(beneficiary, TokenBought[beneficiary]);
    }
    function claimRefund(address beneficiary) public iloNotActive() {
       if(presaleResult == false) {
          require(Claimed[beneficiary] == false, "Pre-Sale: Only member can refund coins!");
          Claimed[beneficiary] = true;
          payable(beneficiary).transfer(CoinPaid[beneficiary]);
      }
    }
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.transfer(beneficiary, tokenAmount);
    }
    function _forwardFunds() internal {
        swapETHForBNB(msg.value);
    }
    function _prepareRefund(address _walletAddress) internal {
        uint256 bnbBalance = IBEP20(bnbAddress).balanceOf(_walletAddress);
        swapBNBForETH(bnbBalance);
    }
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        _deliverTokens(beneficiary, tokenAmount);
    }
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(_rate).div(1000000);
    }
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, 'Pre-Sale: Contract has no money');
        payable(_wallet).transfer(address(this).balance);
    }
    function getToken() public view returns (IBEP20) {
        return _token;
    }
    function getWallet() public view returns (address) {
        return _wallet;
    }
    function getRate() public view returns (uint256) {
        return _rate;
    }
    function setRate(uint256 newRate) public onlyOwner {
        _rate = newRate;
    }
    function setAvailableTokens(uint256 amount) public onlyOwner {
        availableTokens = amount;
    }
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }
    modifier iloActive() {
        require(endTime > 0 && block.timestamp < endTime && availableTokens > 0, "Pre-Sale: ILO must be active");
        _;
    }
    modifier iloNotActive() {
        require(endTime < block.timestamp, 'Pre-Sale:  should not be active');
        _;
    }
}