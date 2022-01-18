// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LinearVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event TokenDeposited(address user, address tokenAddr, uint256 amount);
    event TokenMinted(address user, address tokenAddr, address beneficiary, uint256 amount, uint256 time);
    event TokenRedeemed(address beneficiary, uint256 amount);

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

    // current vesting schedule identifier
    uint256 private curScheduleID = 0;
    mapping(uint256 => VestingSchedule) private vestingSchedules;

    // amount of token available to mint that user deposited upfront
    mapping (address => mapping (address => uint256)) private tokenAmountByUsers;

    /**
    * @notice Return current scheduleId.
    * @return scheduleId the vesting schedule identifier
    */
    function getCurScheduleID() external view returns (uint256) {
        return curScheduleID;
    }

    /**
    * @notice Return amount of token that user can mint in the vesting contract.
    * @return scheduleId the vesting schedule identifier
    */
    function getTokenAmountByUser(address tokenAddr) external view returns (uint256) {
        return tokenAmountByUsers[_msgSender()][tokenAddr];
    }

    /**
    * @notice Deposit tokens to vest for a beneficiary.
    * @dev Follow checks-effects-interactions pattern and use reentrancy guard to prevent reentrancy attacks.
    * @param tokenAddr address of token to deposit
    * @param amount amount of token to deposit
    */
    function deposit(address tokenAddr, uint256 amount) public nonReentrant {
        require (tokenAddr != address(0), "LinearVesting: token is zero address");
        require (amount > 0, "LinearVesting: token amount is zero");

        IERC20 token = IERC20(tokenAddr);
        uint256 balanceOfSender = token.balanceOf(_msgSender());
        require (balanceOfSender > amount, "LinearVesting: user has not enough tokens");

        uint256 curAmount = tokenAmountByUsers[_msgSender()][tokenAddr];
        tokenAmountByUsers[_msgSender()][tokenAddr] = curAmount.add(amount);

        emit TokenDeposited(_msgSender(), tokenAddr, amount);
        token.safeTransferFrom(_msgSender(), address(this), amount);
    }

    /**
    * @notice Create a new vesting schedule for a beneficiary.
    * @dev Users can only mint using tokens they deposited upfront.
    * @param tokenAddr address of token to vest
    * @param toAddr address of beneficiary
    * @param amount total amount of tokens to be released at the end of the vesting
    * @param time duration in seconds of the period in which the tokens will vest
    */
    function mint(address tokenAddr, address toAddr, uint256 amount, uint256 time) public {
        require (tokenAddr != address(0), "LinearVesting: token is zero address");
        require (toAddr != address(0), "LinearVesting: mint to the zero address");
        require(
            tokenAmountByUsers[_msgSender()][tokenAddr] >= amount,
            "LinearVesting: cannot mint because user has not enough tokens"
        );
        require (amount > 0, "LinearVesting: token amount is zero");
        require (time > 0, "LinearVesting: vesting duration is zero");

        vestingSchedules[curScheduleID] = VestingSchedule(
            tokenAddr,
            _msgSender(),
            toAddr,
            getCurrentTime(),
            time,
            amount,
            0
        );

        uint256 curAmount = tokenAmountByUsers[_msgSender()][tokenAddr];
        tokenAmountByUsers[_msgSender()][tokenAddr] = curAmount.sub(amount);

        curScheduleID = curScheduleID.add(1);

        emit TokenMinted(_msgSender(), tokenAddr, toAddr, amount, time);
    }

    /**
    * @notice Redeem vested amount of tokens.
    * @dev Follow checks-effects-interactions pattern and use reentrancy guard to prevent reentrancy attacks.
    * @param scheduleId the vesting schedule identifier
    */
    function redeem(uint256 scheduleId) public nonReentrant {
        VestingSchedule storage vestingSchedule = vestingSchedules[scheduleId];
        address beneficiary = vestingSchedule.beneficiary;
        require(
            _msgSender() == beneficiary,
            "LinearVesting: only beneficiary can redeem vested tokens"
        );

        uint256 amount = _getRedeemableAmount(vestingSchedule);
        vestingSchedule.redeemed = vestingSchedule.redeemed.add(amount);

        emit TokenRedeemed(beneficiary, amount);
        IERC20 token = IERC20(vestingSchedule.tokenAddr);
        token.safeTransfer(beneficiary, amount);
    }

    /**
    * @notice Returns the vesting schedule information for a given identifier.
    * @param vestingScheduleId the vesting schedule identifier
    * @return the vesting schedule structure information
    */
    function getVestingSchedule(uint256 vestingScheduleId)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[vestingScheduleId];
    }

    /**
    * @notice Return the redeemable amount of tokens for a vesting schedule.
    * @return the amount of redeemable tokens
    */
    function getRedeemableAmount(uint256 vestingScheduleId)
        public
        view
        returns(uint256){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        return _getRedeemableAmount(vestingSchedule);
    }

    /**
    * @notice Return the redeemable amount of tokens for a vesting schedule.
    * @return the amount of redeemable tokens
    */
    function _getRedeemableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256) {
        if (getCurrentTime() >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.redeemed);
        } else {
            uint256 timeFromStart = getCurrentTime().sub(vestingSchedule.start);
            uint256 vestedAmount = vestingSchedule.amountTotal.mul(timeFromStart).div(vestingSchedule.duration);
            return vestedAmount.sub(vestingSchedule.redeemed);
        }
    }

    /**
    * @dev Return current time.
    * @return block.timestamp
    */
    function getCurrentTime()
        internal
        virtual
        view
        returns(uint256){
        return block.timestamp;
    }
}