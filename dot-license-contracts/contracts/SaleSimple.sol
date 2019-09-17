pragma solidity 0.5.0;

import "./ownership/Ownable.sol";
import "./math/SafeMath.sol";

import "./LicenseOwnership.sol";
import "./DAITransactor.sol";

/**
 * SaleSimple is an extremely simple Sale contract that does not distinguish between different
 * products.  There is a single price for licenses.  Licenses are non-expiring, meaning that
 * subscriptions are not supported.
 */
contract SaleSimple is Ownable, DAITransactor
{
    using SafeMath for uint256;

    constructor(address _licenseOwnership, uint256 _daiWeiPrice, uint256 _availableSupply) public {
        licenseOwnership = LicenseOwnership(_licenseOwnership);
        daiWeiPrice = _daiWeiPrice;
        availableSupply = _availableSupply;
        withdrawalAddress = msg.sender;
    }

    LicenseOwnership public licenseOwnership;
    function setOwnershipContract(address _licenseOwnership) public onlyOwner {
        licenseOwnership = LicenseOwnership(_licenseOwnership);
    }

    // @notice Single price for all licenses.
    uint256 public daiWeiPrice;
    function setDaiWeiPrice(uint256 _newPrice) public onlyOwner {
        daiWeiPrice = _newPrice;
    }

    // @notice Total number of licenses available.
    uint256 public availableSupply;
    function setAvailableSupply(uint256 _availableSupply) public onlyOwner {
        availableSupply = _availableSupply;
    }

    /** internal **/
    function _performPurchase(address _assignee) internal returns (uint) {
        availableSupply = availableSupply.sub(1);
        return _createLicense(_assignee);
    }

    function _createLicense(address _assignee)
        internal
        returns (uint)
    {
        uint256 newLicenseId = licenseOwnership.createLicense(0, _assignee, 0);
        return newLicenseId;
    }

    function createPromotionalPurchase(address _assignee)
        external
        onlyOwner
        returns (uint256)
    {
        return _performPurchase(_assignee);
    }

    /** anyone **/
    /**
     * @notice Makes a purchase of a product.
     * @dev Requires that the value sent is exactly the price of the product
     * @param _assignee - the address to assign the purchase to (doesn't have to be msg.sender)
     */
    function purchase(address _assignee)
        external
        returns (uint256)
    {
        require(daiWeiPrice == 0 || address(daiContract) != address(0), "SaleSimple.purchase(): DAI contract address is unset");
        require(_assignee != address(0), "SaleSimple.purchase(): assignee must be non-zero");

        if (daiWeiPrice > 0) {
            require(daiContract.allowance(msg.sender, address(this)) == daiWeiPrice, "SaleSimple.purchase(): not enough DAI");
            bool ok = daiContract.transferFrom(msg.sender, address(this), daiWeiPrice);
            require(ok, "SaleSimple.purchase(): DAI transfer failed");
        }

        uint256 licenseId = _performPurchase(_assignee);
        return licenseId;
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
        require(_newWithdrawalAddress != address(0), "SaleSimple.setWithdrawalAddress(): new withdrawalAddress must be non-zero");
        withdrawalAddress = _newWithdrawalAddress;
    }

    /**
     * @notice Withdraw the balance to the withdrawalAddress
     * @dev We set a withdrawal address seperate from the CFO because this allows us to withdraw to a cold wallet.
     */
    function withdrawBalance() external onlyOwner {
        require(withdrawalAddress != address(0), "SaleSimple.withdrawBalance(): withdrawalAddress must be non-zero");

        bool ok = daiContract.transfer(withdrawalAddress, daiContract.balanceOf(address(this)));
        require(ok, "SaleSimple.withdrawBalance(): DAI transfer failed");
    }
}
