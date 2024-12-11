const hre = require("hardhat");
const launchpadDeploymentModule = require("../ignition/modules/DeploymentModule");

async function main() {
  console.log(`Launchpad Deployment on Sepolia...`);
  console.log(`Please wait for the deployment to complete...`);

  try {
    // Execute the Ignition module
    const {
      proxyAdmin,
      launchpadToken, // Logic contract
      launchpadTokenProxy,
      staking, // Logic contract
      stakingProxy,
      vesting, // Logic contract
      vestingProxy,
      ico, // Logic contract
      icoProxy,
      ino, // Logic contract
      inoProxy,
    } = await hre.ignition.deploy(launchpadDeploymentModule, {
      network: "frontier",
    });

    // Log the addresses
    console.log(`ProxyAdmin deployed to: ${await proxyAdmin.getAddress()}`);
    console.log(`LaunchpadToken Contract deployed to: ${await launchpadToken.getAddress()}`);
    console.log(`LaunchpadToken Proxy Contract deployed to: ${await launchpadTokenProxy.getAddress()}`);
    console.log(`Staking Contract deployed to: ${await staking.getAddress()}`);
    console.log(`Staking Proxy Contract deployed to: ${await stakingProxy.getAddress()}`);
    console.log(`Vesting Contract deployed to: ${await vesting.getAddress()}`);
    console.log(`Vesting Proxy Contract deployed to: ${await vestingProxy.getAddress()}`);
    console.log(`ICO Contract deployed to: ${await ico.getAddress()}`);
    console.log(`ICO Proxy Contract deployed to: ${await icoProxy.getAddress()}`);
    console.log(`INO Contract deployed to: ${await ino.getAddress()}`);
    console.log(`INO Proxy Contract deployed to: ${await inoProxy.getAddress()}`);
  } catch (error) {
    console.error("Error deploying LaunchpadDeploymentModule:", error);
    process.exit(1);
  }
}

main().then(() => process.exit(0));