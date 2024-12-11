// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./ICO.sol";
import "./INO.sol";
import "./Staking.sol";
import "./Token.sol";
import "./Vesting.sol";

// Contract to manage the ProxyAdmin
contract ProxyAdminManager {
    ProxyAdmin public proxyAdmin;

    constructor() {
        proxyAdmin = new ProxyAdmin(msg.sender);
    }
}

// Contract to deploy ICO proxy
contract ICOProxy {
    TransparentUpgradeableProxy public icoProxy;
    ProxyAdminManager public admin;

    constructor(address _admin) {
        admin = ProxyAdminManager(_admin);
    }

    function deployICO(
        address _logic,
        uint256 _totalTokensForSale,
        address _stakingContract,
        address _vestingContract,
        uint256 _minStakeAmount,
        uint256 _softCap,
        uint256 _hardCap
    ) external {
        bytes memory data = abi.encodeWithSelector(
            ICO(payable(_logic)).initialize.selector, // Explicitly mark as payable
            _totalTokensForSale,
            _stakingContract,
            _vestingContract,
            _minStakeAmount,
            _softCap,
            _hardCap
        );
        icoProxy = new TransparentUpgradeableProxy(_logic, address(admin.proxyAdmin()), data);
    }
}

// Contract to deploy INO proxy
contract INOProxy {
    TransparentUpgradeableProxy public inoProxy;
    ProxyAdminManager public admin;

    constructor(address _admin) {
        admin = ProxyAdminManager(_admin);
    }

    function deployINO(
        address _logic,
        address _stakingContract,
        address _vestingContract,
        uint256 _minStakeAmount
    ) external {
        bytes memory data = abi.encodeWithSelector(
            INO(payable(_logic)).initialize.selector, // Explicitly mark as payable
            _stakingContract,
            _vestingContract,
            _minStakeAmount
        );
        inoProxy = new TransparentUpgradeableProxy(_logic, address(admin.proxyAdmin()), data);
    }
}

// Contract to deploy Staking proxy
contract StakingProxy {
    TransparentUpgradeableProxy public stakingProxy;
    ProxyAdminManager public admin;

    constructor(address _admin) {
        admin = ProxyAdminManager(_admin);
    }

    function deployStaking(
        address _logic,
        address _nativeToken,
        uint256 _penaltyRate
    ) external {
        bytes memory data = abi.encodeWithSelector(
            Staking(_logic).initialize.selector,
            _nativeToken,
            _penaltyRate
        );
        stakingProxy = new TransparentUpgradeableProxy(_logic, address(admin.proxyAdmin()), data);
    }
}

// Contract to deploy LaunchpadToken proxy
contract LaunchpadTokenProxy {
    TransparentUpgradeableProxy public launchpadTokenProxy;
    ProxyAdminManager public admin;

    constructor(address _admin) {
        admin = ProxyAdminManager(_admin);
    }

    function deployLaunchpadToken(
        address _logic,
        uint256 _initialSupply
    ) external {
        bytes memory data = abi.encodeWithSelector(
            LaunchpadToken(_logic).initialize.selector,
            _initialSupply
        );
        launchpadTokenProxy = new TransparentUpgradeableProxy(_logic, address(admin.proxyAdmin()), data);
    }
}

// Contract to deploy Vesting proxy
contract VestingProxy {
    TransparentUpgradeableProxy public vestingProxy;
    ProxyAdminManager public admin;

    constructor(address _admin) {
        admin = ProxyAdminManager(_admin);
    }

    function deployVesting(
        address _logic,
        address _token
    ) external {
        bytes memory data = abi.encodeWithSelector(
            Vesting(_logic).initialize.selector,
            _token
        );
        vestingProxy = new TransparentUpgradeableProxy(_logic, address(admin.proxyAdmin()), data);
    }
}