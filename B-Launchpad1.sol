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
import "IBEP20 code/IUniswapV2Factory.sol";
    contract Launchpad is ReentrancyGuard, Context, Ownable {
    AggregatorV3Interface internal priceFeed;
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    mapping (address => uint256) private _rOwned;
    mapping(address => uint256) private _balances;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000 * 10**7 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    string private _name = "";
    string private _symbol = "";
    uint8 private _decimals = 9;
    uint256 public _taxFee = 5;
    uint256 private _previousTaxFee = _taxFee;
    uint256 public _liquidityFee = 5;
    uint256 private _previousLiquidityFee = _liquidityFee;
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    uint256 public _maxTxAmount = 5000000 * 10**7 * 10**9;
    uint256 private numTokensSellToAddToLiquidity = 500000 * 10**7 * 10**9;
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approve(address indexed from, address indexed to, uint256 value);
    event SwapAndLiquify(uint256 tokensSwapped,uint256 ethReceived,uint256 tokensIntoLiqudity);
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
    modifier iloActive() {
        require(endTime > 0 && block.timestamp < endTime , "Pre-Sale: ILO must be active");
        //require(endTime > 0 && block.timestamp < endTime && availableTokens > 0, "Pre-Sale: ILO must be active");
        _;
    }
    modifier iloNotActive() {
        require(endTime < block.timestamp, 'Pre-Sale:  should not be active');
        _;
    }
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
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
         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        // set the rest of the contract variables
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }
    receive() external payable {
        if(endTime > 0 && block.timestamp < endTime){
            buyTokens(_msgSender());
        } else {
            revert("Pre-Sale is closed");
        }
    }
     //StartSale
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
    function lockTokens(address _tokenAddress,uint256 _amount,uint256 _unlockTime,bool _feesInBnb) external payable returns (uint256 _id) {
        require(_amount > 0, 'Tokens amount must be greater than 0');
        require(_unlockTime < 10000000000, 'Unix timestamp must be in seconds, not milliseconds');
        require(_unlockTime > block.timestamp, 'Unlock time must be in future');
        require(!_feesInBnb || msg.value > bnbFee, 'BNB fee not provided');
        require(IBEP20(_tokenAddress).approve(address(this), _amount), 'Failed to approve tokens');
        require(IBEP20(_tokenAddress).transferFrom(msg.sender, address(this), _amount), 'Failed to transfer tokens to locker');
        uint256 lockAmount = _amount;
        if (_feesInBnb) {
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
    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
   function setAvailableTokens(uint256 amount) public onlyOwner {
       availableTokens = amount;
   }
    function weiRaised() public view returns (uint256) {
       return _weiRaised;
    }
/**
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }
    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }
    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }
    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is not excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }
    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
    }
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
     //to recieve ETH from uniswapV2Router when swaping
   // receive() external payable {}
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }
    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }
    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }
    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }
    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(10**2);
    }
    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0) return;   
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _taxFee = 0;
        _liquidityFee = 0;
    }
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP0: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approve(owner, spender, amount);
    }
    function balanceOf(address account) public  view returns (uint256) {
        return _balances[account];
    }

    function _transfer(address from,address to,uint256 amount) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        if(contractTokenBalance >= _maxTxAmount){
            contractTokenBalance = _maxTxAmount;
        }
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (overMinTokenBalance && !inSwapAndLiquify && from != uniswapV2Pair && swapAndLiquifyEnabled) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
    }
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;
        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered
        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);
        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this),tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),/*0x0000000000000000000000000000000000000001,
            block.timestamp
        );
    }
    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();   
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
      } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
           _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }       
        if(!takeFee)
            restoreAllFee();
    }
    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }*/
}