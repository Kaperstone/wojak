const hre = require("hardhat");

async function main() {
  const Token = await hre.ethers.getContractFactory("Token/Wojak.sol").deploy();
  await Token.deployed();
  console.log("Token deployed to:", Token.address);

  const Staking = await hre.ethers.getContractFactory("Staking/Boomer.sol").deploy();
  await Staking.deployed();
  console.log("Staking deployed to:", Staking.address);

  const Treasury = await hre.ethers.getContractFactory("Treasury/Bunker.sol").deploy();
  await Treasury.deployed();
  console.log("Treasury deployed to:", Treasury.address);

  const Treasury = await hre.ethers.getContractFactory("Bridge/GoldenRog.sol").deploy();
  await Treasury.deployed();
  console.log("Treasury deployed to:", Treasury.address);

  const Bonds = await hre.ethers.getContractFactory("Bonds/Chad.sol").deploy();
  await Bonds.deployed();
  console.log("Bonds deployed to:", Bonds.address);
}

main().then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
