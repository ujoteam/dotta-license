pragma solidity 0.5.0;

import "./ownership/Ownable.sol";
import "./lifecycle/Pausable.sol";
import "./interfaces/IERC20.sol";
import "./math/SafeMath.sol";

import "./LicenseOwnership.sol";
import "./LicenseInventory.sol";
import "./Affiliate/AffiliateProgram.sol";
import "./DAITransactor.sol";

contract LicenseSale is Ownable, DAITransactor {
  using SafeMath for uint256;

  AffiliateProgram public affiliateProgram;
  LicenseInventory public productInventory;
  LicenseOwnership public licenseOwnership;

  function setInventoryContract(address _productInventory) public onlyOwner {
    productInventory = LicenseInventory(_productInventory);
  }

  function setOwnershipContract(address _licenseOwnership) public onlyOwner {
    licenseOwnership = LicenseOwnership(_licenseOwnership);
  }

  modifier whenTokenNotPaused {
    require(licenseOwnership.paused() == false, "token is paused");
    _;
  }

  constructor() public {
    withdrawalAddress = msg.sender;
  }



  /**************************************
   *      LICENSE REGISTRY FUNCTIONS
   **************************************/


  /**
   * @notice Issued is emitted when a new license is issued
   */
  event LicenseIssued(
    address indexed owner,
    address indexed purchaser,
    uint256 licenseId,
    uint256 productId,
    uint256 attributes,
    uint256 issuedTime,
    uint256 expirationTime,
    address affiliate
  );

  event LicenseRenewal(
    address indexed owner,
    address indexed purchaser,
    uint256 licenseId,
    uint256 productId,
    uint256 expirationTime
  );

  struct License {
    uint256 productId;
    uint256 attributes;
    uint256 issuedTime;
    uint256 expirationTime;
    address affiliate;
  }

  /**
   * @notice All licenses in existence.
   * @dev The ID of each license is an index in this array.
   */
  License[] licenses;

  /** internal **/
  function _isValidLicense(uint256 _licenseId) internal view returns (bool) {
    return licenseProductId(_licenseId) != 0;
  }

  /** anyone **/

  /**
   * @notice Get a license's productId
   * @param _licenseId the license id
   */
  function licenseProductId(uint256 _licenseId) public view returns (uint256) {
    return licenses[_licenseId].productId;
  }

  /**
   * @notice Get a license's attributes
   * @param _licenseId the license id
   */
  function licenseAttributes(uint256 _licenseId) public view returns (uint256) {
    return licenses[_licenseId].attributes;
  }

  /**
   * @notice Get a license's issueTime
   * @param _licenseId the license id
   */
  function licenseIssuedTime(uint256 _licenseId) public view returns (uint256) {
    return licenses[_licenseId].issuedTime;
  }

  /**
   * @notice Get a license's issueTime
   * @param _licenseId the license id
   */
  function licenseExpirationTime(uint256 _licenseId) public view returns (uint256) {
    return licenses[_licenseId].expirationTime;
  }

  /**
   * @notice Get a the affiliate credited for the sale of this license
   * @param _licenseId the license id
   */
  function licenseAffiliate(uint256 _licenseId) public view returns (address) {
    return licenses[_licenseId].affiliate;
  }

  /**
   * @notice Get a license's info
   * @param _licenseId the license id
   */
  function licenseInfo(uint256 _licenseId)
    public view returns (uint256, uint256, uint256, uint256, address)
  {
    return (
      licenseProductId(_licenseId),
      licenseAttributes(_licenseId),
      licenseIssuedTime(_licenseId),
      licenseExpirationTime(_licenseId),
      licenseAffiliate(_licenseId)
    );
  }







  /**************************************
   *   LICENSE SALE/RENEWAL FUNCTIONS
   **************************************/

  /**
   * @notice We credit affiliates for renewals that occur within this time of
   * original purchase. E.g. If this is set to 1 year, and someone subscribes to
   * a monthly plan, the affiliate will receive credits for that whole year, as
   * the user renews their plan
   */
  uint256 public renewalsCreditAffiliatesFor = 365 days;

  /** internal **/
  function _performPurchase(
    uint256 _productId,
    uint256 _numCycles,
    address _assignee,
    uint256 _attributes,
    address _affiliate)
    internal returns (uint)
  {
    productInventory.purchaseOneUnitInStock(_productId);
    return _createLicense(
      _productId,
      _numCycles,
      _assignee,
      _attributes,
      _affiliate
      );
  }

  function _createLicense(
    uint256 _productId,
    uint256 _numCycles,
    address _assignee,
    uint256 _attributes,
    address _affiliate)
    internal
    returns (uint)
  {
    // You cannot create a subscription license with zero cycles
    if (productInventory.isSubscriptionProduct(_productId)) {
      require(_numCycles != 0);
    }

    // Non-subscription products have an expiration time of 0, meaning "no-expiration"
    uint256 expirationTime = productInventory.isSubscriptionProduct(_productId) ?
      now.add(productInventory.intervalOf(_productId).mul(_numCycles)) : // solium-disable-line security/no-block-members
      0;

    License memory _license = License({
      productId: _productId,
      attributes: _attributes,
      issuedTime: now, // solium-disable-line security/no-block-members
      expirationTime: expirationTime,
      affiliate: _affiliate
    });

    uint256 newLicenseId = licenses.push(_license) - 1; // solium-disable-line zeppelin/no-arithmetic-operations

    emit LicenseIssued(
      _assignee,
      msg.sender,
      newLicenseId,
      _license.productId,
      _license.attributes,
      _license.issuedTime,
      _license.expirationTime,
      _license.affiliate);

    licenseOwnership.mint(_assignee, newLicenseId);
    return newLicenseId;
  }

  function _handleAffiliate(
    address _affiliate,
    uint256 _productId,
    uint256 _licenseId,
    uint256 _purchaseAmount)
    internal
  {
    uint256 affiliateCut = affiliateProgram.cutFor(
      _affiliate,
      _productId,
      _licenseId,
      _purchaseAmount);
    if(affiliateCut > 0) {
      require(affiliateCut < _purchaseAmount, "LicenseSale._handleAffiliate(): affiliateCut < _purchaseAmount");
      affiliateProgram.credit(_affiliate, _licenseId, affiliateCut);
    }
  }

  function _performRenewal(uint256 _tokenId, uint256 _numCycles) internal {
    // You cannot renew a non-expiring license
    // ... but in what scenario can this happen?
    // require(licenses[_tokenId].expirationTime != 0);
    uint256 productId = licenses[_tokenId].productId;

    // If our expiration is in the future, renewing adds time to that future expiration
    // If our expiration has passed already, then we use `now` as the base.
    uint256 renewalBaseTime = Math.max(now, licenses[_tokenId].expirationTime);

    // We assume that the payment has been validated outside of this function
    uint256 newExpirationTime = renewalBaseTime.add(productInventory.intervalOf(productId).mul(_numCycles));

    licenses[_tokenId].expirationTime = newExpirationTime;

    emit LicenseRenewal(
      licenseOwnership.ownerOf(_tokenId),
      msg.sender,
      _tokenId,
      productId,
      newExpirationTime
    );
  }

  function _affiliateProgramIsActive() internal view returns (bool) {
    return
      address(affiliateProgram) != address(0) &&
      affiliateProgram.storeAddress() == address(this) &&
      !affiliateProgram.paused();
  }

  /** owner **/
  function setAffiliateProgramAddress(address _address) external onlyOwner {
    AffiliateProgram candidateContract = AffiliateProgram(_address);
    require(candidateContract.isAffiliateProgram());
    affiliateProgram = candidateContract;
  }

  function setRenewalsCreditAffiliatesFor(uint256 _newTime) external onlyOwner {
    renewalsCreditAffiliatesFor = _newTime;
  }

  function createPromotionalPurchase(
    uint256 _productId,
    uint256 _numCycles,
    address _assignee,
    uint256 _attributes
    )
    external
    onlyOwner
    whenTokenNotPaused
    returns (uint256)
  {
    return _performPurchase(
      _productId,
      _numCycles,
      _assignee,
      _attributes,
      address(0));
  }

  function createPromotionalRenewal(
    uint256 _tokenId,
    uint256 _numCycles
    )
    external
    onlyOwner
    whenTokenNotPaused
  {
    uint256 productId = licenses[_tokenId].productId;
    productInventory.requireRenewableProduct(productId);

    return _performRenewal(_tokenId, _numCycles);
  }

  /** anyone **/
  /**
  * @notice Makes a purchase of a product.
  * @dev Requires that the value sent is exactly the price of the product
  * @param _productId - the product to purchase
  * @param _numCycles - the number of cycles being purchased. This number should be `1` for non-subscription products and the number of cycles for subscriptions.
  * @param _assignee - the address to assign the purchase to (doesn't have to be msg.sender)
  * @param _affiliate - the address to of the affiliate - use address(0) if none
  */
  function purchase(
    uint256 _productId,
    uint256 _numCycles,
    address _assignee,
    address _affiliate
    )
    external
    whenTokenNotPaused
    returns (uint256)
  {
    require(address(daiContract) != address(0), "LicenseSale.purchase(): DAI contract address is unset");
    require(_productId != 0, "LicenseSale.purchase(): productID must be non-zero");
    require(_numCycles != 0, "LicenseSale.purchase(): numCycles must be non-zero");
    require(_assignee != address(0), "LicenseSale.purchase(): assignee must be non-zero");
    // msg.value can be zero: free products are supported

    // Don't bother dealing with excess payments. Ensure the price paid is
    // accurate. No more, no less.
    // require(msg.value == productInventory.costForProductCycles(_productId, _numCycles));
    uint256 cost = productInventory.costForProductCycles(_productId, _numCycles);
    require(daiContract.allowance(msg.sender, address(this)) == cost, "LicenseSale.purchase(): not enough DAI");
    bool ok = daiContract.transferFrom(msg.sender, address(this), cost);
    require(ok, "LicenseSale.purchase(): DAI transfer failed");

    // Non-subscription products should send a _numCycle of 1 -- you can't buy a
    // multiple quantity of a non-subscription product with this function
    if(!productInventory.isSubscriptionProduct(_productId)) {
      require(_numCycles == 1);
    }

    // this can, of course, be gamed by malicious miners. But it's adequate for our application
    // Feel free to add your own strategies for product attributes
    // solium-disable-next-line security/no-block-members, zeppelin/no-arithmetic-operations
    uint256 attributes = uint256(keccak256(abi.encodePacked(blockhash(block.number-1))))^_productId^(uint256(_assignee));
    uint256 licenseId = _performPurchase(
      _productId,
      _numCycles,
      _assignee,
      attributes,
      _affiliate);

    if(
      productInventory.priceOf(_productId) > 0 &&
      _affiliate != address(0) &&
      _affiliateProgramIsActive()
    ) {
      _handleAffiliate(
        _affiliate,
        _productId,
        licenseId,
        cost);
    }

    return licenseId;
  }

  /**
   * @notice Renews a subscription
   */
  function renew(
    uint256 _tokenId,
    uint256 _numCycles
    )
    external
    whenTokenNotPaused
  {
    require(_numCycles != 0);
    require(licenseOwnership.ownerOf(_tokenId) != address(0));

    uint256 productId = licenses[_tokenId].productId;
    productInventory.requireRenewableProduct(productId);

    // Transfer the DAI
    uint256 renewalCost = productInventory.costForProductCycles(productId, _numCycles);
    require(daiContract.allowance(msg.sender, address(this)) >= renewalCost, "LicenseSale.renew(): not enough DAI");
    bool ok = daiContract.transferFrom(msg.sender, address(this), renewalCost);
    require(ok, "LicenseSale.renew(): DAI transfer failed");

    _performRenewal(_tokenId, _numCycles);

    if(
      renewalCost > 0 &&
      licenses[_tokenId].affiliate != address(0) &&
      _affiliateProgramIsActive() &&
      licenses[_tokenId].issuedTime.add(renewalsCreditAffiliatesFor) > now
    ) {
      _handleAffiliate(
        licenses[_tokenId].affiliate,
        productId,
        _tokenId,
        renewalCost);
    }
  }



  /**
   * @notice withdrawal address
   */
  address public withdrawalAddress;

  /**
   * @notice Sets a new withdrawalAddress
   * @param _newWithdrawalAddress - the address where we'll send the funds
   */
  function setWithdrawalAddress(address _newWithdrawalAddress) external onlyOwner {
    require(_newWithdrawalAddress != address(0), "LicenseSale.setWithdrawalAddress(): new withdrawalAddress must be non-zero");
    withdrawalAddress = _newWithdrawalAddress;
  }

  /**
   * @notice Withdraw the balance to the withdrawalAddress
   * @dev We set a withdrawal address seperate from the CFO because this allows us to withdraw to a cold wallet.
   */
  function withdrawBalance() external onlyOwner {
    require(withdrawalAddress != address(0), "LicenseSale.withdrawBalance(): withdrawalAddress must be non-zero");

    bool ok = daiContract.transfer(withdrawalAddress, daiContract.balanceOf(address(this)));
    require(ok, "LicenseSale.withdrawBalance(): DAI transfer failed");
  }

}
