require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-contract-sizer")
require('@typechain/hardhat')

const {
  CORE_RPC,
  CORE_DEPLOY_KEY,
  CORESCAN_API_KEY
} = require("./env.json")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.info(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545/',
      timeout: 120000,
      accounts: {
        // mnemonic: "near cruel jar space pond motion evidence shed coach more drama pyramid",
        mnemonic: "test test test test test test test test test test test junk",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 10,
        passphrase: ""
      }
    },
    hardhat: {
      allowUnlimitedContractSize: true
    },
    core: {
      url: CORE_RPC,
      gasPrice: 20000000000,
      chainId: 5,
      accounts: [CORE_DEPLOY_KEY]
    }
  },
  etherscan: {
    apiKey: {
      core: CORESCAN_API_KEY,
    },
    customChains: [
      {
        network: "core",
        chainId: 5,
        urls: {
          apiURL: "https://api-goerli.etherscan.io/api",
          browserURL: "https://goerli.etherscan.io",
        },
      },
    ]
  },
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10
      }
    }
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
}
