// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title Staking
 * @dev Staking contract with tiered rewards and penalties for early withdrawal.
 */
contract Staking is Initializable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public nativeToken;
    uint256 private totalStaked; // Made private for security
    uint256 public penaltyRate;
    uint256 public tierCount; // Track the number of tiers

    struct StakeInfo {
        uint256 amount;
        uint256 rewardRate;
        uint256 lockTime;
        uint256 lastUpdate;
        uint256 rewardAmount;
    }

    mapping(address => StakeInfo) private stakers; // Made private for privacy
    mapping(uint256 => uint256) public tierRewardRates;
    mapping(uint256 => uint256) public tierLockPeriods;
    mapping(uint256 => uint256) public tierStakingRequirements;

    event TokensStaked(address indexed user, uint256 amount, uint256 tier);
    event TokensUnstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ContractPaused();
    event ContractUnpaused();
    event PenaltyRateSet(uint256 penaltyRate);
    event TierRewardRateSet(uint256 tier, uint256 rewardRate);
    event TierLockPeriodSet(uint256 tier, uint256 lockPeriod);
    event TierStakingRequirementSet(uint256 tier, uint256 stakingRequirement);

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _nativeToken Address of the native token.
     * @param _penaltyRate Penalty rate for early withdrawal.
     * @param _tierRewardRates Array of reward rates for each tier.
     * @param _tierLockPeriods Array of lock periods for each tier.
     * @param _tierStakingRequirements Array of staking requirements for each tier.
     */
    function initialize(
        IERC20 _nativeToken,
        uint256 _penaltyRate,
        uint256[] memory _tierRewardRates,
        uint256[] memory _tierLockPeriods,
        uint256[] memory _tierStakingRequirements
    ) public initializer {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        nativeToken = _nativeToken;
        penaltyRate = _penaltyRate;
        tierCount = _tierRewardRates.length; // Set the tier count

        for (uint256 i = 0; i < tierCount; i++) {
            tierRewardRates[i] = _tierRewardRates[i];
            tierLockPeriods[i] = _tierLockPeriods[i];
            tierStakingRequirements[i] = _tierStakingRequirements[i];
        }

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Allows the owner to update tier parameters.
     */
    function setTierParameters(
        uint256[] memory _tierRewardRates,
        uint256[] memory _tierLockPeriods,
        uint256[] memory _tierStakingRequirements
    ) external onlyOwner {
        require(_tierRewardRates.length == tierCount, "Invalid reward rates length");
        require(_tierLockPeriods.length == tierCount, "Invalid lock periods length");
        require(_tierStakingRequirements.length == tierCount, "Invalid staking requirements length");

        for (uint256 i = 0; i < tierCount; i++) {
            tierRewardRates[i] = _tierRewardRates[i];
            tierLockPeriods[i] = _tierLockPeriods[i];
            tierStakingRequirements[i] = _tierStakingRequirements[i];
        }
    }

    /**
    * @dev Allows users to stake tokens.
    * @param amount Amount of tokens to stake.
    */
    function stakeTokens(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(amount >= tierStakingRequirements[0], "Amount below minimum for 0th tier");

        uint256 tier = 0;
        for (uint256 i = 0; i < tierCount; i++) {
            if (amount >= tierStakingRequirements[i]) {
                tier = i;
            }
        }

        nativeToken.safeTransferFrom(msg.sender, address(this), amount);

        _updateReward(msg.sender);

        StakeInfo storage stakeInfo = stakers[msg.sender];
        stakeInfo.amount += amount;
        stakeInfo.rewardRate = tierRewardRates[tier];
        stakeInfo.lockTime = block.timestamp + tierLockPeriods[tier];
        stakeInfo.lastUpdate = block.timestamp;

        totalStaked += amount;

        emit TokensStaked(msg.sender, amount, tier);
    }

    /**
     * @dev Allows users to unstake tokens.
     * @param amount Amount of tokens to unstake.
     */
    function unstakeTokens(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        StakeInfo storage stakeInfo = stakers[msg.sender];
        require(stakeInfo.amount >= amount, "Insufficient staked amount");

        _updateReward(msg.sender);

        uint256 penalty = 0;
        if (block.timestamp < stakeInfo.lockTime) {
            penalty = (amount * penaltyRate) / 100;
            if (penalty >= amount) {
                penalty = amount;
            }
            nativeToken.safeTransfer(owner(), penalty);
        }

        uint256 amountAfterPenalty = amount - penalty;
        stakeInfo.amount -= amount;
        totalStaked -= amountAfterPenalty;

        nativeToken.safeTransfer(msg.sender, amountAfterPenalty);

        emit TokensUnstaked(msg.sender, amountAfterPenalty);
    }

    /**
     * @dev Allows users to claim their rewards.
     */
    function claimRewards() public nonReentrant whenNotPaused {
        _updateReward(msg.sender);

        StakeInfo storage stakeInfo = stakers[msg.sender];
        uint256 reward = stakeInfo.rewardAmount;
        stakeInfo.rewardAmount = 0;

        if (reward > 0) {
            nativeToken.safeTransfer(msg.sender, reward);
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    /**
     * @dev Calculates the reward for a user.
     * @param user Address of the user.
     * @return Reward amount.
     */
    function calculateReward(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakers[user];
        return stakeInfo.amount * stakeInfo.rewardRate * (block.timestamp - stakeInfo.lastUpdate) / 1e18;
    }

    /**
     * @dev Returns the staked amount for a specific user.
     * @param user Address of the user.
     * @return Staked amount.
     */
    function getStakedAmount(address user) external view returns (uint256) {
        return stakers[user].amount;
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused();
    }

    /**
    * @dev Returns the total staked amount.
    * @return Total staked amount.
    */
    function totalStakedAmount() external view onlyOwner returns (uint256) {
        return totalStaked;
    }

    /**
     * @dev Allows users to withdraw their staked tokens in case of an emergency.
     */
    function emergencyWithdraw() external whenPaused nonReentrant {
        StakeInfo storage stakeInfo = stakers[msg.sender];
        uint256 staked = stakeInfo.amount;
        require(staked > 0, "No staked amount to withdraw");

        stakeInfo.amount = 0;
        totalStaked -= staked;

        nativeToken.safeTransfer(msg.sender, staked);
    }

    /**
     * @dev Updates the reward for a user.
     * @param user Address of the user.
     */
    function _updateReward(address user) internal {
        StakeInfo storage stakeInfo = stakers[user];
        if (stakeInfo.amount > 0) {
            stakeInfo.rewardAmount += calculateReward(user);
        }
        stakeInfo.lastUpdate = block.timestamp;
    }

     /**
     * @dev Returns the staking information for the caller.
     * @return amount The amount of tokens staked by the caller.
     * @return rewardRate The reward rate applicable to the caller's stake.
     * @return lockTime The lock time until which the caller's stake is locked.
     * @return lastUpdate The last time the reward was updated for the caller.
     * @return rewardAmount The accumulated reward amount for the caller.
     */
    function getMyStakeInfo() external view returns (uint256 amount, uint256 rewardRate, uint256 lockTime, uint256 lastUpdate, uint256 rewardAmount) {
        StakeInfo storage stakeInfo = stakers[msg.sender];
        return (
            stakeInfo.amount,
            stakeInfo.rewardRate,
            stakeInfo.lockTime,
            stakeInfo.lastUpdate,
            stakeInfo.rewardAmount
        );
    }
}