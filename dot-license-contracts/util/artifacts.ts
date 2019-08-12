export class Artifacts {
  public Migrations: any;
  public LicenseCore: any;
  public LicenseCoreTest: any;
  public LicenseSale: any;
  public LicenseOwnership: any;
  public LicenseInventory: any;
  public LicenseBase: any;
  public LicenseAccessControl: any;
  public AffiliateProgram: any;
  public ERC20: any;
  public ERC721: any;
  public SafeMath: any;

  public MockTokenReceiver: any;

  constructor(artifacts: any) {
    this.Migrations = artifacts.require('Migrations');
    this.LicenseCore = artifacts.require('LicenseCore');
    this.LicenseCoreTest = artifacts.require('LicenseCoreTest');
    this.LicenseSale = artifacts.require('LicenseSale');
    this.LicenseOwnership = artifacts.require('LicenseOwnership');
    this.LicenseInventory = artifacts.require('LicenseInventory');
    // this.LicenseBase = artifacts.require('LicenseBase');
    // this.LicenseAccessControl = artifacts.require('LicenseAccessControl');
    this.ERC721 = artifacts.require('ERC721');
    this.ERC20 = artifacts.require('ERC20');
    this.SafeMath = artifacts.require('SafeMath');
    this.AffiliateProgram = artifacts.require('AffiliateProgram');

    this.MockTokenReceiver = artifacts.require('MockTokenReceiver');
  }
}
