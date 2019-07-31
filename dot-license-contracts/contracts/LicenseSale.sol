pragma solidity 0.5.0;

import "./ownership/Ownable.sol";
import "./interfaces/ERC20.sol";

import "./LicenseOwnership.sol";
import "./Affiliate/AffiliateProgram.sol";
import "./DAITransactor.sol";

contract LicenseSale is Ownable, DAITransactor, LicenseOwnership {
  AffiliateProgram public affiliateProgram;

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
    _purchaseOneUnitInStock(_productId);
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
    if (isSubscriptionProduct(_productId)) {
      require(_numCycles != 0);
    }

    // Non-subscription products have an expiration time of 0, meaning "no-expiration"
    uint256 expirationTime = isSubscriptionProduct(_productId) ?
      now.add(intervalOf(_productId).mul(_numCycles)) : // solium-disable-line security/no-block-members
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
    _mint(_assignee, newLicenseId);
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
      require(affiliateCut < _purchaseAmount);
      affiliateProgram.credit(_affiliate, _licenseId, affiliateCut);
    }
  }

  function _performRenewal(uint256 _tokenId, uint256 _numCycles) internal {
    // You cannot renew a non-expiring license
    // ... but in what scenario can this happen?
    // require(licenses[_tokenId].expirationTime != 0);
    uint256 productId = licenseProductId(_tokenId);

    // If our expiration is in the future, renewing adds time to that future expiration
    // If our expiration has passed already, then we use `now` as the base.
    uint256 renewalBaseTime = Math.max(now, licenses[_tokenId].expirationTime);

    // We assume that the payment has been validated outside of this function
    uint256 newExpirationTime = renewalBaseTime.add(intervalOf(productId).mul(_numCycles));

    licenses[_tokenId].expirationTime = newExpirationTime;

    emit LicenseRenewal(
      ownerOf(_tokenId),
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
    whenNotPaused
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
    whenNotPaused
  {
    uint256 productId = licenseProductId(_tokenId);
    _requireRenewableProduct(productId);

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
    whenNotPaused
    returns (uint256)
  {
    require(address(daiContract) != address(0), "LicenseSale.purchase(): DAI contract address is unset");
    require(_productId != 0, "LicenseSale.purchase(): productID must be non-zero");
    require(_numCycles != 0, "LicenseSale.purchase(): numCycles must be non-zero");
    require(_assignee != address(0), "LicenseSale.purchase(): assignee must be non-zero");
    // msg.value can be zero: free products are supported

    // Don't bother dealing with excess payments. Ensure the price paid is
    // accurate. No more, no less.
    // require(msg.value == costForProductCycles(_productId, _numCycles));
    uint256 cost = costForProductCycles(_productId, _numCycles);
    require(daiContract.allowance(msg.sender, address(this)) >= cost, "LicenseSale.purchase(): not enough DAI");
    bool ok = daiContract.transferFrom(msg.sender, address(this), cost);
    require(ok, "LicenseSale.purchase(): DAI transfer failed");

    // Non-subscription products should send a _numCycle of 1 -- you can't buy a
    // multiple quantity of a non-subscription product with this function
    if(!isSubscriptionProduct(_productId)) {
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
      priceOf(_productId) > 0 &&
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
    whenNotPaused
  {
    require(_numCycles != 0);
    require(ownerOf(_tokenId) != address(0));

    uint256 productId = licenseProductId(_tokenId);
    _requireRenewableProduct(productId);

    // Transfer the DAI
    uint256 renewalCost = costForProductCycles(productId, _numCycles);
    require(daiContract.allowance(msg.sender, address(this)) >= renewalCost, "LicenseSale.renew(): not enough DAI");
    bool ok = daiContract.transferFrom(msg.sender, address(this), renewalCost);
    require(ok, "LicenseSale.renew(): DAI transfer failed");

    _performRenewal(_tokenId, _numCycles);

    if(
      renewalCost > 0 &&
      licenseAffiliate(_tokenId) != address(0) &&
      _affiliateProgramIsActive() &&
      licenseIssuedTime(_tokenId).add(renewalsCreditAffiliatesFor) > now
    ) {
      _handleAffiliate(
        licenseAffiliate(_tokenId),
        productId,
        _tokenId,
        renewalCost);
    }
  }

}
