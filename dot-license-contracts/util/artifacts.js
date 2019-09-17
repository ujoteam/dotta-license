class Artifacts {
  constructor(artifacts) {
    this.Migrations = artifacts.require('Migrations');
    this.SaleStore = artifacts.require('SaleStore');
    this.SaleSimple = artifacts.require('SaleSimple');
    this.LicenseRegistry = artifacts.require('LicenseRegistry');
    this.Inventory = artifacts.require('Inventory');
    this.ERC721 = artifacts.require('ERC721');
    this.ERC20 = artifacts.require('ERC20');
    this.SafeMath = artifacts.require('SafeMath');
    this.AffiliateProgram = artifacts.require('AffiliateProgram');

    this.MockTokenReceiver = artifacts.require('MockTokenReceiver');
  }
}


module.exports = { Artifacts }