// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title LaunchpadToken
 * @dev ERC20 Token with minting functionality, owned by a single address.
 */
contract LaunchpadToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    /**
     * @dev Initializes the contract with the given parameters.
     * @param initialSupply Initial supply of tokens to mint.
     */
    function initialize(uint256 initialSupply) public initializer {
        __ERC20_init("LaunchpadToken", "LPT");
        __Ownable_init(msg.sender);
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mints new tokens to a specified address. Only the owner can call this function.
     * @param to Address to receive the newly minted tokens.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}