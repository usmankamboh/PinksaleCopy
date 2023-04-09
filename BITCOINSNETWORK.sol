// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
contract BitcoinNetworks is Context, IBEP20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    // mapping (address => uint256) private _mining;

    mapping (address => mapping (address => uint256)) private _allowances;
    
    mapping (address => uint256) private _lastRewardTime;
    mapping (address => bool) private _isExcluded;
    
    uint256 private _totalSupply = 21000000 * 10**8;
    uint8 private _decimals = 8;
    string private _symbol = "BTCN";
    string private _name = "Bitcoin Networks";
    address public deployer;
    uint256 public genisisBlock;
    uint256 public genisisBlockNumber;
    uint256 private _lastBlockTime;
    uint256 private _lastBlock;
    uint256 private _circulatingSupply = 1000000 * 10**8;
    uint256 private _mining = 0;
    uint256 private _blockReward = 200 * 10**8;
    // uint256 private _halvingInterval = 400;
    uint private _blockTime = 600; // time
    uint256 public maxTxAmount = 50000 * 10**8; // maximum 50000 btcn can be transferred in 1 transaction
    uint256 private _totalBlockRewards = 0; 
    uint256 private _totalBlocksMined = 1;
    bool private _enableMine = true;
    event blockMined (address _by, uint256 _time, uint256 _blockNumber);
    constructor()  {
        genisisBlock = block.timestamp;
        genisisBlockNumber = block.number;
        _lastBlock = genisisBlockNumber;
        _lastBlockTime = genisisBlock;
        _lastRewardTime[_msgSender()] = _totalBlocksMined;
        _balances[_msgSender()] = _circulatingSupply;
        _mining = _circulatingSupply;
        emit Transfer(address(0), _msgSender(), _circulatingSupply);
    }

    /**
   * @dev Returns the bep token owner.
   */
    function getOwner() public view returns (address) {
    return owner();
  }

    /**
   * @dev Returns the token decimals.
   */
    function decimals() public view returns (uint8) {
    return _decimals;
  }

    /**
   * @dev Returns the token symbol.
   */
    function symbol() public view returns (string memory) {
    return _symbol;
  }

    /**
  * @dev Returns the token name.
  */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
   * @dev See {BEP20-totalSupply}.
   */
    function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

    /**
   * @dev See {BEP20-balanceOf}.
   */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account])
            return _balances[account];
        return _balances[account]+_calcReward(account);
    }

    /**
   * @dev See {BEP20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
      _transfer(_msgSender(), recipient, amount);
      return true;
    }

    /**
   * @dev See {BEP20-allowance}.
   */
    function allowance(address owner, address spender) public view override returns (uint256) {
    return _allowances[owner][spender];
  }

    /**
   * @dev See {BEP20-approve}.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
   * @dev See {BEP20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {BEP20};
   *
   * Requirements:
   * - `sender` and `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   * - the caller must have allowance for `sender`'s tokens of at least
   * `amount`.
   */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

    /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

    /**
   * @dev Moves tokens `amount` from `sender` to `recipient`.
   *
   * This is internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `sender` cannot be the zero address.
   * - `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   */
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        if (sender != owner())
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        
        
        /* CONSIDER THIS WITH OTHER FIRS */
        if (_isExcluded[sender]) {
            if (!_isExcluded[recipient]) _mining = _mining + amount;
        }else {
            if (_isExcluded[recipient]) _mining = _mining - amount;
        }
        if (_balances[recipient] <= 0) _lastRewardTime[recipient] = _totalBlocksMined;
        
        // First check if sender claimed reward  already
        if (_lastRewardTime[sender] < _totalBlocksMined && !_isExcluded[sender]) {
            uint256 _reward = _calcReward(sender);
            _balances[sender] = _balances[sender]+_reward;
            _lastRewardTime[sender] = _totalBlocksMined;
        }
        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        if (_lastRewardTime[recipient] < _totalBlocksMined && !_isExcluded[recipient]) {
            uint256 _reward = _calcReward(recipient);
            _balances[recipient] = _balances[recipient]+_reward;
            _lastRewardTime[recipient] = _totalBlocksMined;
        }
        mine(sender);
      
        emit Transfer(sender, recipient, amount);
    }
    
    function _calcReward (address account) private view returns (uint256) {
        if (_lastRewardTime[account] == _totalBlocksMined)
            return 0;
        uint256 _reward = 0;
        uint256 _prevBlockReward = 0;
        uint256 _lastReward = _lastRewardTime[account];
        
        if (_lastReward >= 1 && _lastReward < 17280) {
            _prevBlockReward = 200 * 10**18;
            if (_totalBlocksMined > 17280) {
                _reward = ((17280 - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining);
                _lastReward = 17280;
            }else {
                _reward = ((_totalBlocksMined - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining);
                _lastReward = _totalBlocksMined;
            }
        }
        if (_lastReward >= 17280 && _lastReward < 69120) {
            _prevBlockReward = 100 * 10**18;
            if (_totalBlocksMined > 69120) {
                _reward = _reward + (((69120 - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining));
                _lastReward = 69120;
            }else {
                _reward = _reward +  (((_totalBlocksMined - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining));
                _lastReward = _totalBlocksMined;
            }
        }
        if (_lastReward >= 69120 && _lastReward < 207360) {
            _prevBlockReward = 50 * 10**18;
            if (_totalBlocksMined > 207360) {
                _reward = _reward +  (((207360 - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining));
                _lastReward = 207360;
            }else {
                _reward = _reward +  (((_totalBlocksMined - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining));
                _lastReward = _totalBlocksMined;
            }
        }
        if (_lastReward >= 207360 && _lastReward < 385280) {
            _prevBlockReward = 25 * 10**18;
            if (_totalBlocksMined >= 385280) {
                _reward = _reward +  (((385280 - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining));
                _lastReward = 385280;
            }else {
                _reward = _reward +  (((_totalBlocksMined - _lastReward) * _prevBlockReward).mul(_balances[account]).div(_mining));
                _lastReward = _totalBlocksMined;
            }
        }
        
        return _reward;
    }
    
    /**
   * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
   *
   * This is internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `owner` cannot be the zero address.
   * - `spender` cannot be the zero address.
   */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
    
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function mine(address account) private {
        if (!_enableMine) return; // Don't use require as it will fail transfers if mining is not enabled
        if (block.number < _lastBlock+_blockTime) return;
        _totalBlockRewards = _totalBlockRewards+_blockReward;
        _circulatingSupply = _circulatingSupply+_blockReward;
        _mining = _mining+_blockReward;
        _lastBlock = block.number;
        _lastBlockTime = block.timestamp;
        _totalBlocksMined++;
        
        emit blockMined (account, _lastBlockTime, _lastBlock);
        
        // if (_lastBlock < _halvingInterval+genisisBlockNumber) return;
        if (_totalBlocksMined == 17280) {
            _blockTime = 400;
            _blockReward = _blockReward.div(2); // block reward halves
        }else if (_totalBlocksMined == 69120) {
            _blockTime = 300;
            _blockReward = _blockReward.div(2); // block reward halves
        }else if (_totalBlocksMined == 207360) {
            _blockTime = 200;
            _blockReward = _blockReward.div(2); // block reward halves
        }
        
        if (_totalBlocksMined >= 385280-1) _enableMine = false; // end mining
    }
    
    function exlude (address account) external onlyOwner {
         _exclude(account);
    }
    function include (address account) external onlyOwner {
        _include(account);
    }
    
    function _exclude (address account) private {
        _isExcluded[account] = true;
        _mining = _mining - _balances[account];
    }
    function _include (address account) private {
        _isExcluded[account] = false;
        _mining = _mining+ _balances[account];
    }
    
    function isExcluded (address account) public view returns (bool) {
        return _isExcluded[account];
    }
    function circulatingSupply() public view returns (uint256) {
        return _circulatingSupply;
    }
    function totalBlockRewards() public view returns (uint256) {
        return _totalBlockRewards;
    }
    function totalBlocksMined() public view returns (uint256) {
        return _totalBlocksMined;
    }
    function enableMine() public view returns (bool) {
        return _enableMine;
    }
    function lastBlockTime() public view returns (uint256) {
        return _lastBlockTime;
    }
    function lastBlock() public view returns (uint256) {
        return _lastBlock;
    }
    function blockReward() public view returns (uint256) {
        return _blockReward;
    }

    function miningReward() public view returns (uint256) {
        return _mining;
    }
    function blockTime() public view returns (uint) {
        return _blockTime;
    }
}
