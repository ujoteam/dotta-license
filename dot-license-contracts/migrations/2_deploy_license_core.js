const { Artifacts } = require('../util/artifacts')
const {
  LicenseCore,
  LicenseCoreTest,
  LicenseSale,
  LicenseOwnership,
  LicenseInventory,
  LicenseBase,
  LicenseAccessControl,
  ERC721,
  ERC20,
  SafeMath,
  AffiliateProgram
} = new Artifacts(artifacts)

module.exports = function (deployer, network, accounts) {
  // deployer.then(async () => {
    // await deployer.deploy(LicenseSale)
    // await deployer.deploy(LicenseInventory)
    deployer.deploy(LicenseOwnership, "ujo", "UJO", "http://localhost", 10000)
    // deployer.deploy(ERC20)

    // let owner;

    // let licenseSaleInstance = await LicenseSale.deployed()
    // let licenseInventoryInstance = await LicenseInventory.deployed()
    // let licenseOwnershipInstance = await LicenseOwnership.deployed()
    // let daiContractInstance = await ERC20.deployed()

    // await licenseInventoryInstance.setSaleController(licenseSaleInstance.address, { from: accounts[0] })
    // await licenseSaleInstance.setDAIContract(daiContractInstance.address, { from: accounts[0] })
    // await licenseSaleInstance.setInventoryContract(licenseInventoryInstance.address, { from: accounts[0] })
    // await licenseSaleInstance.setOwnershipContract(licenseOwnershipInstance.address, { from: accounts[0] })
    // await licenseOwnershipInstance.setSaleController(licenseSaleInstance.address, { from: accounts[0] })

  // })
}