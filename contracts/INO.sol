// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Staking.sol";
import "./Vesting.sol";

/**
 * @title INO
 * @dev Initial NFT Offering contract with staking and vesting functionalities.
 */
contract INO is Initializable, ERC721Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public startTime;
    uint256 public endTime;
    uint256 public price;
    uint256 public maxSupply;
    uint256 public totalMinted;
    uint256 public minStakeAmount;
    string private baseURI;
    bool public isPaused;
    uint256 private nextTokenId;

    Staking public stakingContract;
    Vesting public vestingContract;

    mapping(uint256 => address) private tokenOwner;
    mapping(address => uint256[]) private userTokens;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public userTier;
    mapping(uint256 => uint256) public tierLimits;
    mapping(address => uint256) public userPurchaseAmount;
    mapping(uint256 => uint256) public tierVestingPeriod;

    event INOStarted(uint256 startTime, uint256 endTime, uint256 price, uint256 maxSupply);
    event NFTMinted(address indexed recipient, uint256 tokenId);
    event NFTBought(address indexed buyer, uint256 tokenId);
    event UserWhitelisted(address indexed user, uint256 tier);
    event TierLimitSet(uint256 tier, uint256 limit);
    event VestingPeriodSet(uint256 tier, uint256 vestingPeriod);
    event INOEnded(bool success);
    event INOEmergencyPaused(bool isPaused);

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _stakingContract Address of the staking contract.
     * @param _vestingContract Address of the vesting contract.
     * @param _minStakeAmount Minimum amount required to stake.
    */
    function initialize(
        address _stakingContract,
        address _vestingContract,
        uint256 _minStakeAmount
    ) public initializer {
        __ERC721_init("MyToken", "MTK");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        require(_stakingContract != address(0), "Invalid staking contract address");
        require(_vestingContract != address(0), "Invalid vesting contract address");

        stakingContract = Staking(_stakingContract);
        vestingContract = Vesting(_vestingContract);
        minStakeAmount = _minStakeAmount;

        // vestingContract.setINOContract(address(this));
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
    */
    modifier whenNotPaused() {
        require(!isPaused, "INO is paused");
        _;
    }

    /**
     * @dev Sets the base URI for the token metadata.
     * @param newBaseURI New base URI.
    */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @dev Internal function to return the base URI for the token metadata.
     * @return Base URI string.
    */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Starts the INO with the given parameters.
     * @param _startTime INO start time.
     * @param _endTime INO end time.
     * @param _price Price of each NFT in wei.
     * @param _maxSupply Maximum supply of NFTs.
    */
    function startINO(uint256 _startTime, uint256 _endTime, uint256 _price, uint256 _maxSupply) external onlyOwner {
        require(block.timestamp < startTime || block.timestamp > endTime, "INO already active");
        require(_startTime < _endTime, "Start time must be before end time");
        require(_maxSupply > 0, "Max supply must be greater than zero");

        startTime = _startTime;
        endTime = _endTime;
        price = _price;
        maxSupply = _maxSupply;

        emit INOStarted(_startTime, _endTime, _price, _maxSupply);
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

        whitelisted[user] = false;
        userTier[user] = 0;

        emit UserWhitelisted(user, 0);
    }

    /**
     * @dev Sets the purchase limit for a specific tier.
     * @param tier Tier for which the limit is set.
     * @param limit Purchase limit for the tier.
    */
    function setTierLimit(uint256 tier, uint256 limit) external onlyOwner {
        require(limit<=maxSupply,"Tier limit should be less than or equal to max supply");
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
     * @dev Mints an NFT to a specific recipient.
     * @param recipient Address of the recipient.
    */
    function mintNFT(address recipient) external onlyOwner {
        require(totalMinted < maxSupply, "Max supply reached");

        uint256 tokenId = nextTokenId;
        nextTokenId++;
        totalMinted++;

        _safeMint(recipient, tokenId);
        tokenOwner[tokenId] = recipient;
        userTokens[recipient].push(tokenId);

        emit NFTMinted(recipient, tokenId);
    }

    /**
     * @dev Allows users to buy NFTs during the INO.
     * @param tokenId Token ID of the NFT to buy.
    */
    function buyNFT(uint256 tokenId) external payable nonReentrant whenNotPaused {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "INO not active");
        require(msg.value == price, "Incorrect Ether value");
        require(stakingContract.getStakedAmount(msg.sender) >= minStakeAmount, "Insufficient staked amount");
        require(whitelisted[msg.sender], "User not whitelisted");
        require(userPurchaseAmount[msg.sender] + 1 <= tierLimits[userTier[msg.sender]], "Purchase exceeds tier limit");
        require(tokenOwner[tokenId] == owner(), "NFT not available for sale");

        userPurchaseAmount[msg.sender] += 1;
        tokenOwner[tokenId] = msg.sender;
        userTokens[msg.sender].push(tokenId);

        uint256 vestingPeriod = tierVestingPeriod[userTier[msg.sender]];
        vestingContract.setVestingSchedule(msg.sender, 1, block.timestamp, block.timestamp, block.timestamp + vestingPeriod);

        _transfer(owner(), msg.sender, tokenId);

        emit NFTBought(msg.sender, tokenId);
    }

    /**
     * @dev Withdraws Ether from the contract.
    */
    function withdraw() external onlyOwner nonReentrant {
        require(block.timestamp > endTime, "INO not ended");
        uint256 balance = address(this).balance;
        require(balance > 0, "No Ether to withdraw");
        payable(owner()).transfer(balance);
        emit INOEnded(true);
    }

    /**
     * @dev Pauses or unpauses the INO in case of an emergency.
    */
    function emergencyPauseINO() external onlyOwner {
        isPaused = !isPaused;
        emit INOEmergencyPaused(isPaused);
    }

    /**
     * @dev Refunds Ether to users if the INO fails to reach the max supply.
    */
    function refund() external nonReentrant {
        require(block.timestamp > endTime, "INO not ended");
        require(totalMinted < maxSupply, "Max supply reached, no refunds");

        uint256 amountPurchased = userPurchaseAmount[msg.sender];
        require(amountPurchased > 0, "No NFTs purchased");

        uint256 refundAmount = amountPurchased * price;
        userPurchaseAmount[msg.sender] = 0;

        for (uint256 i = 0; i < amountPurchased; i++) {
            uint256 tokenId = userTokens[msg.sender][i];
            _transfer(msg.sender, owner(), tokenId);
        }

        payable(msg.sender).transfer(refundAmount);
    }

    /**
     * @dev Internal function to handle token transfers and update ownership records.
     * @param from Address transferring the token.
     * @param to Address receiving the token.
     * @param tokenId ID of the token being transferred.
    */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal {
        if (from != address(0)) {
            _removeTokenFromUser(from, tokenId);
        }

        if (to != address(0)) {
            tokenOwner[tokenId] = to;
            userTokens[to].push(tokenId);
        }
    }

    /**
     * @dev Internal function to remove a token from a user's list of owned tokens.
     * @param user Address of the user.
     * @param tokenId ID of the token to remove.
    */
    function _removeTokenFromUser(address user, uint256 tokenId) internal {
        uint256[] storage tokens = userTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    receive() external payable {
        revert("Direct Ether transfer not allowed");
    }

    fallback() external payable {
        revert("Fallback function called");
    }
}