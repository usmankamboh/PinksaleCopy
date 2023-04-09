pragma solidity ^0.8.0;
import "IBEP20 code/Context.sol";
import "IBEP20 code/Ownable.sol";
import "IBEP20 code/Address.sol";
import "IBEP20 code/SafeBEP20.sol";
import "IBEP20 code/ReentrancyGuard.sol";
import "IBEP20 code/SafeMath.sol";
import "IBEP20 code/IBEP20.sol";
contract DemoGreenPresale is ReentrancyGuard, Context, Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    uint256 private constant MIN_LOCKTIME = 1 weeks;
    IBEP20 private _token;
    address private _wallet;
    uint256 private _rate;
    uint256 private _weiRaised;
    uint256 public endILO;
    uint256 public unlockableTime = 0;
    uint public minPurchase;
    uint public maxPurchase;
    uint public availableTokensILO;
    mapping (address => bool) Claimed;
    mapping (address => uint256) valDrop;
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    modifier iloActive() {
        require(endILO > 0 && block.timestamp < endILO && availableTokensILO > 0, "ILO must be active");
        _;
    }
    modifier iloNotActive() {
        require(endILO < block.timestamp, 'ILO should not be active');
        _;
    }
    constructor (uint256 rate, address wallet, IBEP20 token) {
        require(rate > 0, "Pre-Sale: rate is 0");
        require(wallet != address(0), "Pre-Sale: wallet is the zero address");
        require(address(token) != address(0), "Pre-Sale: token is the zero address");
        _rate = rate;
        _wallet = wallet;
        _token = token;
    }
    function lock(uint256 endDate) public onlyOwner {
        require(unlockableTime == 0, "LOCK: this contract already lock tokens");
        require(endDate > block.timestamp + MIN_LOCKTIME, "LOCK: endDate should be more than 1 week later from now");
        unlockableTime = endDate;
    }
    function unlock() public onlyOwner {
        unlockableTime = 0;
    }
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
    receive() external payable {
        if(endILO > 0 && block.timestamp < endILO){
            buyTokens(_msgSender());
        }
        else{
            revert('Pre-Sale is closed');
        }
    }
}