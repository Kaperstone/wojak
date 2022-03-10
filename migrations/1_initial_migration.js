const Wojak = artifacts.require("Wojak");
const Boomer = artifacts.require("Boomer");
const Zoomer = artifacts.require("Zoomer");
const Chad = artifacts.require("Chad");
const Keeper = artifacts.require("Keeper");
const Locker = artifacts.require("Locker");
const Treasury = artifacts.require("Treasury");
const Manager = artifacts.require("Manager");

const BooSoy = artifacts.require("BooSoy");
const CreditSoy = artifacts.require("CreditSoy");
const ScreamSoy = artifacts.require("ScreamSoy");
const TarotSoy = artifacts.require("TarotSoy");
const UsdcSoy = artifacts.require("UsdcSoy");

module.exports = function (deployer) {
  // deployer.deploy(Wojak);
  // deployer.deploy(Boomer);
  // deployer.deploy(Zoomer);
  // deployer.deploy(Chad);
  // deployer.deploy(Keeper);
  // deployer.deploy(Locker);
  // deployer.deploy(Treasury);
  // deployer.deploy(Manager);

  deployer.deploy(BooSoy);
  deployer.deploy(CreditSoy);
  deployer.deploy(ScreamSoy);
  deployer.deploy(TarotSoy);
  deployer.deploy(UsdcSoy);
};
