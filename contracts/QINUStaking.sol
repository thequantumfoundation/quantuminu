// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract QINUStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant REWARD_DURATION = 1095 days;
    uint256 public constant PRECISION = 1e18;

    IERC20 public immutable qinu;
    IERC20 public immutable lpToken;
    uint256 public immutable rewardsStart;
    uint256 public immutable rewardsEnd;
    uint256 public immutable totalRewardAllocation;

    uint256 public totalStaked;
    uint256 public totalLPStaked;
    uint256 public accRewardPerShare;
    uint256 public lastRewardTime;
    uint256 public rewardsPaid;
    uint256 public rewardReserve;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public lpStaked;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public pendingStored;

    event Stake(address indexed account, uint256 amount);
    event Unstake(address indexed account, uint256 amount);
    event StakeLP(address indexed account, uint256 amount);
    event UnstakeLP(address indexed account, uint256 amount);
    event ClaimRewards(address indexed account, uint256 amount);
    event RewardsFunded(address indexed funder, uint256 amount);

    constructor(address qinu_, address lpToken_, uint256 totalRewardAllocation_, address adminOwner_) Ownable(adminOwner_) {
        require(qinu_ != address(0), "Staking: zero QINU");
        require(lpToken_ != address(0), "Staking: zero LP");
        require(adminOwner_ != address(0), "Staking: zero admin");
        require(totalRewardAllocation_ > 0, "Staking: zero rewards");

        qinu = IERC20(qinu_);
        lpToken = IERC20(lpToken_);
        totalRewardAllocation = totalRewardAllocation_;
        rewardsStart = block.timestamp;
        rewardsEnd = block.timestamp + REWARD_DURATION;
        lastRewardTime = block.timestamp;
    }

    function fundRewards(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Staking: zero rewards");
        require(rewardReserve + amount <= totalRewardAllocation - rewardsPaid, "Staking: rewards exceed allocation");

        uint256 balanceBefore = qinu.balanceOf(address(this));
        qinu.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = qinu.balanceOf(address(this)) - balanceBefore;
        require(received == amount, "Staking: fee token unsupported");

        rewardReserve += amount;
        emit RewardsFunded(msg.sender, amount);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Staking: zero amount");
        _updatePool();
        _harvestToStored(msg.sender);

        uint256 balanceBefore = qinu.balanceOf(address(this));
        qinu.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = qinu.balanceOf(address(this)) - balanceBefore;
        require(received == amount, "Staking: fee token unsupported");

        staked[msg.sender] += amount;
        totalStaked += amount;
        rewardDebt[msg.sender] = _combinedStake(msg.sender) * accRewardPerShare / PRECISION;

        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) public nonReentrant {
        require(amount > 0, "Staking: zero amount");
        require(staked[msg.sender] >= amount, "Staking: insufficient stake");
        _updatePool();
        _harvestToStored(msg.sender);

        staked[msg.sender] -= amount;
        totalStaked -= amount;
        rewardDebt[msg.sender] = _combinedStake(msg.sender) * accRewardPerShare / PRECISION;

        qinu.safeTransfer(msg.sender, amount);
        emit Unstake(msg.sender, amount);
    }

    function stakeLP(uint256 amount) external nonReentrant {
        require(amount > 0, "Staking: zero amount");
        _updatePool();
        _harvestToStored(msg.sender);

        uint256 balanceBefore = lpToken.balanceOf(address(this));
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = lpToken.balanceOf(address(this)) - balanceBefore;
        require(received == amount, "Staking: fee LP unsupported");

        lpStaked[msg.sender] += amount;
        totalLPStaked += amount;
        rewardDebt[msg.sender] = _combinedStake(msg.sender) * accRewardPerShare / PRECISION;

        emit StakeLP(msg.sender, amount);
    }

    function unstakeLP(uint256 amount) public nonReentrant {
        require(amount > 0, "Staking: zero amount");
        require(lpStaked[msg.sender] >= amount, "Staking: insufficient LP stake");
        _updatePool();
        _harvestToStored(msg.sender);

        lpStaked[msg.sender] -= amount;
        totalLPStaked -= amount;
        rewardDebt[msg.sender] = _combinedStake(msg.sender) * accRewardPerShare / PRECISION;

        lpToken.safeTransfer(msg.sender, amount);
        emit UnstakeLP(msg.sender, amount);
    }

    function claimRewards() public nonReentrant {
        _updatePool();
        _harvestToStored(msg.sender);

        uint256 reward = pendingStored[msg.sender];
        require(reward > 0, "Staking: no rewards");
        require(reward <= rewardReserve, "Staking: insufficient reward reserve");

        pendingStored[msg.sender] = 0;
        rewardDebt[msg.sender] = _combinedStake(msg.sender) * accRewardPerShare / PRECISION;
        rewardsPaid += reward;
        rewardReserve -= reward;

        qinu.safeTransfer(msg.sender, reward);
        emit ClaimRewards(msg.sender, reward);
    }

    function exit() external {
        uint256 qinuAmount = staked[msg.sender];
        uint256 lpAmount = lpStaked[msg.sender];

        if (qinuAmount > 0) {
            unstake(qinuAmount);
        }

        if (lpAmount > 0) {
            unstakeLP(lpAmount);
        }

        if (pendingRewards(msg.sender) > 0) {
            claimRewards();
        }
    }

    function pendingRewards(address account) public view returns (uint256) {
        uint256 projectedAccRewardPerShare = accRewardPerShare;
        uint256 combinedTotal = totalStaked + totalLPStaked;

        if (block.timestamp > lastRewardTime && combinedTotal > 0) {
            uint256 reward = _rewardBetween(lastRewardTime, _min(block.timestamp, rewardsEnd));
            projectedAccRewardPerShare += reward * PRECISION / combinedTotal;
        }

        uint256 accumulated = _combinedStake(account) * projectedAccRewardPerShare / PRECISION;
        return pendingStored[account] + accumulated - rewardDebt[account];
    }

    function rewardRateAt(uint256 timestamp) external view returns (uint256) {
        return _rewardRateAt(timestamp);
    }

    function _updatePool() private {
        uint256 currentTime = _min(block.timestamp, rewardsEnd);

        if (currentTime <= lastRewardTime) {
            return;
        }

        uint256 combinedTotal = totalStaked + totalLPStaked;

        if (combinedTotal == 0) {
            lastRewardTime = currentTime;
            return;
        }

        uint256 reward = _rewardBetween(lastRewardTime, currentTime);
        accRewardPerShare += reward * PRECISION / combinedTotal;
        lastRewardTime = currentTime;
    }

    function _harvestToStored(address account) private {
        uint256 accumulated = _combinedStake(account) * accRewardPerShare / PRECISION;
        uint256 pending = accumulated - rewardDebt[account];

        if (pending > 0) {
            pendingStored[account] += pending;
        }
    }

    function _rewardBetween(uint256 from, uint256 to) private view returns (uint256) {
        if (to <= from || from >= rewardsEnd) {
            return 0;
        }

        uint256 boundedTo = _min(to, rewardsEnd);
        uint256 elapsedFrom = from - rewardsStart;
        uint256 elapsedTo = boundedTo - rewardsStart;
        uint256 duration = rewardsEnd - rewardsStart;

        uint256 area = ((elapsedTo - elapsedFrom) * duration) - ((elapsedTo * elapsedTo - elapsedFrom * elapsedFrom) / 2);
        return (2 * totalRewardAllocation * area) / (duration * duration);
    }

    function _rewardRateAt(uint256 timestamp) private view returns (uint256) {
        if (timestamp < rewardsStart || timestamp >= rewardsEnd) {
            return 0;
        }

        uint256 duration = rewardsEnd - rewardsStart;
        uint256 elapsed = timestamp - rewardsStart;
        return 2 * totalRewardAllocation * (duration - elapsed) / (duration * duration);
    }

    function _combinedStake(address account) private view returns (uint256) {
        return staked[account] + lpStaked[account];
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}