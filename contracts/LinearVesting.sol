// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract LinearVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        // address of token to vest
        address tokenAddr;
        // benefactor of tokens
        address benefactor;
        // beneficiary of tokens after they are released
        address beneficiary;
        // start time of the vesting period
        uint256 start;
        // duration of the vesting period in seconds
        uint256 duration;
        // total amount of tokens to be redeemed at the end of the vesting
        uint256 amountTotal;
        // amount of tokens redeemed
        uint256 redeemed;
    }

    uint256 private curScheduleID = 0;
    mapping(uint256 => VestingSchedule) private vestingSchedules;

    mapping (address => mapping (address => uint256)) private tokenAmountByUsers;

    function deposit(address tokenAddr, uint256 amount) public {
        require (tokenAddr != address(0), "LinearVesting: token is zero address");
        require (amount > 0, "LinearVesting: token amount is zero");

        IERC20 token = IERC20(tokenAddr);
        uint256 balanceOfSender = token.balanceOf(msg.sender);
        require (balanceOfSender > amount, "LinearVesting: user has not enough tokens");

        tokenAmountByUsers[msg.sender][tokenAddr] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
    * @notice Create a new vesting schedule for a beneficiary.
    * @param tokenAddr address of token to vest
    * @param toAddr address of beneficiary
    * @param amount total amount of tokens to be released at the end of the vesting
    * @param time duration in seconds of the period in which the tokens will vest
    */
    function mint(address tokenAddr, address toAddr, uint256 amount, uint256 time) public nonReentrant {
        require(
            tokenAmountByUsers[msg.sender][tokenAddr] >= amount,
            "LinearVesting: cannot mint because user has not enough tokens"
        );
        require (tokenAddr != address(0), "LinearVesting: token is zero address");
        require (toAddr != address(0), "LinearVesting: mint to the zero address");
        require (amount > 0, "LinearVesting: token amount is zero");
        require (time > 0, "LinearVesting: vesting duration is zero");

        vestingSchedules[curScheduleID] = VestingSchedule(
            tokenAddr,
            msg.sender,
            toAddr,
            block.timestamp,
            time,
            amount,
            0
        );

        uint256 curAmount = tokenAmountByUsers[msg.sender][tokenAddr];
        tokenAmountByUsers[msg.sender][tokenAddr] = curAmount.sub(amount);

        curScheduleID.add(1);
    }

    /**
    * @notice Redeem vested amount of tokens.
    * @param scheduleId the vesting schedule identifier
    */
    function redeem(uint256 scheduleId) public nonReentrant {
        VestingSchedule storage vestingSchedule = vestingSchedules[scheduleId];
        require(
            msg.sender == vestingSchedule.beneficiary,
            "LinearVesting: only beneficiary can release vested tokens"
        );
        IERC20 token = IERC20(vestingSchedule.tokenAddr);
        uint256 amount = _getRedeemableAmount(vestingSchedule);
        vestingSchedule.redeemed = vestingSchedule.redeemed.add(amount);

        token.safeTransfer(vestingSchedule.beneficiary, amount);
    }

    /**
    * @dev Get the redeemable amount of tokens for a vesting schedule.
    * @return the amount of redeemable tokens
    */
    function _getRedeemableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        if (block.timestamp >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.redeemed);
        } else {
            uint256 timeFromStart = block.timestamp.sub(vestingSchedule.start);
            uint256 vestedAmount = vestingSchedule.amountTotal.mul(timeFromStart).div(vestingSchedule.duration);
            return vestedAmount.sub(vestingSchedule.redeemed);
        }
    }

}