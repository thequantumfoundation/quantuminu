// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract QINULPLock {
    using SafeERC20 for IERC20;

    IERC20 public immutable lpToken;
    address public immutable beneficiary;
    uint64 public immutable unlockTime;
    bool public released;

    event Released(address indexed beneficiary, uint256 amount);

    constructor(address lpToken_, address beneficiary_, uint64 unlockTime_) {
        require(lpToken_ != address(0), "LPLock: zero LP token");
        require(beneficiary_ != address(0), "LPLock: zero beneficiary");
        require(unlockTime_ > block.timestamp, "LPLock: unlock in past");

        lpToken = IERC20(lpToken_);
        beneficiary = beneficiary_;
        unlockTime = unlockTime_;
    }

    function release() external {
        require(block.timestamp >= unlockTime, "LPLock: locked");
        require(!released, "LPLock: released");

        released = true;
        uint256 amount = lpToken.balanceOf(address(this));
        require(amount > 0, "LPLock: no LP tokens");

        lpToken.safeTransfer(beneficiary, amount);
        emit Released(beneficiary, amount);
    }
}