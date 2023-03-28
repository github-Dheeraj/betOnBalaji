require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    polygon: {
      url: process.env.POLYGON_URL,
      accounts: [process.env.ACCOUNT_KEY],
    }
  },
  solidity: {
    version: "0.8.19",
    viaIR: true,
    settings: {
      optimizer: {
        enabled: true,
        runs: 999999,
      },
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API
    //apiKey: process.env.AVALANCHE_TEST_API
  },
};
