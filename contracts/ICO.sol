// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Staking.sol";
import "./Vesting.sol";

/**
 * @title ICO
 * @dev Initial Coin Offering contract with staking and vesting functionalities.
 */
contract ICO is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public startTime;
    uint256 public endTime;
    uint256 public tokenPrice;
    uint256 public totalTokensForSale;
    uint256 public totalTokensSold;
    uint256 public minStakeAmount;
    uint256 public softCap;
    uint256 public hardCap;
    bool public isPaused;
    uint256[] public tiers;

    Staking public stakingContract;
    Vesting public vestingContract;

    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public userTier;
    mapping(uint256 => uint256) public tierLimits;
    mapping(address => uint256) public userPurchaseAmount;
    mapping(uint256 => uint256) public tierVestingPeriod;
    mapping(uint256 => bool) private tierExists;

    event ICOStarted(uint256 startTime, uint256 endTime, uint256 tokenPrice);
    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokensDistributed(address indexed recipient, uint256 amount);
    event TokensReleased(address indexed recipient, uint256 amount);
    event UserWhitelisted(address indexed user, uint256 tier);
    event TierLimitSet(uint256 tier, uint256 limit);
    event VestingPeriodSet(uint256 tier, uint256 vestingPeriod);
    event ICOEnded(bool success);
    event ICOEmergencyPaused(bool isPaused);

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _totalTokensForSale Total tokens available for sale.
     * @param _stakingContract Address of the staking contract.
     * @param _vestingContract Address of the vesting contract.
     * @param _minStakeAmount Minimum amount required to stake.
     * @param _softCap Minimum amount of tokens to be sold for the ICO to be successful.
     * @param _hardCap Maximum amount of tokens to be sold.
     */
    function initialize(
        uint256 _totalTokensForSale,
        address _stakingContract,
        address _vestingContract,
        uint256 _minStakeAmount,
        uint256 _softCap,
        uint256 _hardCap
    ) public initializer {
        __ERC20_init("MyToken", "MTK");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        require(_stakingContract != address(0), "Invalid staking contract address");
        require(_vestingContract != address(0), "Invalid vesting contract address");
        require(_softCap <= _hardCap, "Soft cap must be less than or equal to hard cap");
        require(_hardCap <= _totalTokensForSale, "Hard cap must be less than or equal to total tokens for sale"); // New check

        totalTokensForSale = _totalTokensForSale;
        _mint(address(this), _totalTokensForSale);
        stakingContract = Staking(_stakingContract);
        vestingContract = Vesting(_vestingContract);
        // vestingContract.setICOContract(address(this));
        minStakeAmount = _minStakeAmount;
        softCap = _softCap;
        hardCap = _hardCap;
    }

    modifier whenNotPaused() {
        require(!isPaused, "ICO is paused");
        _;
    }

    /**
     * @dev Starts the ICO with the given parameters.
     * @param _startTime ICO start time.
     * @param _endTime ICO end time.
     * @param _tokenPrice Price of each token in wei.
     */
    function startICO(uint256 _startTime, uint256 _endTime, uint256 _tokenPrice) external onlyOwner {
        require(_startTime < _endTime, "Start time must be before end time");
        startTime = _startTime;
        endTime = _endTime;
        tokenPrice = _tokenPrice;

        emit ICOStarted(_startTime, _endTime, _tokenPrice);
    }

    /**
     * @dev Whitelists a user and assigns them a tier.
     * @param user Address of the user to be whitelisted.
     * @param tier Tier assigned to the user.
     */
    function whitelistUser(address user, uint256 tier) external onlyOwner {
        require(user != address(0), "Invalid address");
        whitelisted[user] = true;
        userTier[user] = tier;

        emit UserWhitelisted(user, tier);
    }

    /**
    * @dev Removes a user from the whitelist.
    * @param user Address of the user to be removed from the whitelist.
    */
    function removeWhitelistedUser(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(whitelisted[user], "User not whitelisted");

        // Remove the user from the whitelist
        whitelisted[user] = false;
        userTier[user] = 0; // Optionally reset the user's tier

        emit UserWhitelisted(user, 0); // Emit event with tier 0 to indicate removal
    }

    /**
     * @dev Sets the purchase limit for a specific tier.
     * @param tier Tier for which the limit is set.
     * @param limit Purchase limit for the tier.
     */
    function setTierLimit(uint256 tier, uint256 limit) external onlyOwner {
        // Ensure the individual tier limit does not exceed the max supply
        require(limit <= totalTokensForSale, "Tier limit exceeds max supply");

        // Set the limit for the tier
        tierLimits[tier] = limit;
        emit TierLimitSet(tier, limit);
    }

    /**
     * @dev Sets the vesting period for a specific tier.
     * @param tier Tier for which the vesting period is set.
     * @param vestingPeriod Vesting period for the tier.
     */
    function setVestingPeriod(uint256 tier, uint256 vestingPeriod) external onlyOwner {
        tierVestingPeriod[tier] = vestingPeriod;
        emit VestingPeriodSet(tier, vestingPeriod);
    }

    /**
     * @dev Allows users to buy tokens during the ICO.
     * @param amount Amount of tokens to buy.
     */
        function buyTokens(uint256 amount) external payable nonReentrant whenNotPaused {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "ICO not active");
        require(msg.value == amount * tokenPrice, "Incorrect Ether value");
        require(totalTokensSold + amount <= totalTokensForSale, "Not enough tokens left for sale");
        require(totalTokensSold + amount <= hardCap, "Hard cap reached");
        require(stakingContract.getStakedAmount(msg.sender) >= minStakeAmount, "Insufficient staked amount");
        require(whitelisted[msg.sender], "User not whitelisted");
        require(userPurchaseAmount[msg.sender] + amount <= tierLimits[userTier[msg.sender]], "Purchase exceeds tier limit");

        // Update state variables before making external calls
        totalTokensSold += amount;
        userPurchaseAmount[msg.sender] += amount;

        // Transfer tokens to the buyer
        _transfer(address(this), msg.sender, amount);

        // Set vesting schedule for purchased tokens
        uint256 vestingPeriod = tierVestingPeriod[userTier[msg.sender]];
        vestingContract.setVestingSchedule(msg.sender, amount, block.timestamp, block.timestamp, block.timestamp + vestingPeriod);

        emit TokensPurchased(msg.sender, amount);
    }


    /**
    * @dev Distributes tokens to the caller.
    * @param amount Amount of tokens to distribute.
    */
    function distributeTokens(uint256 amount) external onlyOwner {
        require(totalTokensSold + amount <= totalTokensForSale, "Not enough tokens left for distribution");
        _transfer(address(this), msg.sender, amount);
        totalTokensSold += amount;

        emit TokensDistributed(msg.sender, amount);
    }

    /**
    * @dev Allows a user to release their vested tokens.
    * @notice This function should be called by the recipient of the vesting schedule.
    * @param index The index of the vesting schedule for the caller.
    *
    * Emits a {TokensReleased} event indicating the amount of tokens released.
    */
    function releaseVestedTokens(uint256 index) external {
        vestingContract.releaseVestedTokens(index);
        (uint256 amount, , , , ) = vestingContract.getVestingSchedule(msg.sender, index);
        emit TokensReleased(msg.sender, amount);
    }

    /**
     * @dev Withdraws Ether from the contract after the ICO ends.
     */
    function withdraw() external onlyOwner nonReentrant {
        require(block.timestamp > endTime, "ICO not ended");
        if (totalTokensSold >= softCap) {
            uint256 balance = address(this).balance;
            require(balance > 0, "No Ether to withdraw");
            payable(owner()).transfer(balance);
            emit ICOEnded(true);
        } else {
            emit ICOEnded(false);
        }
    }

    /**
     * @dev Pauses or unpauses the ICO in case of an emergency.
     */
    function emergencyPauseICO() external onlyOwner {
        isPaused = !isPaused;
        emit ICOEmergencyPaused(isPaused);
    }

    /**
     * @dev Refunds Ether to users if the ICO fails to reach the soft cap.
     */
    function refund() external nonReentrant {
        require(block.timestamp > endTime, "ICO not ended");
        require(totalTokensSold < softCap, "Soft cap reached, no refunds");

        uint256 amountPurchased = userPurchaseAmount[msg.sender];
        require(amountPurchased > 0, "No tokens purchased");

        uint256 refundAmount = amountPurchased * tokenPrice;
        userPurchaseAmount[msg.sender] = 0;

        // Update totalTokensSold to reflect the refund
        totalTokensSold -= amountPurchased;

        payable(msg.sender).transfer(refundAmount);
    }

    /**
     * @dev Sets the ICO contract address in the Vesting contract.
     * This function can only be called by the owner of the ICO contract.
     * It ensures that the Vesting contract recognizes this ICO contract
     * as an authorized caller for setting vesting schedules.
     */
    function setICOInVesting() external onlyOwner {
        vestingContract.setICOContract(address(this));
    }

    receive() external payable {
        revert("Direct Ether transfer not allowed");
    }

    fallback() external payable {
        revert("Fallback function called");
    }
}