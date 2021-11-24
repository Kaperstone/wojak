const hre = require("hardhat");

/*
 *
 *  Wojak token
 * 
 *  Contracts
 *    > Token
 *    > Staking
 *    > Treasury
 *    > Oven
 *    > Bonds
 *    > Vault
 * 
 *  Stream
 *    Token fill> Treasury
 *    Token fill> Liquidity
 *    Treasury profits.send> Oven (Buyback Burn)
 *    Staking read> Token circ supply
 *    Bonds mint> Token
 *    Bonds fill> Treasury
 *    Bonds fill> Liquidity
 *    Staking request.mint> Token
 *    Vault request.mint> Token
 *    Vault profits.send> Oven (Buyback Burn)
 *    Vault mint> Staking
 *    Vault burn> Staking
 *    Oven fill> 5% to liquidity
 *    Oven profit> 5% to 0x4122
 *    Oven burn> Token
 * 
 * 
 *  Token
 *    Token will fine a tax of 2% with a turnable 1% for burning
 *    1% liquidity
 *    1% treasury
 *    if(ownerWants)
 *      1% burning
 *  Staking
 *    5% of the total supply will be distributed once per 12 hours (10% every 24hours)
 *    2.5% will be distributed to [Vault] (5% every 24 hours)
 *    Planned:
 *      Booster (the more staked, the more the protocol distributes) = Cancelled in favor of [Vault]
 *  Treasury
 *    Will deposit to Alpaca & Venus
 *    Once per 24 hours, will fetch all the funds, sub. by the treasury size to get the profits
 *    Profits will be sent to [Oven]
 *  Bonds
 *    People will lock their funds for 4 days, an action that will "buy" for them tokens at a discount
 *    after 4 days, contract [Token] will mint new tokens and send to bonders.
 *    Funds are sent immediately to [Treasury]
 *  Vault
 *    People can stake any acceptable token.
 *    The token will be deposited to Alpaca & Venus and generate revenue
 *    Revenue will be sent to [Oven]
 *    Stakers can withdraw at any time
 *    Stakers will get protocol emissions
 *    No risk & no ownership rights but deciding to which [Oven] address to send to.
 * 
 * 
 *  Smart Contract Functions
 *    Token (Token: Wojak)
 *      approve (public)
 *      unapprove (public)
 *      transfer (public)
 *      mint (multi.onlyOwner) (Staking, Bonds)
 *      burn (public) (Oven)
 *      addMinter (single.onlyOwner)
 *      removeMinter (single.onlyOwner)
 *      transferOwnership (single.onlyOwner)
 *      setBurningTax (single.onlyOwner)
 *      setTreasuryAddress (single.onlyOwner)
 *    Staking (Token: Boomer)
 *      approve (public)
 *      unapprove (public)
 *      transfer (public)
 *      stake (public)
 *      unstake (public)
 *      redeemRewards (public)
 *      getStats (public) returns (TotalStaked, TotalStakers, TotalRewarded)
 *      getMyData (public) returns (Staked, Rewards, NextReward)
 *      mint (multi.onlyOwner) (Self, Vault)
 *      burn (public) (Self, Vault)
 *      addMinter (single.onlyOwner)
 *      removeMinter (single.onlyOwner)
 *      transferOwnership (single.onlyOwner)
 *      setTokenAddress (single.onlyOwner)
 *    Treasury
 *      getTreasurySize (public)
 *      addToTreasury (public) (Token, Bonds, Vault)
 *      prepareOven (public)
 *      setOvenAddress (single.onlyOwner)
 *      addMethod (single.onlyOwner)
 *      removeMethod (single.onlyOwner)
 *      putProfitsBackToWork (single.onlyOwner)
 *    Bonds
 *      createBond (public)
 *      redeemBond (public)
 *      setTokenAddress (single.onlyOwner)
 *      setTreasuryAddress (single.onlyOwner)
 *      addMethod (single.onlyOwner)
 *      removeMethod (single.onlyOwner)
 *    Oven
 *      setAdminFee (single.onlyOwner)
 *      setLiquidityFee (single.onlyOwner)
 *      turnUpTheHeat (onlyTreasury)
 *      setTreasuryAddress (single.onlyOwner)
 *      getTotalBurnt (public)
 *    Vaults (Token: Zoomer)
 *      approve (public)
 *      unapprove (public)
 *      transfer (public)
 *      getMethods (public) returns (methodIds)
 *      getMethodData (public) returns (methodPoolSize, methodRewards, methodMyStaked, methodMyRewards, methodMyNextReward)
 *      addMethod (single.onlyOwner)
 *      removeMethod (single.onlyOwner)
 *      stake (public)
 *      unstake (public)
 *      redeemRewards (public)
 *      setOvenAddress (single.onlyOwner)
 *      
 * 
**/

async function main() {
  const Token = await hre.ethers.getContractFactory("Token/Wojak.sol").deploy();
  await Token.deployed();
  console.log("Token deployed to:", Token.address);

  const Staking = await hre.ethers.getContractFactory("Staking/Boomer.sol").deploy();
  await Staking.deployed();
  console.log("Staking deployed to:", Staking.address);

  const Treasury = await hre.ethers.getContractFactory("Treasury/main.sol").deploy();
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
