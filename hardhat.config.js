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
        runs: 999,
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
      timeout: 2000000000,
    },
    hardhat: {
      from: "0xB14Ba501390A89A9E8e6C4E2f8ef95e3124B2119",
      accounts: [
        {
          privateKey: "eac02834adc5c16d756af6cacc67abcdadbb2be4080a19e56f61ecb20fd616b8",
          balance: "500000000000000000000000000" // 500mil :)
        }
      ],
      forking: {
        url: "https://apis-sj.ankr.com/c2e370321311467885a63632ca3118d2/e7af78440c6d117d158147628814aae7/fantom/full/main"
      },
      chainId: 1337,
      mining: {
        auto: true
      }
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
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [':ERC20$'],
  },
  watcher: {
    test: {
      tasks: ["test"],
    }
  },
};
