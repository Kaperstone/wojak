const hre = require("hardhat");

async function main() {
  const Bonds = await hre.ethers.getContractFactory("Chad")
  const bonds = await Bonds.deploy()
                await bonds.deployed()
  console.log("Bonds deployed to:\t", bonds.address);

  const SoyFarms = await hre.ethers.getContractFactory("SoyFarms")
  const soyfarms = await SoyFarms.deploy()
                   await soyfarms.deployed()
  console.log("SoyFarms deployed to:\t", soyfarms.address);

  const Staking = await hre.ethers.getContractFactory("Boomer")
  const staking = await Staking.deploy()
                  await staking.deployed()
  console.log("Staking deployed to:\t", staking.address);

  const Token = await hre.ethers.getContractFactory("Wojak")
  const token = await Token.deploy()
                await token.deployed()
  console.log("Token deployed to:\t", token.address);

  const Treasury = await hre.ethers.getContractFactory("Treasury")
  const treasury = await Treasury.deploy()
                   await treasury.deployed()
  console.log("Treasury deployed to:\t", treasury.address);

  const Strategy = await hre.ethers.getContractFactory("TStrategy")
  const strategy = await Strategy.deploy()
                   await strategy.deployed()
  console.log("TStrategy deployed to:\t", strategy.address);

  const UpKeep = await hre.ethers.getContractFactory("Keeper")
  const keeper = await UpKeep.deploy()
                 await keeper.deployed()
  console.log("Keeper deployed to:\t", keeper.address);
}

main().then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
