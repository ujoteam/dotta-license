import { Artifacts } from '../util/artifacts';
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
} = new Artifacts(artifacts);

module.exports = (deployer: any, network: string) => {
  // const licenseContract = network === 'test' ? LicenseCoreTest : LicenseCore;

  // TODO - Do this in tests instead of in migrations
  // const daiContract = network === 'test' ? ERC20 : ERC20;
  // deployer.deploy(licenseContract);
  // deployer.deploy(daiContract);
  deployer.deploy(LicenseCore)
  deployer.deploy(LicenseSale)
};
