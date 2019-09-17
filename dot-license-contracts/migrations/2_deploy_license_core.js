const { Artifacts } = require('../util/artifacts')
const {
  LicenseCore,
  LicenseCoreTest,
  SaleStore,
  LicenseRegistry,
  Inventory,
  LicenseBase,
  LicenseAccessControl,
  ERC721,
  ERC20,
  SafeMath,
  AffiliateProgram
} = new Artifacts(artifacts)

module.exports = function (deployer, network, accounts) {
  // deployer.then(async () => {
    // await deployer.deploy(SaleStore)
    // await deployer.deploy(Inventory)
    deployer.deploy(LicenseRegistry, "ujo", "UJO", "http://localhost", 10000)
    // deployer.deploy(ERC20)

    // let owner;

    // let licenseSaleInstance = await SaleStore.deployed()
    // let licenseInventoryInstance = await Inventory.deployed()
    // let licenseRegistryInstance = await LicenseRegistry.deployed()
    // let daiContractInstance = await ERC20.deployed()

    // await licenseInventoryInstance.setSaleController(licenseSaleInstance.address, { from: accounts[0] })
    // await licenseSaleInstance.setDAIContract(daiContractInstance.address, { from: accounts[0] })
    // await licenseSaleInstance.setInventoryContract(licenseInventoryInstance.address, { from: accounts[0] })
    // await licenseSaleInstance.setLicenseRegistryContract(licenseRegistryInstance.address, { from: accounts[0] })
    // await licenseRegistryInstance.setSaleController(licenseSaleInstance.address, { from: accounts[0] })

  // })
}