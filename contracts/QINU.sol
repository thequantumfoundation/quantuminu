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
    uint256 public constant REACTIVE_BURN_THRESHOLD = 10_000_000_000 * 1e18;
    uint256 public constant REACTIVE_BURN_AMOUNT = 1_000_000 * 1e18;
    uint256 public constant MAX_REFLECTION_EXCLUSIONS = 100;
    uint256 private constant MAX = type(uint256).max;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 private _totalSupply = INITIAL_SUPPLY;
    uint256 private _reflectedSupply = MAX - (MAX % INITIAL_SUPPLY);
    uint256 private _totalFeesReflected;

    uint256 public maxWallet = INITIAL_SUPPLY / 200;
    uint256 public maxTx = INITIAL_SUPPLY / 500;
    uint256 public reactiveBurnVolume;
    uint256 public totalReactiveBurned;

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
    mapping(address => bool) public isReactiveBurnExempt;
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
    event TaxEnabledSet(bool enabled);
    event LimitsEnabledSet(bool enabled);
    event ReflectionEnabledSet(bool enabled);
    event ReactiveBurnExemptSet(address indexed account, bool isExempt);
    event ReactiveBurn(address indexed reserve, uint256 amount);
    event GenesisAllocation(string indexed category, address indexed recipient, uint256 amount);

    constructor(
        address tippingSocial,
        address stakingRewardsPool,
        address airdrops,
        address memeTreasury,
        address liquidity,
        address ecosystemFund,
        address foundationTreasury,
        address burnReserve_,
        address team,
        address publicSale,
        address taxTreasury,
        address adminOwner
    ) Ownable(adminOwner) {
        _requireNonZero(tippingSocial);
        _requireNonZero(stakingRewardsPool);
        _requireNonZero(airdrops);
        _requireNonZero(memeTreasury);
        _requireNonZero(liquidity);
        _requireNonZero(ecosystemFund);
        _requireNonZero(foundationTreasury);
        _requireNonZero(burnReserve_);
        _requireNonZero(team);
        _requireNonZero(publicSale);
        _requireNonZero(taxTreasury);
        _requireNonZero(adminOwner);

        treasury = taxTreasury;
        burnReserve = burnReserve_;

        _setExcludedFromReflection(BURN_ADDRESS, true);
        _setExcludedFromReflection(address(this), true);
        _setExcludedFromReflection(burnReserve_, true);
        _setExcludedFromReflection(stakingRewardsPool, true);
        _setExcludedFromReflection(team, true);
        _setExcludedFromReflection(publicSale, true);
        _setExcludedFromReflection(taxTreasury, true);

        _setFeeExempt(adminOwner, true);
        _setFeeExempt(stakingRewardsPool, true);
        _setFeeExempt(foundationTreasury, true);
        _setFeeExempt(taxTreasury, true);
        _setFeeExempt(burnReserve_, true);
        _setFeeExempt(team, true);
        _setFeeExempt(publicSale, true);

        _setLimitExempt(adminOwner, true);
        _setLimitExempt(stakingRewardsPool, true);
        _setLimitExempt(foundationTreasury, true);
        _setLimitExempt(taxTreasury, true);
        _setLimitExempt(burnReserve_, true);
        _setLimitExempt(team, true);
        _setLimitExempt(publicSale, true);
        _setLimitExempt(BURN_ADDRESS, true);

        _setReactiveBurnExempt(adminOwner, true);
        _setReactiveBurnExempt(tippingSocial, true);
        _setReactiveBurnExempt(stakingRewardsPool, true);
        _setReactiveBurnExempt(airdrops, true);
        _setReactiveBurnExempt(memeTreasury, true);
        _setReactiveBurnExempt(liquidity, true);
        _setReactiveBurnExempt(ecosystemFund, true);
        _setReactiveBurnExempt(foundationTreasury, true);
        _setReactiveBurnExempt(burnReserve_, true);
        _setReactiveBurnExempt(team, true);
        _setReactiveBurnExempt(publicSale, true);
        _setReactiveBurnExempt(taxTreasury, true);
        _setReactiveBurnExempt(address(this), true);
        _setReactiveBurnExempt(BURN_ADDRESS, true);

        _mintGenesisAllocation("Tipping & Social Rewards", tippingSocial, INITIAL_SUPPLY * 10 / 100);
        _mintGenesisAllocation("Staking & Yield Incentives", stakingRewardsPool, INITIAL_SUPPLY * 20 / 100);
        _mintGenesisAllocation("Community Airdrops & Campaigns", airdrops, INITIAL_SUPPLY * 10 / 100);
        _mintGenesisAllocation("Meme Treasury", memeTreasury, INITIAL_SUPPLY * 5 / 100);
        _mintGenesisAllocation("Liquidity Pools", liquidity, INITIAL_SUPPLY * 75 / 1000);
        _mintGenesisAllocation("Ecosystem Growth Fund", ecosystemFund, INITIAL_SUPPLY * 75 / 1000);
        _mintGenesisAllocation("Treasury (Quantum Foundation)", foundationTreasury, INITIAL_SUPPLY * 10 / 100);
        _mintGenesisAllocation("Burn Reserve", burnReserve_, INITIAL_SUPPLY * 10 / 100);
        _mintGenesisAllocation("Core Team & Builders", team, INITIAL_SUPPLY * 10 / 100);
        _mintGenesisAllocation("Seed / Public Sale", publicSale, INITIAL_SUPPLY * 10 / 100);
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

    function setReactiveBurnExempt(address account, bool exempt) external onlyOwner {
        _setReactiveBurnExempt(account, exempt);
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
        totalReactiveBurned += amount;
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

        if (limitsEnabled && !isLimitExempt[to]) {
            require(balanceOf(to) <= maxWallet, "QINU: max wallet exceeded");
        }

        _trackReactiveBurn(from, to, amount);
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

    function _trackReactiveBurn(address from, address to, uint256 amount) private {
        if (isReactiveBurnExempt[from] || isReactiveBurnExempt[to]) {
            return;
        }

        uint256 pendingVolume = reactiveBurnVolume + amount;
        uint256 burnCount = pendingVolume / REACTIVE_BURN_THRESHOLD;
        reactiveBurnVolume = pendingVolume % REACTIVE_BURN_THRESHOLD;

        if (burnCount == 0) {
            return;
        }

        uint256 pendingBurnAmount = burnCount * REACTIVE_BURN_AMOUNT;
        uint256 reserveBalance = balanceOf(burnReserve);
        uint256 burnAmount = pendingBurnAmount > reserveBalance ? reserveBalance : pendingBurnAmount;

        if (burnAmount == 0) {
            return;
        }

        totalReactiveBurned += burnAmount;
        _burn(burnReserve, burnAmount);
        emit ReactiveBurn(burnReserve, burnAmount);
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

    function _mintGenesisAllocation(string memory category, address account, uint256 amount) private {
        _mintGenesis(account, amount);
        emit GenesisAllocation(category, account, amount);
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

    function _setReactiveBurnExempt(address account, bool exempt) private {
        _requireNonZero(account);
        isReactiveBurnExempt[account] = exempt;
        emit ReactiveBurnExemptSet(account, exempt);
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