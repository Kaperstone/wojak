const { expect } = require("chai");
const { ethers } = require("hardhat");

async function main() {
    const wftm = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"
    const usdc = "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75"
    const boo = "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE"
    const credit = "0x77128DFdD0ac859B33F44050c6fa272F34872B5E"
    const scream = "0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475"
    const tarot = "0xC5e2B037D30a390e62180970B3aa4E91868764cD"

    const unlimited = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

    const [owner] = await ethers.getSigners()
    const signer = new ethers.Wallet("eac02834adc5c16d756af6cacc67abcdadbb2be4080a19e56f61ecb20fd616b8")

    let list = [
        "Boomer",
        "Chad",
        "Keeper",
        "Locker",
        "Manager",
        "Treasury",
        "Wojak",
        "Zoomer",
        "BooSoy",
        "CreditSoy",
        "ScreamSoy",
        "TarotSoy",
        "UsdcSoy"
    ]

    let contracts = {}

    for (let x = 0; x < list.length; x++) {
        const Contract = await ethers.getContractFactory(list[x])

        const name = list[x].toLowerCase()

        contracts[name] = await Contract.deploy()
        await contracts[name].deployed()

        console.log(list[x] + " deployed: " + contracts[name].address)
    }

    const router = new ethers.Contract("0xF491e7B69E4244ad4002BC14e878a34207E38c29", [
        "function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts)"
    ], signer)

    // Prepare everything with `Manager`
    contracts.manager.setAddressToken(contracts.wojak.address)
    contracts.manager.setAddressStaking(contracts.boomer.address)
    contracts.manager.setAddressBonds(contracts.chad.address)
    contracts.manager.setAddressKeeper(contracts.keeper.address)
    contracts.manager.setAddressLocker(contracts.locker.address)
    contracts.manager.setAddressTreasury(contracts.treasury.address)
    contracts.manager.setAddressZoomer(contracts.zoomer.address)

    contracts.manager.setAddressBooSoy(contracts.boosoy.address)
    contracts.manager.setAddressCreditSoy(contracts.creditsoy.address)
    contracts.manager.setAddressScreamSoy(contracts.screamsoy.address)
    contracts.manager.setAddressTarotSoy(contracts.tarotsoy.address)
    contracts.manager.setAddressUsdcSoy(contracts.usdcsoy.address)

    contracts.manager.updateKeeperContracts()
    contracts.manager.updateContract()

    await router.swapExactETHForTokens(0, [wftm, usdc], owner.address, Date.now() + 1000 * 60 * 10,
        {
            value: ethers.utils.parseEther("10000000"), // 10mil
            gasLimit: 310000
        }
    );

    await router.addLiquidity(
        contracts.wojak.address,
        usdc,
        ethers.utils.parseUnits("8800", 18), ethers.utils.parseUnits("8800000", 6),
        0, 0,
        contracts.keeper.address,
        Date.now() + 1000 * 60 * 10);

    let wjkAmount = await stake.balanceOf(owner.address)
    console.log("> wjkAmount = " + wjkAmount)
    
    await contracts.wojak.approve(contracts.boomer.address, unlimited)
    let swjkAmount = await contracts.boomer.stake(ethers.utils.parseUnits("1", 18)) // Stake one WJK
    console.log("> staked:swjkAmount = " + swjkAmount)

    await contracts.keeper.performUpkeep("0x0000000000000000000000000000000000000000000000000000000000000000")

    // buy usdc , boo , scream , tarot , credit
    // setTimeout(2 minutes)
    // put into all soys
    // launch keeper
    // 

    /*
    it("Stake 1 $WJK", async function() {
        const [owner] = await ethers.getSigners();

        const Wojak = await ethers.getContractFactory("Wojak");
        const Boomer = await ethers.getContractFactory("Boomer");

        const token = await Wojak.deploy();
        const stake = await Boomer.deploy();

        const CONTRACT_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("CONTRACT_ROLE"))



        console.log("setAddressToken(" + token.address + ")")
        await stake.setAddressToken(token.address);
        console.log("grantRole(CONTRACT_ROLE, " + stake.address + ")")
        await token.grantRole(CONTRACT_ROLE, stake.address);

        console.log("Attempt approve token")
        await token.approve(stake.address, ethers.utils.parseUnits("1.0", 18))
        
        console.log("\t$BOOMER=" + ethers.utils.commify(ethers.utils.formatUnits(await stake.balanceOf(owner.address))))
        console.log("\t$WJK=" + ethers.utils.commify(ethers.utils.formatUnits(await token.balanceOf(owner.address))))

        console.log("Attempt to stake")
        await stake.stake(ethers.utils.parseUnits("1.0", 18))

        console.log("\t$BOOMER=" + ethers.utils.commify(ethers.utils.formatUnits(await stake.balanceOf(owner.address))))
        console.log("\t$WJK=" + ethers.utils.commify(ethers.utils.formatUnits(await token.balanceOf(owner.address))))

        expect(true).to.equal(true);
    });
    */
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });