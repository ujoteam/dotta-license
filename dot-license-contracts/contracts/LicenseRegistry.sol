pragma solidity 0.5.0;

import "./DAITransactor.sol";
import "./util/ERC721.sol";
import "./util/ERC721Metadata.sol";
import "./util/ERC721Enumerable.sol";
import "./util/ERC165.sol";
import "./util/ERC721Receiver.sol";
import "./util/Strings.sol";
import "./util/Ownable.sol";
import "./util/SafeMath.sol";

/**
 * @title LicenseRegistry
 * @notice LicenseRegistry storage contract built for managing NFTs as licenses for products or services.
 *     Much of the logic regarding ownership, approval, and transferability should bear familiarity
 *     to other ERC721 implementations while the addition functionality of operators enables other
 *     addresses to act on behalf of owners. When paired with inventory solutions, these contracts
 *     stand as foundational elements for sales and management of licensible material.
 **/
contract LicenseRegistry is Ownable, ERC165, ERC721, ERC721Metadata, ERC721Enumerable
{
    using SafeMath for uint256;

    address public controller;
    function setController(address _controller) onlyOwner public {
        controller = _controller;
    }

    // Total amount of tokens
    uint256 public totalSupply;

    // Mapping from token ID to owner
    mapping (uint256 => address) private tokenOwner;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private tokenApprovals;

    // Mapping from owner address to operator address to approval
    mapping (address => mapping (address => bool)) private operatorApprovals;

    // Mapping from owner to list of owned token IDs
    mapping (address => uint256[]) private ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private ownedTokensIndex;

    string public name;
    string public symbol;
    string public tokenMetadataBaseURI;

    constructor(string memory _name, string memory _symbol, string memory _tokenMetadataBaseURI, uint256 _totalSupply) public {
        name = _name;
        symbol = _symbol;
        tokenMetadataBaseURI = _tokenMetadataBaseURI;
        totalSupply = _totalSupply;
    }

    function implementsERC721() external pure returns (bool) {
        return true;
    }

    function tokenURI(uint256 _tokenId)
        external
        view
        returns (string memory infoUrl)
    {
        return Strings.strConcat(
            tokenMetadataBaseURI,
            Strings.uint2str(_tokenId));
    }

    function supportsInterface(
        bytes4 interfaceID) // solium-disable-line ujo/underscore-function-arguments
        external view returns (bool)
    {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == 0x5b5e139f || // ERC721Metadata
            interfaceID == 0x6466353c || // ERC-721 on 3/7/2018
            interfaceID == 0x780e9d63; // ERC721Enumerable
    }

    function setTokenMetadataBaseURI(string calldata _newBaseURI) external onlyOwner {
        tokenMetadataBaseURI = _newBaseURI;
    }

    /**
     * @notice Guarantees msg.sender is owner of the given token
     * @param _tokenId uint256 ID of the token to validate its ownership belongs to msg.sender
     */
    modifier onlyOwnerOf(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "LicenseRegistry.onlyOwnerOf(): only the owner of that token can do that");
        _;
    }

    /**
     * @notice Enumerate valid NFTs
     * @dev Our Licenses are kept in an array and each new License-token is just
     * the next element in the array. This method is required for ERC721Enumerable
     * which may support more complicated storage schemes. However, in our case the
     * _index is the tokenId
     * @param _index A counter less than `totalSupply`
     * @return The token identifier for the `_index`th NFT
     */
    function tokenByIndex(uint256 _index) external view returns (uint256) {
        require(_index < totalSupply, "LicenseRegistry.tokenByIndex(): token index out of range");
        return _index;
    }

    /**
     * @notice Gets the total token count of the specified address
     * @param _owner address to query the balance of
     * @return uint256 representing the amount of tokens owned by the passed address
     */
    function balanceOf(address _owner) public view returns (uint256) {
        require(_owner != address(0), "LicenseRegistry.balanceOf(): owner must be non-zero");
        return ownedTokens[_owner].length;
    }

    /**
     * @notice Gets the list of tokens owned by a given address
     * @param _owner address to query the tokens of
     * @return uint256[] representing the list of tokenIds owned by the passed address
     */
    function tokensOf(address _owner) public view returns (uint256[] memory) {
        require(_owner != address(0), "LicenseRegistry.balanceOf(): owner must be non-zero");
        return ownedTokens[_owner];
    }

    /**
     * @notice Enumerate NFTs assigned to an owner
     * @dev Throws if `_index` >= `balanceOf(_owner)` or if
     *  `_owner` is the zero address, representing invalid NFTs.
     * @param _owner An address where we are interested in NFTs owned by them
     * @param _index A counter less than `balanceOf(_owner)`
     * @return The token identifier for the `_index`th NFT assigned to `_owner`,
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index)
        external
        view
        returns (uint256 _tokenId)
    {
        require(_owner != address(0), "LicenseRegistry.balanceOf(): owner must be non-zero");
        require(_index < balanceOf(_owner), "LicenseRegistry.tokenOfOwnerByIndex(): token index out of range");
        return ownedTokens[_owner][_index];
    }

    /**
     * @notice Gets the owner of the specified token ID
     * @param _tokenId uint256 ID of the token to query the owner of
     * @return owner address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = tokenOwner[_tokenId];
        require(owner != address(0), "LicenseRegistry.ownerOf(): owner must be non-zero");
        return owner;
    }

    /**
     * @notice Gets the address approved to take ownership of a given token ID
     * @param _tokenId uint256 ID of the token to query the approval of
     * @return address currently approved to take ownership of the given token ID
     */
    function getApproved(uint256 _tokenId) public view returns (address) {
        return tokenApprovals[_tokenId];
    }

    /**
     * @notice Tells whether the msg.sender is approved to transfer the given token ID or not
     * Checks both for specific approval and operator approval
     * @param _tokenId uint256 ID of the token to query the approval of
     * @return bool whether transfer by msg.sender is approved for the given token ID or not
     */
    function isSenderApprovedFor(uint256 _tokenId) internal view returns (bool) {
        return
            ownerOf(_tokenId) == msg.sender ||
            isSpecificallyApprovedFor(msg.sender, _tokenId) ||
            isApprovedForAll(ownerOf(_tokenId), msg.sender);
    }

    /**
     * @notice Tells whether the _asker is approved for the given token ID or not
     * @param _asker address of asking for approval
     * @param _tokenId uint256 ID of the token to query the approval of
     * @return bool whether the requested address is approved for the given token ID or not
     */
    function isSpecificallyApprovedFor(address _asker, uint256 _tokenId) internal view returns (bool) {
        return getApproved(_tokenId) == _asker;
    }

    /**
     * @notice Tells whether an operator is approved by a given owner
     * @param _owner owner address which you want to query the approval of
     * @param _operator operator address which you want to query the approval of
     * @return bool whether the given operator is approved by the given owner
     */
    function isApprovedForAll(address _owner, address _operator) public view returns (bool) {
        return operatorApprovals[_owner][_operator];
    }

    /**
     * @notice Transfers the ownership of a given token ID to another address
     * @param _to address to receive the ownership of the given token ID
     * @param _tokenId uint256 ID of the token to be transferred
     */
    function transfer(address _to, uint256 _tokenId)
        external
        onlyOwnerOf(_tokenId)
    {
        _clearApprovalAndTransfer(msg.sender, _to, _tokenId);
    }

    /**
     * @notice Approves another address to claim the ownership of the given token ID
     * @param _to address to be approved for the given token ID
     * @param _tokenId uint256 ID of the token to be approved
     */
    function approve(address _to, uint256 _tokenId)
        external
        onlyOwnerOf(_tokenId)
    {
        address owner = ownerOf(_tokenId);
        require(_to != owner, "LicenseRegistry.approve(): new owner must be different from old owner");
        if (getApproved(_tokenId) != address(0x0) || _to != address(0x0)) {
            tokenApprovals[_tokenId] = _to;
            emit Approval(owner, _to, _tokenId);
        }
    }

    /**
     * @notice Enable or disable approval for a third party ("operator") to manage all your assets
     * @dev Emits the ApprovalForAll event
     * @param _to Address to add to the set of authorized operators.
     * @param _approved True if the operators is approved, false to revoke approval
     */
    function setApprovalForAll(address _to, bool _approved)
        external
    {
        if(_approved) {
            approveAll(_to);
        } else {
            disapproveAll(_to);
        }
    }

    /**
     * @notice Approves another address to claim for the ownership of any tokens owned by this account
     * @param _to address to be approved for the given token ID
     */
    function approveAll(address _to)
        public
    {
        require(_to != msg.sender, "LicenseRegistry.approveAll(): new owner can't be yourself");
        require(_to != address(0), "LicenseRegistry.approveAll(): new owner must be non-zero");
        operatorApprovals[msg.sender][_to] = true;
        emit ApprovalForAll(msg.sender, _to, true);
    }

    /**
     * @notice Removes the blanket approval for another address to claim for the ownership of any
     *  tokens owned by this account. Specific approval for tokenIds will remain active.
     * @dev Note that this only removes the operator approval and
     *  does not clear any independent, specific approvals of token transfers to this address
     * @param _to address to be disapproved for the given token ID
     */
    function disapproveAll(address _to)
        public
    {
        require(_to != msg.sender, "LicenseRegistry.disapproveAll(): new owner can't be yourself");
        delete operatorApprovals[msg.sender][_to];
        emit ApprovalForAll(msg.sender, _to, false);
    }

    /**
     * @notice Claims the ownership of a given token ID
     * @param _tokenId uint256 ID of the token being claimed by the msg.sender
     */
    function takeOwnership(uint256 _tokenId)
      external
    {
        require(isSenderApprovedFor(_tokenId), "LicenseRegistry.takeOwnership(): you are not approved to take ownership");
        _clearApprovalAndTransfer(ownerOf(_tokenId), msg.sender, _tokenId);
    }

    /**
     * @notice Transfer a token owned by another address, for which the calling address has
     *  previously been granted transfer approval by the owner.
     * @param _from The address that owns the token
     * @param _to The address that will take ownership of the token. Can be any address, including the caller
     * @param _tokenId The ID of the token to be transferred
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        public
    {
        require(isSenderApprovedFor(_tokenId), "LicenseRegistry.transferFrom(): you are not approved to transfer that token");
        require(ownerOf(_tokenId) == _from, "LicenseRegistry.transferFrom(): 'from' must be the current owner of the token");
        _clearApprovalAndTransfer(ownerOf(_tokenId), _to, _tokenId);
    }

    /**
     * @notice Transfers the ownership of an NFT from one address to another address
     * @dev Throws unless `msg.sender` is the current owner, an authorized
     * operator, or the approved address for this NFT. Throws if `_from` is
     * not the current owner. Throws if `_to` is the zero address. Throws if
     * `_tokenId` is not a valid NFT. When transfer is complete, this function
     * checks if `_to` is a smart contract (code size > 0). If so, it calls
     * `onERC721Received` on `_to` and throws if the return value is not
     * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
     * @param _from The current owner of the NFT
     * @param _to The new owner
     * @param _tokenId The NFT to transfer
     * @param _data Additional data with no specified format, sent in call to `_to`
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public {
        require(_to != address(0), "LicenseRegistry.safeTransferFrom(): 'to' address must be non-zero");
        transferFrom(_from, _to, _tokenId);
        if (_isContract(_to)) {
            bytes4 tokenReceiverResponse = ERC721Receiver(_to).onERC721Received.gas(50000)(msg.sender, _from, _tokenId, _data);
            require(tokenReceiverResponse == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")), "LicenseRegistry.safeTransferFrom(): bad response from ERC721 token receiver");
        }
    }

    /*
     * @notice Transfers the ownership of an NFT from one address to another address
     * @dev This works identically to the other function with an extra data parameter,
     *  except this function just sets data to ""
     * @param _from The current owner of the NFT
     * @param _to The new owner
     * @param _tokenId The NFT to transfer
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        safeTransferFrom(_from, _to, _tokenId, "");
    }


    /**
     * @notice Internal function to clear current approval and transfer the ownership of a given token ID
     * @param _from address which you want to send tokens from
     * @param _to address which you want to transfer the token to
     * @param _tokenId uint256 ID of the token to be transferred
     */
    function _clearApprovalAndTransfer(address _from, address _to, uint256 _tokenId) internal {
        require(_to != address(0), "LicenseRegistry._clearApprovalAndTransfer(): 'to' address must be non-zero");
        require(_to != ownerOf(_tokenId), "LicenseRegistry._clearApprovalAndTransfer(): 'to' address must not be the token's current owner");
        require(ownerOf(_tokenId) == _from, "LicenseRegistry._clearApprovalAndTransfer(): 'from' address must be the token's current owner");

        _clearApproval(_from, _tokenId);
        _removeToken(_from, _tokenId);
        _addToken(_to, _tokenId);
        emit Transfer(_from, _to, _tokenId);
    }

    /**
     * @notice Internal function to clear current approval of a given token ID
     * @param _owner address representing the owner of the token to be transferred
     * @param _tokenId uint256 ID of the token to be transferred
     */
    function _clearApproval(address _owner, uint256 _tokenId) private {
        require(ownerOf(_tokenId) == _owner, "LicenseRegistry._clearApproval(): 'owner' address must be the token's current owner");
        tokenApprovals[_tokenId] = address(0x0);
        emit Approval(_owner, address(0x0), _tokenId);
    }

    /**
     * @notice Internal function to add a tokenId to the list of tokenIds owned by a given address
     * @param _to address representing the new owner of the given token ID
     * @param _tokenId uint256 ID of the token to be added to the list
     */
    function _addToken(address _to, uint256 _tokenId) private {
        require(tokenOwner[_tokenId] == address(0), "LicenseRegistry._addToken(): token ID already exists");
        tokenOwner[_tokenId] = _to;
        uint256 length = balanceOf(_to);
        ownedTokens[_to].push(_tokenId);
        ownedTokensIndex[_tokenId] = length;
        totalSupply = totalSupply.add(1);
    }

    /**
     * @notice Internal function to remove a token ID from the list tokenIds owned by a given address
     * @param _from address representing the previous owner of the given token ID
     * @param _tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeToken(address _from, uint256 _tokenId) private {
        require(ownerOf(_tokenId) == _from, "LicenseRegistry._removeToken(): 'from' address must be the token's current owner");

        uint256 tokenIndex = ownedTokensIndex[_tokenId];
        uint256 lastTokenIndex = balanceOf(_from).sub(1);
        uint256 lastToken = ownedTokens[_from][lastTokenIndex];

        tokenOwner[_tokenId] = address(0x0);
        ownedTokens[_from][tokenIndex] = lastToken;
        ownedTokens[_from][lastTokenIndex] = 0;
        // Note that this will handle single-element arrays. In that case, both tokenIndex and lastTokenIndex are going to
        // be zero. Then we can make sure that we will remove _tokenId from the ownedTokens list since we are first swapping
        // the lastToken to the first position, and then dropping the element placed in the last position of the list

        ownedTokens[_from].length--;
        ownedTokensIndex[_tokenId] = 0;
        ownedTokensIndex[lastToken] = tokenIndex;
        totalSupply = totalSupply.sub(1);
    }

    function _isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }



    struct License {
        uint256 productId;
        uint256 issuedTime;
        uint256 expirationTime;
    }

    /**
     * @notice All licenses in existence.
     * @dev The ID of each license is an index in this array.
     */
    License[] licenses;

    /**
     * @notice Get a license's info
     * @param _licenseId the license id
     */
    function licenseInfo(uint256 _licenseId)
        public view returns (uint256 productId, uint256 issuedTime, uint256 expirationTime)
    {
        License storage license = licenses[_licenseId];
        return (
            license.productId,
            license.issuedTime,
            license.expirationTime
        );
    }

    event LicenseIssued(
        address indexed owner,
        address indexed purchaser,
        uint256 licenseId,
        uint256 productId,
        uint256 issuedTime,
        uint256 expirationTime
    );

    function createLicense(
        uint256 _productId,
        address _assignee,
        uint256 _expirationTime)
        public
        returns (uint)
    {
        require(msg.sender == controller || msg.sender == owner(), "LicenseRegistry.createLicense(): forbidden");

        License memory _license = License({
            productId: _productId,
            issuedTime: now, // solium-disable-line security/no-block-members
            expirationTime: _expirationTime
        });

        uint256 newLicenseId = licenses.push(_license) - 1; // solium-disable-line zeppelin/no-arithmetic-operations

        emit LicenseIssued(
            _assignee,
            msg.sender,
            newLicenseId,
            _license.productId,
            _license.issuedTime,
            _license.expirationTime);

        _addToken(_assignee, newLicenseId);
        emit Transfer(address(0x0), _assignee, newLicenseId);

        return newLicenseId;
    }

    function setExpirationTime(uint256 _tokenId, uint256 newExpirationTime) public {
        require(msg.sender == controller || msg.sender == owner(), "LicenseRegistry.createLicense(): forbidden");

        licenses[_tokenId].expirationTime = newExpirationTime;
    }
}
