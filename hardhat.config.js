require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ganache");
require("hardhat-gas-reporter");
require("solidity-coverage");

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
  solidity: "0.8.6",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000,
    },
  },
  defaultNetwork: "localhost",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      from: "0x358e1db2e05fb645486d93424d4c18a2621e5d54c7765c84ab15aa9281599ecf",
      gasPrice: 12000000,
      gasMultiplier: 12000000,
      accounts: [
        "0x358e1db2e05fb645486d93424d4c18a2621e5d54c7765c84ab15aa9281599ecf",
        "0xfedb62c7b035970c95a08b406a2f5eb3ff8727a59878998bf4feffd3e2b0e6fd",
        "0x709629f066725c42b4df017dbc6c401226a3d6fc887cb212db567fecfb89bb91",
        "0x85d191ef0114e3fceeb20f9a799f08af5f459bde48522bbe69eeaabdafaf0ce8",
        "0x8518231233ef3d80546cb4275883a37c79238108758f1862b7831b3a4b8352ee",
        "0x96bdf16f943ba6f86f8d03ef49bdb6782ec5ae2a4f67df9ec495a51d27c68052",
        "0x25c2fadfbf41877cae7ae08caa779e1f84fa1ee39636098977b336f701967137",
        "0x77990f32d020809bb78c62557feff1c8945a01e84f3a6915b9490397f2029639",
        "0x74c88c4c5db69ce1c85ac392f11bd359a67d2836f5c47d599d37e5d10e26d8fe",
        "0x82d0af453492dc5c6264346ead94fcd0cfd494abeb27a0f6c88229bf9c12d024"
      ]
    },
  },
};
