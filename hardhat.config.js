require("@nomicfoundation/hardhat-toolbox");
require('@nomicfoundation/hardhat-ignition');
require("@nomicfoundation/hardhat-ignition-ethers");
const INFURA_PROJECT_ID = "341e4922a3e34deaa80cebb4c4b1fd51"; // Replace with your Infura project ID
const priv_key = "99B3C12287537E38C90A9219D4CB074A89A16E9CDB20BF85728EBD97C343E342";
const PRIVATE_KEY = "0a4fa1a67953a43c704e9e9e8db60c7f8d6d454cf80698c52a77fc7ddd6ce84d"; // Replace with your wallet's private key
const CUSTOM_PRIVATE_KEY = "99b3c12287537e38c90a9219d4cb074a89a16e9cdb20bf85728ebd97c343e342";
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {},
    frontier: {
      url: "http://127.0.0.1:9944",
      chainId: 42,
      accounts: ['0x5fb92d6e98884f76de468fa3f6278f8807c48bebc13595d45af5bdc4da702133'],
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_PROJECT_ID}`,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    moonbeam: {
      url: `http://127.0.0.1:9944`,
      chainId:1281,
      accounts: ['0x5fb92d6e98884f76de468fa3f6278f8807c48bebc13595d45af5bdc4da702133'],
    }
  }
};
