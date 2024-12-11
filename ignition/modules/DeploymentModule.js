const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const deploymentModule = buildModule("DeploymentModule", (m) => {
  // Retrieve the first account to be used as the owner for ProxyAdmin
  const proxyAdminOwner = m.getAccount(0);

  // Deploy the ProxyAdmin contract
  const proxyAdmin = m.contract("ProxyAdmin", [proxyAdminOwner]);

  // Deploy contracts and their proxies
  const launchpadToken = m.contract("LaunchpadToken");
  const launchpadTokenProxy = createProxy(m, launchpadToken, proxyAdmin, "LaunchpadTokenProxy");

  const staking = m.contract("Staking");
  const stakingProxy = createProxy(m, staking, proxyAdmin, "StakingProxy");

  const vesting = m.contract("Vesting");
  const vestingProxy = createProxy(m, vesting, proxyAdmin, "VestingProxy");

  const ico = m.contract("ICO");
  const icoProxy = createProxy(m, ico, proxyAdmin, "ICOProxy");

  // Initialize the ICO contract through the proxy
  m.call(ico, "initialize", [
    1000000,   // Total tokens for sale
    stakingProxy,
    vestingProxy,
    100,       // Minimum staking amount
    500000,    // Soft cap
    1000000    // Hard cap
  ], { from: proxyAdminOwner, gasLimit: 50000000000 });
  console.log("came 1");
  const ino = m.contract("INO");
  const inoProxy = createProxy(m, ino, proxyAdmin, "INOProxy");
console.log("came 2");
  // Initialize the INO contract through the proxy
  m.call(ino, "initialize", [
    stakingProxy,
    vestingProxy,
    100        // Minimum staking amount for INO
  ], { from: proxyAdminOwner, gasLimit: 50000000000 });
  console.log("came 3");
  // Set the ICO contract address in the Vesting contract
  m.call(vesting, "setICOContract", [icoProxy], { from: proxyAdminOwner, gasLimit: 50000000000 });
  console.log("came 4");
  // Return deployed contract instances
  return {
    proxyAdmin,
    launchpadToken,
    launchpadTokenProxy,
    staking,
    stakingProxy,
    vesting,
    vestingProxy,
    ico,
    icoProxy,
    ino,
    inoProxy
  };
});

// Helper function to create a TransparentUpgradeableProxy
function createProxy(m, contract, proxyAdmin, id) {
  return m.contract("TransparentUpgradeableProxy", [contract, proxyAdmin, "0x"], { id });
}

module.exports = deploymentModule;