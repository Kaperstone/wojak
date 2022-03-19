require("dotenv").config();

// require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-ganache")
require("hardhat-gas-reporter")
require("solidity-coverage")
require("hardhat-contract-sizer")
require("hardhat-preprocessor")
// require("strip-comments")
require("hardhat-watcher");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    }
  },
  defaultNetwork: "localhost",
  networks: {
    goerli: {
      url: "https://rpc.goerli.mudit.blog",
      from: "0xB14Ba501390A89A9E8e6C4E2f8ef95e3124B2119",
      accounts: ["eac02834adc5c16d756af6cacc67abcdadbb2be4080a19e56f61ecb20fd616b8"],
      chainId: 5,
      gasPrice: 20000000000,
      timeout: 2000000000 
    },
    //////////////////////////////////////////////////////////////
    localhost: {
      url: "http://127.0.0.1:8545",
      from: "0xB14Ba501390A89A9E8e6C4E2f8ef95e3124B2119",
      accounts: ["eac02834adc5c16d756af6cacc67abcdadbb2be4080a19e56f61ecb20fd616b8"],
      chainId: 1337,
      gasPrice: 20000000000,
      // timeout: 2000000000,
    },
    hardhat: {
      from: "0xB14Ba501390A89A9E8e6C4E2f8ef95e3124B2119",
      accounts: [
        {
          privateKey: "eac02834adc5c16d756af6cacc67abcdadbb2be4080a19e56f61ecb20fd616b8",
          balance: "1000000000000000000000000000" // 1bil
        },
        {
          privateKey: "79f8042dc8daff41e73fba873976e849c0c5e0503ba9cb43e9b0c52dd885f121",
          balance: "1000000000000000000000000000" // 1bil
        }
      ],
      forking: {
        url: "https://rpc.ftm.tools/"
      },
      chainId: 1337,
      chains: {
        250: {
          hardforkHistory: {
            london: 33509400
          },
        }
      },
      hardfork: "london",
      mining: {
        auto: false,
        interval: [3000, 6000]
      }
    },
    fantom: {
      url: "https://rpc.ftm.tools/",
      from: "0x41227A3F9Df302d6fBDf7dD1b3261928ba789D47",
      accounts: ["6f146b6477982cdd981508660751a122b629cbfc0e903ac2f030e1ea1316bf18"],
      chainId: 250
    },
    //////////////////////////////////////////////////////////////
    testnet: {
      url: "https://data-seed-prebsc-1-s2.binance.org:8545",
      from: "0xB14Ba501390A89A9E8e6C4E2f8ef95e3124B2119",
      accounts: ["eac02834adc5c16d756af6cacc67abcdadbb2be4080a19e56f61ecb20fd616b8"],
      chainId: 97,
      gasPrice: 20000000000,
      timeout: 2000000000 
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      gasPrice: 20000000000,
      chainId: 56
    }
  },
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  },
  watcher: {
    test: {
      tasks: ["test"],
    }
  },
};
