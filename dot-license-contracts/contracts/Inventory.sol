pragma solidity 0.5.0;

import "./util/SafeMath.sol";
import "./util/Ownable.sol";

/**
 * @title Inventory
 * @notice Inventory is a simple storage contract that stores products, their prices, and a
 *     few other attributes (supply cap, subscription interval, etc.) that facilitate making purchases
 *     on-chain.  It is separate from the Sale contract so that new Sale logic can be deployed without
 *     requiring the developer to migrate any product data to a new contract.
 **/
contract Inventory is Ownable
{
    using SafeMath for uint256;

    address public controller;
    function setController(address _controller) onlyOwner public {
        controller = _controller;
    }

    event ProductCreated(
        uint256 id,
        uint256 price,
        uint256 available,
        uint256 supplyCap,
        uint256 interval,
        bool renewable
    );
    event ProductInventoryAdjusted(uint256 productId, uint256 available);
    event ProductPriceChanged(uint256 productId, uint256 price);
    event ProductRenewableChanged(uint256 productId, bool renewable);


    /**
     * @notice Product defines a product
     * * renewable: There may come a time when we which to disable the ability to renew a subscription. For example, a plan we no longer wish to support. Obviously care needs to be taken with how we communicate this to customers, but contract-wise, we want to support the ability to discontinue renewal of certain plans.
     */
    struct Product {
        uint256 id;
        uint256 price;
        uint256 available;
        uint256 supplyCap;
        uint256 sold;
        uint256 interval;
        bool renewable;
    }

    // @notice All products in existence
    uint256[] public allProductIds;

    // @notice A mapping from product ids to Products
    mapping (uint256 => Product) public products;

    /*** internal ***/

    /**
     * @notice Checks to see if a product exists
     * @param _productId uint256 ID representing the product
     * @return bool representing the existence of the product
     */
    function _productExists(uint256 _productId) internal view returns (bool) {
        return products[_productId].id != 0;
    }

    /**
     * @notice Checks to see if a product does not exists
     * @param _productId uint256 ID representing the product
     * @return bool representing the non-existence of the product
     */
    function _productDoesNotExist(uint256 _productId) internal view returns (bool) {
        return products[_productId].id == 0;
    }

    /**
     * @notice Creates a product in the list of products
     * @param _productId uint256 ID representing the product (cannot be changed)
     * @param _initialPrice uint256 the starting price in DAI (price can be changed)
     * @param _initialInventoryQuantity uint256 of the initial inventory (inventory can be changed)
     * @param _supplyCap uint256 representing total supply cap - use `0` for "unlimited" (cannot be changed)
     * @param _interval uint256 representing the interval ????
     */
    function _createProduct(
        uint256 _productId,
        uint256 _initialPrice,
        uint256 _initialInventoryQuantity,
        uint256 _supplyCap,
        uint256 _interval)
        internal
    {
        require(_productDoesNotExist(_productId), "Inventory._createProduct(): product already exists");
        require(_initialInventoryQuantity <= _supplyCap, "Inventory._createProduct(): initialInventoryQuantity > supplyCap");

        Product memory _product = Product({
            id: _productId,
            price: _initialPrice,
            available: _initialInventoryQuantity,
            supplyCap: _supplyCap,
            sold: 0,
            interval: _interval,
            renewable: _interval == 0 ? false : true
        });

        products[_productId] = _product;
        allProductIds.push(_productId);

        emit ProductCreated(
            _product.id,
            _product.price,
            _product.available,
            _product.supplyCap,
            _product.interval,
            _product.renewable
        );
    }

    /**
     * @notice Increase the inventory of a product with a supply cap > 0.
     * @param _productId uint256 ID representing the product
     * @param _inventoryAdjustment uint256 the amount to increase the product inventory
     */
    function _incrementInventory(
        uint256 _productId,
        uint256 _inventoryAdjustment)
        internal
    {
        require(_productExists(_productId), "Inventory._incrementInventory(): product does not exist");
        uint256 newInventoryLevel = products[_productId].available.add(_inventoryAdjustment);

        // A supplyCap of "0" means "unlimited". Otherwise we need to ensure that we're not over-creating this product
        if (products[_productId].supplyCap > 0) {
            // you have to take already sold into account
            require(products[_productId].sold.add(newInventoryLevel) <= products[_productId].supplyCap, "Inventory._incrementInventory(): that would exceed maximum supplyCap");
        }

        products[_productId].available = newInventoryLevel;
    }

    /**
     * @notice Decrease the inventory of a product with a supply cap > 0.
     * @param _productId uint256 ID representing the product
     * @param _inventoryAdjustment uint256 the amount to decrease the product inventory
     */
    function _decrementInventory(
        uint256 _productId,
        uint256 _inventoryAdjustment)
        internal
    {
        require(_productExists(_productId), "Inventory._decrementInventory(): product does not exist");
        uint256 newInventoryLevel = products[_productId].available.sub(_inventoryAdjustment);
        // unnecessary because we're using SafeMath and an unsigned int
        // require(newInventoryLevel >= 0);
        products[_productId].available = newInventoryLevel;
    }

    /**
     * @notice Remove additional inventory of a product.
     * @param _productId uint256 ID representing the product
     */
    function _clearInventory(uint256 _productId) internal {
        require(_productExists(_productId), "Inventory._clearInventory(): product does not exist");
        products[_productId].available = 0;
    }

    /**
     * @notice Update the price of a product.
     * @param _productId uint256 ID representing the product
     * @param _price uint256 the updated price in DAI
     */
    function _setPrice(uint256 _productId, uint256 _price) internal {
        require(_productExists(_productId), "Inventory._setPrice(): product does not exist");
        products[_productId].price = _price;
    }

    /**
     * @notice Update the product to require or disable subscription functionality.
     * @param _productId uint256 ID representing the product
     * @param _isRenewable bool of renewability
     */
    function _setRenewable(uint256 _productId, bool _isRenewable) internal {
        require(_productExists(_productId), "Inventory._setRenewable(): product does not exist");
        products[_productId].renewable = _isRenewable;
    }

    /**
     * @notice Enables msg.sender to purchase one item of product.
     * @param _productId uint256 ID representing the product
     */
    function purchaseOneUnitInStock(uint256 _productId) public {
        require(msg.sender == controller, "Inventory.purchaseOneUnitInStock(): can only be called by the controller");
        require(_productExists(_productId), "Inventory.purchaseOneUnitInStock(): product does not exist");
        require(availableInventoryOf(_productId) > 0, "Inventory.purchaseOneUnitInStock(): no available inventory");

        // lower inventory
        _decrementInventory(_productId, 1);

        // record that one was sold
        products[_productId].sold = products[_productId].sold.add(1);
    }

    /**
     * @notice Enables msg.sender to purchase one item of product.
     * @param _productId uint256 ID representing the product
     */
    function requireRenewableProduct(uint256 _productId) public view {
        // productId must exist
        require(_productId != 0, "Inventory.requireRenewableProduct(): productID must be non-zero");
        // You can only renew a subscription product
        require(isSubscriptionProduct(_productId), "Inventory.requireRenewableProduct(): not a subscription product");
        // The product must currently be renewable
        require(renewableOf(_productId), "Inventory.requireRenewableProduct(): product is not renewable");
    }

    /*** public ***/

    /** executives-only **/

    /**
     * @notice createProduct creates a new product in the system
     * @param _productId uint256 ID representing the product (cannot be changed)
     * @param _initialPrice uint256 the starting price in DAI (price can be changed)
     * @param _initialInventoryQuantity uint256 of the initial inventory (inventory can be changed)
     * @param _supplyCap uint256 representing total supply cap - use `0` for "unlimited" (cannot be changed)
     */
    function createProduct(
        uint256 _productId,
        uint256 _initialPrice,
        uint256 _initialInventoryQuantity,
        uint256 _supplyCap,
        uint256 _interval)
        external
        onlyOwner
    {
        _createProduct(
            _productId,
            _initialPrice,
            _initialInventoryQuantity,
            _supplyCap,
            _interval);
    }

    /**
     * @notice Increases the inventory of a product
     * @param _productId uint256 ID representing the product
     * @param _inventoryAdjustment uint256 the amount to increment
     */
    function incrementInventory(
        uint256 _productId,
        uint256 _inventoryAdjustment)
        external
        onlyOwner
    {
        _incrementInventory(_productId, _inventoryAdjustment);
        emit ProductInventoryAdjusted(_productId, availableInventoryOf(_productId));
    }

    /**
     * @notice Decreases inventory levels for a product
     * @param _productId uint256 ID representing the product
     * @param _inventoryAdjustment - the amount to decrement
     */
    function decrementInventory(
        uint256 _productId,
        uint256 _inventoryAdjustment)
        external
        onlyOwner
    {
        _decrementInventory(_productId, _inventoryAdjustment);
        emit ProductInventoryAdjusted(_productId, availableInventoryOf(_productId));
    }

    /**
     * @notice clearInventory clears the inventory of a product.
     * @dev decrementInventory verifies inventory levels, whereas this method
     * simply sets the inventory to zero. This is useful, for example, if an
     * owner wants to take a product off the market quickly. There could be a
     * race condition with decrementInventory where a product is sold, which could
     * cause the admins decrement to fail (because it may try to decrement more
     * than available).
     *
     * @param _productId - the product id
     */
    function clearInventory(uint256 _productId)
        external
        onlyOwner
    {
        _clearInventory(_productId);
        emit ProductInventoryAdjusted(_productId, availableInventoryOf(_productId));
    }

    /**
     * @notice Update the price of a product.
     * @param _productId uint256 ID representing the product
     * @param _price uint256 the updated price in DAI
     */
    function setPrice(uint256 _productId, uint256 _price)
        external
        onlyOwner
    {
        _setPrice(_productId, _price);
        emit ProductPriceChanged(_productId, _price);
    }

    /**
     * @notice Update the product to require or disable subscription functionality.
     * @param _productId uint256 ID representing the product
     * @param _isRenewable bool of renewability
     */
    function setRenewable(uint256 _productId, bool _newRenewable)
        external
        onlyOwner
    {
        _setRenewable(_productId, _newRenewable);
        emit ProductRenewableChanged(_productId, _newRenewable);
    }

    /** anyone **/

    /**
     * @notice Reads the price of a product
     * @param _productId uint256 ID representing the product
     * @return uint256 representing the price
     */
    function priceOf(uint256 _productId) public view returns (uint256) {
        return products[_productId].price;
    }

    /**
     * @notice The available inventory of a product
     * @param _productId uint256 ID representing the product
     * @return uint256 representing the amount of product available to purchase
     */
    function availableInventoryOf(uint256 _productId) public view returns (uint256) {
        return products[_productId].available;
    }

    /**
     * @notice The total supplyCap of a product
     * @param _productId uint256 ID representing the product
     * @return uint256 representing the total amount over the lifetime of the product
     */
    function totalSupplyOf(uint256 _productId) public view returns (uint256) {
        return products[_productId].supplyCap;
    }

    /**
     * @notice The total sold of a product
     * @param _productId uint256 ID representing the product
     * @return uint256 representing the total amount of product sold
     */
    function totalSold(uint256 _productId) public view returns (uint256) {
        return products[_productId].sold;
    }

    /**
     * @notice The renewal interval of a product in seconds
     * @param _productId uint256 ID representing the product
     * @return uint256 representing the subscription length of the product
     */
    function intervalOf(uint256 _productId) public view returns (uint256) {
        return products[_productId].interval;
    }

    /**
     * @notice Is this product renewable?
     * @param _productId uint256 ID representing the product
     * @return bool which returns whether the product currently requires a subscription
     */
    function renewableOf(uint256 _productId) public view returns (bool) {
        return products[_productId].renewable;
    }


    /**
     * @notice The product info for a product
     * @param _productId uint256 ID representing the product
     * @return struct containing all the product properties as defined in createProduct
     */
    function productInfo(uint256 _productId)
        public
        view
        returns (uint256 price, uint256 inventory, uint256 supplyCap, uint256 interval, bool renewable)
    {
        return (
            priceOf(_productId),
            availableInventoryOf(_productId),
            totalSupplyOf(_productId),
            intervalOf(_productId),
            renewableOf(_productId));
    }

    /**
     * @notice Get all product ids
     * @return uint256[] containing all the productIds
     */
    function getAllProductIds() public view returns (uint256[] memory) {
        return allProductIds;
    }

    /**
     * @notice returns the total cost to renew a product for a number of cycles
     * @dev If a product is a subscription, the interval defines the period of
     * time, in seconds, users can subscribe for. E.g. 1 month or 1 year.
     * _numCycles is the number of these intervals we want to use in the
     * calculation of the price.
     *
     * We require that the end user send precisely the amount required (instead
     * of dealing with excess refunds). This method is public so that clients can
     * read the exact amount our contract expects to receive.
     *
     * @param _productId - the product we're calculating for
     * @param _numCycles - the number of cycles to calculate for
     */
    function costForProductCycles(uint256 _productId, uint256 _numCycles)
        public
        view
        returns (uint256)
    {
        return priceOf(_productId).mul(_numCycles);
    }

    /**
     * @notice returns if this product is a subscription or not
     * @dev Some products are subscriptions and others are not. An interval of 0
     * means the product is not a subscription
     * @param _productId - the product we're checking
     */
    function isSubscriptionProduct(uint256 _productId) public view returns (bool) {
        return intervalOf(_productId) > 0;
    }
}
