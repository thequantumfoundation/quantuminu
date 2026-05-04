// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract QINUVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint64 public immutable start;
    uint64 public immutable cliff;
    uint64 public immutable duration;
    uint256 public immutable allocation;
    uint256 public released;

    event Released(address indexed beneficiary, uint256 amount);

    constructor(address token_, address beneficiary_, uint64 start_, uint64 cliffDuration_, uint64 duration_, uint256 allocation_) {
        require(token_ != address(0), "Vesting: zero token");
        require(beneficiary_ != address(0), "Vesting: zero beneficiary");
        require(duration_ > 0, "Vesting: zero duration");
        require(cliffDuration_ <= duration_, "Vesting: cliff exceeds duration");
        require(allocation_ > 0, "Vesting: zero allocation");

        token = IERC20(token_);
        beneficiary = beneficiary_;
        start = start_;
        cliff = start_ + cliffDuration_;
        duration = duration_;
        allocation = allocation_;
    }

    function release() external {
        uint256 amount = releasableAmount();
        require(amount > 0, "Vesting: nothing releasable");

        released += amount;
        token.safeTransfer(beneficiary, amount);
        emit Released(beneficiary, amount);
    }

    function releasableAmount() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < cliff) {
            return 0;
        }

        if (timestamp >= start + duration) {
            return allocation;
        }

        return allocation * (timestamp - start) / duration;
    }
}