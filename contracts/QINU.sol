// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract QINU is Ownable {
    string public constant name = "Quantum Inu";
    string public constant symbol = "QINU";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000_000 * 1e18;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant REFLECTION_FEE = 100;
    uint256 public constant BURN_FEE = 50;
    uint256 public constant TREASURY_FEE = 50;
    uint256 public constant TOTAL_FEE = REFLECTION_FEE + BURN_FEE + TREASURY_FEE;
    uint256 public constant MAX_REFLECTION_EXCLUSIONS = 100;
    uint256 private constant MAX = type(uint256).max;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 private _totalSupply = INITIAL_SUPPLY;
    uint256 private _reflectedSupply = MAX - (MAX % INITIAL_SUPPLY);
    uint256 private _totalFeesReflected;

    uint256 public maxWallet = INITIAL_SUPPLY / 200;
    uint256 public maxTx = INITIAL_SUPPLY / 500;

    bool public taxEnabled = true;
    bool public limitsEnabled = true;
    bool public reflectionEnabled = true;

    address public treasury;
    address public burnReserve;

    mapping(address => uint256) private _reflectedBalances;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public isLimitExempt;
    mapping(address => bool) public isPair;
    mapping(address => bool) public isExcludedFromReflection;
    address[] private _excludedFromReflection;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed account, uint256 amount);
    event FeeExemptSet(address indexed account, bool isExempt);
    event LimitExemptSet(address indexed account, bool isExempt);
    event MaxWalletSet(uint256 amount);
    event MaxTxSet(uint256 amount);
    event TreasurySet(address indexed treasury);
    event PairSet(address indexed pair, bool isPair);
    event TaxEnabledSet(bool enabled);
    event LimitsEnabledSet(bool enabled);
    event ReflectionEnabledSet(bool enabled);
    event ReactiveBurn(address indexed reserve, uint256 amount);

    struct GenesisAddresses {
        address tippingSocial;
        address stakingRewardsPool;
        address airdrops;
        address memeTreasury;
        address liquidity;
        address ecosystemFund;
        address foundationTreasury;
        address burnReserve;
        address teamVesting;
        address seedVesting;
        address taxTreasury;
        address adminMultisig;
    }

    constructor(GenesisAddresses memory genesis) Ownable(genesis.adminMultisig) {
        _requireNonZero(genesis.tippingSocial);
        _requireNonZero(genesis.stakingRewardsPool);
        _requireNonZero(genesis.airdrops);
        _requireNonZero(genesis.memeTreasury);
        _requireNonZero(genesis.liquidity);
        _requireNonZero(genesis.ecosystemFund);
        _requireNonZero(genesis.foundationTreasury);
        _requireNonZero(genesis.burnReserve);
        _requireNonZero(genesis.teamVesting);
        _requireNonZero(genesis.seedVesting);
        _requireNonZero(genesis.taxTreasury);
        _requireNonZero(genesis.adminMultisig);

        treasury = genesis.taxTreasury;
        burnReserve = genesis.burnReserve;

        _setExcludedFromReflection(BURN_ADDRESS, true);
        _setExcludedFromReflection(address(this), true);
        _setExcludedFromReflection(genesis.burnReserve, true);
        _setExcludedFromReflection(genesis.stakingRewardsPool, true);
        _setExcludedFromReflection(genesis.teamVesting, true);
        _setExcludedFromReflection(genesis.seedVesting, true);
        _setExcludedFromReflection(genesis.taxTreasury, true);

        _setFeeExempt(genesis.adminMultisig, true);
        _setFeeExempt(genesis.taxTreasury, true);
        _setFeeExempt(genesis.foundationTreasury, true);
        _setFeeExempt(genesis.burnReserve, true);
        _setFeeExempt(genesis.stakingRewardsPool, true);
        _setFeeExempt(genesis.teamVesting, true);
        _setFeeExempt(genesis.seedVesting, true);

        _setLimitExempt(genesis.adminMultisig, true);
        _setLimitExempt(genesis.taxTreasury, true);
        _setLimitExempt(genesis.foundationTreasury, true);
        _setLimitExempt(genesis.burnReserve, true);
        _setLimitExempt(genesis.stakingRewardsPool, true);
        _setLimitExempt(genesis.teamVesting, true);
        _setLimitExempt(genesis.seedVesting, true);
        _setLimitExempt(BURN_ADDRESS, true);

        _mintGenesis(genesis.tippingSocial, INITIAL_SUPPLY * 10 / 100);
        _mintGenesis(genesis.stakingRewardsPool, INITIAL_SUPPLY * 20 / 100);
        _mintGenesis(genesis.airdrops, INITIAL_SUPPLY * 10 / 100);
        _mintGenesis(genesis.memeTreasury, INITIAL_SUPPLY * 5 / 100);
        _mintGenesis(genesis.liquidity, INITIAL_SUPPLY * 75 / 1000);
        _mintGenesis(genesis.ecosystemFund, INITIAL_SUPPLY * 75 / 1000);
        _mintGenesis(genesis.foundationTreasury, INITIAL_SUPPLY * 10 / 100);
        _mintGenesis(genesis.burnReserve, INITIAL_SUPPLY * 10 / 100);
        _mintGenesis(genesis.teamVesting, INITIAL_SUPPLY * 10 / 100);
        _mintGenesis(genesis.seedVesting, INITIAL_SUPPLY * 10 / 100);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (isExcludedFromReflection[account]) {
            return _balances[account];
        }

        return tokenFromReflection(_reflectedBalances[account]);
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "QINU: insufficient allowance");

        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }

        _transfer(from, to, amount);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function setFeeExempt(address account, bool exempt) external onlyOwner {
        _setFeeExempt(account, exempt);
    }

    function setLimitExempt(address account, bool exempt) external onlyOwner {
        _setLimitExempt(account, exempt);
    }

    function setMaxWallet(uint256 amount) external onlyOwner {
        require(amount >= INITIAL_SUPPLY / 1000, "QINU: max wallet too low");
        maxWallet = amount;
        emit MaxWalletSet(amount);
    }

    function setMaxTx(uint256 amount) external onlyOwner {
        require(amount >= INITIAL_SUPPLY / 2000, "QINU: max tx too low");
        maxTx = amount;
        emit MaxTxSet(amount);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        _requireNonZero(newTreasury);
        treasury = newTreasury;
        _setFeeExempt(newTreasury, true);
        _setLimitExempt(newTreasury, true);
        emit TreasurySet(newTreasury);
    }

    function setPair(address pair, bool pairStatus) external onlyOwner {
        _requireNonZero(pair);
        isPair[pair] = pairStatus;
        _setLimitExempt(pair, pairStatus);
        emit PairSet(pair, pairStatus);
    }

    function setTaxEnabled(bool enabled) external onlyOwner {
        taxEnabled = enabled;
        emit TaxEnabledSet(enabled);
    }

    function setLimitsEnabled(bool enabled) external onlyOwner {
        limitsEnabled = enabled;
        emit LimitsEnabledSet(enabled);
    }

    function setReflectionEnabled(bool enabled) external onlyOwner {
        reflectionEnabled = enabled;
        emit ReflectionEnabledSet(enabled);
    }

    function excludeFromReflection(address account, bool excluded) external onlyOwner {
        _setExcludedFromReflection(account, excluded);
    }

    function triggerReactiveBurn(uint256 amount) external onlyOwner {
        _burn(burnReserve, amount);
        emit ReactiveBurn(burnReserve, amount);
    }

    function tokenFromReflection(uint256 reflectedAmount) public view returns (uint256) {
        require(reflectedAmount <= _reflectedSupply, "QINU: reflected amount too large");
        return reflectedAmount / _getRate();
    }

    function totalFeesReflected() external view returns (uint256) {
        return _totalFeesReflected;
    }

    function holderTier(address account) external view returns (string memory) {
        uint256 accountBalance = balanceOf(account);

        if (accountBalance >= 100_000_000 * 1e18) {
            return "Quantum Inu";
        }

        if (accountBalance >= 10_000_000 * 1e18) {
            return "Loyal Inu";
        }

        if (accountBalance >= 1_000_000 * 1e18) {
            return "Baby Inu";
        }

        return "Unranked";
    }

    function _transfer(address from, address to, uint256 amount) private {
        _requireNonZero(from);
        _requireNonZero(to);
        require(amount > 0, "QINU: zero amount");

        if (limitsEnabled && !isLimitExempt[from] && !isLimitExempt[to]) {
            require(amount <= maxTx, "QINU: max tx exceeded");
        }

        bool takeFee = taxEnabled && !isFeeExempt[from] && !isFeeExempt[to];

        _tokenTransfer(from, to, amount, takeFee);

        if (limitsEnabled && !isLimitExempt[to] && !isPair[to]) {
            require(balanceOf(to) <= maxWallet, "QINU: max wallet exceeded");
        }
    }

    function _tokenTransfer(address from, address to, uint256 amount, bool takeFee) private {
        uint256 reflectionFee = takeFee && reflectionEnabled ? amount * REFLECTION_FEE / FEE_DENOMINATOR : 0;
        uint256 burnFee = takeFee ? amount * BURN_FEE / FEE_DENOMINATOR : 0;
        uint256 treasuryFee = takeFee ? amount * TREASURY_FEE / FEE_DENOMINATOR : 0;
        uint256 transferAmount = amount - reflectionFee - burnFee - treasuryFee;
        uint256 rate = _getRate();

        _debit(from, amount, rate);
        _credit(to, transferAmount, rate);

        emit Transfer(from, to, transferAmount);

        if (treasuryFee > 0) {
            _credit(treasury, treasuryFee, rate);
            emit Transfer(from, treasury, treasuryFee);
        }

        if (burnFee > 0) {
            _burnFromTransfer(from, burnFee, rate);
        }

        if (reflectionFee > 0) {
            uint256 reflectedFee = reflectionFee * rate;
            _reflectedSupply -= reflectedFee;
            _totalFeesReflected += reflectionFee;
        }
    }

    function _burn(address account, uint256 amount) private {
        _requireNonZero(account);
        require(amount > 0, "QINU: zero burn");

        uint256 rate = _getRate();
        _debit(account, amount, rate);
        _totalSupply -= amount;
        _reflectedSupply -= amount * rate;

        emit Transfer(account, BURN_ADDRESS, amount);
        emit Burn(account, amount);
    }

    function _burnFromTransfer(address from, uint256 amount, uint256 rate) private {
        _totalSupply -= amount;
        _reflectedSupply -= amount * rate;
        emit Transfer(from, BURN_ADDRESS, amount);
        emit Burn(from, amount);
    }

    function _debit(address account, uint256 amount, uint256 rate) private {
        if (isExcludedFromReflection[account]) {
            require(_balances[account] >= amount, "QINU: insufficient balance");
            unchecked {
                _balances[account] -= amount;
            }
        }

        uint256 reflectedAmount = amount * rate;
        require(_reflectedBalances[account] >= reflectedAmount, "QINU: insufficient balance");
        unchecked {
            _reflectedBalances[account] -= reflectedAmount;
        }
    }

    function _credit(address account, uint256 amount, uint256 rate) private {
        if (isExcludedFromReflection[account]) {
            _balances[account] += amount;
        }

        _reflectedBalances[account] += amount * rate;
    }

    function _mintGenesis(address account, uint256 amount) private {
        uint256 rate = _getRate();
        _credit(account, amount, rate);
        emit Transfer(address(0), account, amount);
    }

    function _approve(address tokenOwner, address spender, uint256 amount) private {
        _requireNonZero(tokenOwner);
        _requireNonZero(spender);
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    function _setFeeExempt(address account, bool exempt) private {
        _requireNonZero(account);
        isFeeExempt[account] = exempt;
        emit FeeExemptSet(account, exempt);
    }

    function _setLimitExempt(address account, bool exempt) private {
        _requireNonZero(account);
        isLimitExempt[account] = exempt;
        emit LimitExemptSet(account, exempt);
    }

    function _setExcludedFromReflection(address account, bool excluded) private {
        _requireNonZero(account);

        if (isExcludedFromReflection[account] == excluded) {
            return;
        }

        if (excluded) {
            require(_excludedFromReflection.length < MAX_REFLECTION_EXCLUSIONS, "QINU: too many reflection exclusions");
            _balances[account] = tokenFromReflection(_reflectedBalances[account]);
            isExcludedFromReflection[account] = true;
            _excludedFromReflection.push(account);
            return;
        }

        for (uint256 index = 0; index < _excludedFromReflection.length; index++) {
            if (_excludedFromReflection[index] == account) {
                _excludedFromReflection[index] = _excludedFromReflection[_excludedFromReflection.length - 1];
                _excludedFromReflection.pop();
                break;
            }
        }

        _balances[account] = 0;
        isExcludedFromReflection[account] = false;
    }

    function _getRate() private view returns (uint256) {
        (uint256 reflectedSupply, uint256 tokenSupply) = _getCurrentSupply();
        return reflectedSupply / tokenSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 reflectedSupply = _reflectedSupply;
        uint256 tokenSupply = _totalSupply;

        for (uint256 index = 0; index < _excludedFromReflection.length; index++) {
            address account = _excludedFromReflection[index];

            if (_reflectedBalances[account] > reflectedSupply || _balances[account] > tokenSupply) {
                return (_reflectedSupply, _totalSupply);
            }

            reflectedSupply -= _reflectedBalances[account];
            tokenSupply -= _balances[account];
        }

        if (reflectedSupply < _reflectedSupply / _totalSupply) {
            return (_reflectedSupply, _totalSupply);
        }

        return (reflectedSupply, tokenSupply);
    }

    function _requireNonZero(address account) private pure {
        require(account != address(0), "QINU: zero address");
    }
}