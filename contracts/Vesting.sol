// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/** 
 * @title Vesting
 * @dev Vesting contract for ERC20 tokens with cliff and vesting periods.
 */
contract Vesting is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    address public icoContract;
    address public inoContract;

    struct VestingSchedule {
        uint256 amount;
        uint256 startTime;
        uint256 cliffTime;
        uint256 endTime;
        uint256 releasedAmount;
    }

    mapping(address => VestingSchedule[]) public vestingSchedules;

    event VestingScheduleSet(address indexed recipient, uint256 amount, uint256 startTime, uint256 cliffTime, uint256 endTime);
    event VestedTokensReleased(address indexed recipient, uint256 amount);
    event VestingScheduleRevoked(address indexed recipient, uint256 amount);

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _token Address of the ERC20 token.
     */
    function initialize(IERC20 _token) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        token = _token;
    }

    modifier onlyExistingSchedule(address recipient, uint256 index) {
        require(index < vestingSchedules[recipient].length, "No vesting schedule found");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == icoContract || msg.sender == owner() || msg.sender == inoContract, "Caller is not authorized");
        _;
    }

    /**
     * @dev Sets the ICO contract address.
     * @param _icoContract Address of the ICO contract.
     */
    function setICOContract(address _icoContract) external onlyOwner {
        icoContract = _icoContract;
    }

     /**
     * @dev Sets the INO contract address.
     * @param _inoContract Address of the INO contract.
     */
    function setINOContract(address _inoContract) external onlyOwner {
        inoContract = _inoContract;
    }

    /**
     * @dev Sets a vesting schedule for a recipient and returns the index of the schedule.
     * @param recipient Address of the recipient.
     * @param amount Amount of tokens to be vested.
     * @param startTime Start time of the vesting schedule.
     * @param cliffTime Cliff time of the vesting schedule.
     * @param endTime End time of the vesting schedule.
     * @return index Index of the newly created vesting schedule.
     */
    function setVestingSchedule(
        address recipient,
        uint256 amount,
        uint256 startTime,
        uint256 cliffTime,
        uint256 endTime
    ) external onlyAuthorized whenNotPaused returns (uint256 index) {
        require(amount > 0, "Amount must be greater than 0");
        require(startTime < endTime, "Start time must be before end time");
        // Allow startTime to be equal to cliffTime
        require(startTime <= cliffTime, "Start time must be before or equal to cliff time");
        require(cliffTime < endTime, "Cliff time must be before end time");
        require(token.balanceOf(address(this)) >= amount, "Insufficient tokens in contract");

        vestingSchedules[recipient].push(VestingSchedule({
            amount: amount,
            startTime: startTime,
            cliffTime: cliffTime,
            endTime: endTime,
            releasedAmount: 0
        }));

        index = vestingSchedules[recipient].length - 1;
        emit VestingScheduleSet(recipient, amount, startTime, cliffTime, endTime);
    }

    /**
    * @dev Releases vested tokens for the sender.
    * @param index Index of the vesting schedule.
    */
    function releaseVestedTokens(uint256 index) external nonReentrant whenNotPaused onlyExistingSchedule(msg.sender, index) {
        VestingSchedule storage schedule = vestingSchedules[msg.sender][index];
        require(block.timestamp >= schedule.cliffTime, "Cliff period not reached");

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        token.safeTransfer(msg.sender, releasableAmount);

        emit VestedTokensReleased(msg.sender, releasableAmount);
    }

    /**
     * @dev Revokes a vesting schedule for a recipient.
     * @param recipient Address of the recipient.
     * @param index Index of the vesting schedule.
     */
    function revokeVestingSchedule(address recipient, uint256 index) external onlyOwner whenNotPaused onlyExistingSchedule(recipient, index) {
        VestingSchedule storage schedule = vestingSchedules[recipient][index];
        uint256 unreleasedAmount = schedule.amount - schedule.releasedAmount;
        delete vestingSchedules[recipient][index];

        emit VestingScheduleRevoked(recipient, unreleasedAmount);
    }

    /**
    * @dev Returns the vesting schedule for a recipient.
    * @param recipient Address of the recipient.
    * @param index Index of the vesting schedule.
    * @return amount Amount of tokens to be vested.
    * @return startTime Start time of the vesting schedule.
    * @return cliffTime Cliff time of the vesting schedule.
    * @return endTime End time of the vesting schedule.
    * @return releasedAmount Amount of tokens already released.
    */
    function getVestingSchedule(address recipient, uint256 index) external view onlyExistingSchedule(recipient, index) returns (uint256 amount, uint256 startTime, uint256 cliffTime, uint256 endTime, uint256 releasedAmount) {
        VestingSchedule storage schedule = vestingSchedules[recipient][index];
        require(schedule.amount > 0, "Vesting schedule does not exist");

        return (schedule.amount, schedule.startTime, schedule.cliffTime, schedule.endTime, schedule.releasedAmount);
    }

    /**
     * @dev Returns the remaining time for a vesting schedule.
     * @param recipient Address of the recipient.
     * @param index Index of the vesting schedule.
     * @return Remaining time in seconds.
     */
    function getRemainingTime(address recipient, uint256 index) external view onlyExistingSchedule(recipient, index) returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[recipient][index];
        if (block.timestamp >= schedule.endTime) {
            return 0;
        } else {
            return schedule.endTime - block.timestamp;
        }
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Calculates the vested amount for a vesting schedule.
     * @param schedule Vesting schedule.
     * @return Vested amount.
     */
    function _calculateVestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.cliffTime) {
            return 0;
        } else if (block.timestamp >= schedule.endTime) {
            return schedule.amount;
        } else {
            uint256 duration = schedule.endTime - schedule.startTime;
            uint256 timeElapsed = block.timestamp - schedule.startTime;
            return (schedule.amount * timeElapsed) / duration;
        }
    }

    /**
     * @dev Allows the owner to fund the vesting contract with tokens.
     * @param amount Amount of tokens to transfer to the contract.
     */
    function fundContract(uint256 amount) external onlyOwner {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}