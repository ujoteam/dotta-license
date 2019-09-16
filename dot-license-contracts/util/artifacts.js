class Artifacts {
  constructor(artifacts) {
    this.Migrations = artifacts.require('Migrations');
    this.LicenseCore = artifacts.require('LicenseCore');
    this.LicenseCoreTest = artifacts.require('LicenseCoreTest');
    this.LicenseSale = artifacts.require('LicenseSale');
    this.LicenseOwnership = artifacts.require('LicenseOwnership');
    this.LicenseInventory = artifacts.require('LicenseInventory');
    this.ERC721 = artifacts.require('ERC721');
    this.ERC20 = artifacts.require('ERC20');
    this.SafeMath = artifacts.require('SafeMath');
    this.AffiliateProgram = artifacts.require('AffiliateProgram');

    this.MockTokenReceiver = artifacts.require('MockTokenReceiver');
  }
}


module.exports = { Artifacts }