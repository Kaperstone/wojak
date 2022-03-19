const hardhat = require("hardhat");

async function main() {
  let list = [
    "Boomer",
    "Chad",
    "Keeper",
    "Locker",
    "Manager",
    "Treasury",
    "Wojak",
    "Zoomer",
    "BIFISoy",
    "BOOSoy",
    "CREDITSoy",
    "CRVSoy",
    "SCREAMSoy",
    "SPELLSoy",
    "TAROTSoy",
    "USDCSoy",
    "WFTMSoy"
  ]
  
  console.log("-=-=-=-=-=-=-=-=-=-=-=-")
  for(let x = 0; x < list.length; x++) {
    const Contract = await hardhat.ethers.getContractFactory(list[x])
    const contract = await Contract.deploy()
    await contract.deployed()
    
    console.log(list[x] + " deployed: " + contract.address)
    console.log("chainId: " + contract.provider.network.chainId + "\thost: " + contract.provider.connection.url)
    console.log("tx.hash:\t"+contract.deployTransaction.hash)
    console.log("Signer address:\t" + contract.signer.address)
    console.log("-=-=-=-=-=-=-=-=-=-=-=-")
    // console.log(contract)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });