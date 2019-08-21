import { Artifacts } from '../util/artifacts';
const { LicenseCore, LicenseCoreTest, AffiliateProgram, ERC20 } = new Artifacts(
  artifacts
);

module.exports = (deployer, network, accounts) => {
  deployer.then(async () => {
    const licenseContract = network === 'test' ? LicenseCoreTest : LicenseCore;

    let daiContractInstance = await ERC20.deployed()
    let licenseContractInstance = await licenseContract.deployed()

    await deployer.deploy(AffiliateProgram, licenseContractInstance.address);

    let affilateProgramInstance = await AffiliateProgram.deployed()
    await affilateProgramInstance.setDAIContract(daiContractInstance.address, { from: accounts[0] })

  })
};
