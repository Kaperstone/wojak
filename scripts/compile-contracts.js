const hre = require("hardhat");

async function main() {
  const Bonds = await hre.ethers.getContractFactory("Bonds/Chad.sol").deploy();
  await Bonds.deployed();
  console.log("Bonds deployed to:", Bonds.address);

  const SoyFarms = await hre.ethers.getContractFactory("SoyFarms/SoyFarms.sol").deploy();
  await SoyFarms.deployed();
  console.log("SoyFarms deployed to:", SoyFarms.address);

  const Staking = await hre.ethers.getContractFactory("Staking/Boomer.sol").deploy();
  await Staking.deployed();
  console.log("Staking deployed to:", Staking.address);

  const Token = await hre.ethers.getContractFactory("Token/Wojak.sol").deploy();
  await Token.deployed();
  console.log("Token deployed to:", Token.address);

  const Treasury = await hre.ethers.getContractFactory("Treasury/Treasury.sol").deploy();
  await Treasury.deployed();
  console.log("Treasury deployed to:", Treasury.address);

  const Strategy = await hre.ethers.getContractFactory("Treasury/bridge/Strategy.sol").deploy();
  await Strategy.deployed();
  console.log("Treasury Strategy deployed to:", Strategy.address);

  const UpKeep = await hre.ethers.getContractFactory("UpKeep/Keeper.sol").deploy();
  await UpKeep.deployed();
  console.log("Keeper deployed to:", UpKeep.address);
}

main().then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
