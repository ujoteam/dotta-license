pragma solidity ^0.4.19;

import "./LicenseInventory.sol";
import "./interfaces/ERC721.sol";
import "./interfaces/ERC721Metadata.sol";
import "./interfaces/ERC721Enumerable.sol";
import "./interfaces/ERC165.sol";
import "./interfaces/ERC721TokenReceiver.sol";
import "./strings/Strings.sol";
import "./ownership/Ownable.sol";


contract LicenseOwnership is Ownable, LicenseInventory, ERC721, ERC165, ERC721Metadata, ERC721Enumerable {
  using SafeMath for uint256;

  // Total amount of tokens
  uint256 private totalTokens;

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

  /*** Constants ***/
  // Configure these for your own deployment
  string public constant NAME = "Ujo";
  string public constant SYMBOL = "UJO";
  string public tokenMetadataBaseURI = "http://localhost";

  /**
   * @notice token's name
   */
  function name() external pure returns (string) {
    return NAME;
  }

  /**
   * @notice symbols's name
   */
  function symbol() external pure returns (string) {
    return SYMBOL;
  }

  function implementsERC721() external pure returns (bool) {
    return true;
  }

  function tokenURI(uint256 _tokenId)
    external
    view
    returns (string infoUrl)
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

  function setTokenMetadataBaseURI(string _newBaseURI) external onlyOwner {
    tokenMetadataBaseURI = _newBaseURI;
  }

  /**
  * @notice Guarantees msg.sender is owner of the given token
  * @param _tokenId uint256 ID of the token to validate its ownership belongs to msg.sender
  */
  modifier onlyOwnerOf(uint256 _tokenId) {
    require(ownerOf(_tokenId) == msg.sender, "LicenseOwnership.onlyOwnerOf(): only the owner of that token can do that");
    _;
  }

  /**
  * @notice Gets the total amount of tokens stored by the contract
  * @return uint256 representing the total amount of tokens
  */
  function totalSupply() public view returns (uint256) {
    return totalTokens;
  }

  /**
  * @notice Enumerate valid NFTs
  * @dev Our Licenses are kept in an array and each new License-token is just
  * the next element in the array. This method is required for ERC721Enumerable
  * which may support more complicated storage schemes. However, in our case the
  * _index is the tokenId
  * @param _index A counter less than `totalSupply()`
  * @return The token identifier for the `_index`th NFT
  */
  function tokenByIndex(uint256 _index) external view returns (uint256) {
    require(_index < totalSupply(), "LicenseOwnership.tokenByIndex(): token index out of range");
    return _index;
  }

  /**
  * @notice Gets the balance of the specified address
  * @param _owner address to query the balance of
  * @return uint256 representing the amount owned by the passed address
  */
  function balanceOf(address _owner) public view returns (uint256) {
    require(_owner != address(0), "LicenseOwnership.balanceOf(): owner must be non-zero");
    return ownedTokens[_owner].length;
  }

  /**
  * @notice Gets the list of tokens owned by a given address
  * @param _owner address to query the tokens of
  * @return uint256[] representing the list of tokens owned by the passed address
  */
  function tokensOf(address _owner) public view returns (uint256[]) {
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
    require(_index < balanceOf(_owner), "LicenseOwnership.tokenOfOwnerByIndex(): token index out of range");
    return ownedTokens[_owner][_index];
  }

  /**
  * @notice Gets the owner of the specified token ID
  * @param _tokenId uint256 ID of the token to query the owner of
  * @return owner address currently marked as the owner of the given token ID
  */
  function ownerOf(uint256 _tokenId) public view returns (address) {
    address owner = tokenOwner[_tokenId];
    require(owner != address(0), "LicenseOwnership.ownerOf(): owner must be non-zero");
    return owner;
  }

  /**
   * @notice Gets the approved address to take ownership of a given token ID
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
   * @notice Tells whether the msg.sender is approved for the given token ID or not
   * @param _asker address of asking for approval
   * @param _tokenId uint256 ID of the token to query the approval of
   * @return bool whether the msg.sender is approved for the given token ID or not
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
  function isApprovedForAll(address _owner, address _operator) public view returns (bool)
  {
    return operatorApprovals[_owner][_operator];
  }

  /**
  * @notice Transfers the ownership of a given token ID to another address
  * @param _to address to receive the ownership of the given token ID
  * @param _tokenId uint256 ID of the token to be transferred
  */
  function transfer(address _to, uint256 _tokenId)
    external
    whenNotPaused
    onlyOwnerOf(_tokenId)
  {
    _clearApprovalAndTransfer(msg.sender, _to, _tokenId);
  }

  /**
  * @notice Approves another address to claim for the ownership of the given token ID
  * @param _to address to be approved for the given token ID
  * @param _tokenId uint256 ID of the token to be approved
  */
  function approve(address _to, uint256 _tokenId)
    external
    whenNotPaused
    onlyOwnerOf(_tokenId)
  {
    address owner = ownerOf(_tokenId);
    require(_to != owner, "LicenseOwnership.approve(): new owner must be different from old owner");
    if (getApproved(_tokenId) != 0 || _to != 0) {
      tokenApprovals[_tokenId] = _to;
      Approval(owner, _to, _tokenId);
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
    whenNotPaused
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
    whenNotPaused
  {
    require(_to != msg.sender, "LicenseOwnership.approveAll(): new owner can't be yourself");
    require(_to != address(0), "LicenseOwnership.approveAll(): new owner must be non-zero");
    operatorApprovals[msg.sender][_to] = true;
    ApprovalForAll(msg.sender, _to, true);
  }

  /**
  * @notice Removes approval for another address to claim for the ownership of any
  *  tokens owned by this account.
  * @dev Note that this only removes the operator approval and
  *  does not clear any independent, specific approvals of token transfers to this address
  * @param _to address to be disapproved for the given token ID
  */
  function disapproveAll(address _to)
    public
    whenNotPaused
  {
    require(_to != msg.sender, "LicenseOwnership.disapproveAll(): new owner can't be yourself");
    delete operatorApprovals[msg.sender][_to];
    ApprovalForAll(msg.sender, _to, false);
  }

  /**
  * @notice Claims the ownership of a given token ID
  * @param _tokenId uint256 ID of the token being claimed by the msg.sender
  */
  function takeOwnership(uint256 _tokenId)
   external
   whenNotPaused
  {
    require(isSenderApprovedFor(_tokenId), "LicenseOwnership.takeOwnership(): you are not approved to take ownership");
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
    whenNotPaused
  {
    require(isSenderApprovedFor(_tokenId), "LicenseOwnership.transferFrom(): you are not approved to transfer that token");
    require(ownerOf(_tokenId) == _from, "LicenseOwnership.transferFrom(): 'from' must be the current owner of the token");
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
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  )
    public
    whenNotPaused
  {
    require(_to != address(0), "LicenseOwnership.safeTransferFrom(): 'to' address must be non-zero");
    require(_isValidLicense(_tokenId), "LicenseOwnership.safeTransferFrom(): not a valid license");
    transferFrom(_from, _to, _tokenId);
    if (_isContract(_to)) {
      bytes4 tokenReceiverResponse = ERC721TokenReceiver(_to).onERC721Received.gas(50000)(
        _from, _tokenId, _data
      );
      require(tokenReceiverResponse == bytes4(keccak256("onERC721Received(address,uint256,bytes)")), "LicenseOwnership.safeTransferFrom(): bad response from ERC721 token receiver");
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
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    external
    whenNotPaused
  {
    safeTransferFrom(_from, _to, _tokenId, "");
  }

  /**
  * @notice Mint token function
  * @param _to The address that will own the minted token
  * @param _tokenId uint256 ID of the token to be minted by the msg.sender
  */
  function _mint(address _to, uint256 _tokenId) internal {
    require(_to != address(0), "LicenseOwnership._mint(): 'to' address must be non-zero");
    _addToken(_to, _tokenId);
    Transfer(0x0, _to, _tokenId);
  }

  /**
  * @notice Internal function to clear current approval and transfer the ownership of a given token ID
  * @param _from address which you want to send tokens from
  * @param _to address which you want to transfer the token to
  * @param _tokenId uint256 ID of the token to be transferred
  */
  function _clearApprovalAndTransfer(address _from, address _to, uint256 _tokenId) internal {
    require(_to != address(0), "LicenseOwnership._clearApprovalAndTransfer(): 'to' address must be non-zero");
    require(_to != ownerOf(_tokenId), "LicenseOwnership._clearApprovalAndTransfer(): 'to' address must not be the token's current owner");
    require(ownerOf(_tokenId) == _from, "LicenseOwnership._clearApprovalAndTransfer(): 'from' address must be the token's current owner");
    require(_isValidLicense(_tokenId), "LicenseOwnership._clearApprovalAndTransfer(): not a valid license");

    _clearApproval(_from, _tokenId);
    _removeToken(_from, _tokenId);
    _addToken(_to, _tokenId);
    Transfer(_from, _to, _tokenId);
  }

  /**
  * @notice Internal function to clear current approval of a given token ID
  * @param _tokenId uint256 ID of the token to be transferred
  */
  function _clearApproval(address _owner, uint256 _tokenId) private {
    require(ownerOf(_tokenId) == _owner, "LicenseOwnership._clearApproval(): 'owner' address must be the token's current owner");
    tokenApprovals[_tokenId] = 0;
    Approval(_owner, 0, _tokenId);
  }

  /**
  * @notice Internal function to add a token ID to the list of a given address
  * @param _to address representing the new owner of the given token ID
  * @param _tokenId uint256 ID of the token to be added to the tokens list of the given address
  */
  function _addToken(address _to, uint256 _tokenId) private {
    require(tokenOwner[_tokenId] == address(0), "LicenseOwnership._addToken(): token ID already exists");
    tokenOwner[_tokenId] = _to;
    uint256 length = balanceOf(_to);
    ownedTokens[_to].push(_tokenId);
    ownedTokensIndex[_tokenId] = length;
    totalTokens = totalTokens.add(1);
  }

  /**
  * @notice Internal function to remove a token ID from the list of a given address
  * @param _from address representing the previous owner of the given token ID
  * @param _tokenId uint256 ID of the token to be removed from the tokens list of the given address
  */
  function _removeToken(address _from, uint256 _tokenId) private {
    require(ownerOf(_tokenId) == _from, "LicenseOwnership._removeToken(): 'from' address must be the token's current owner");

    uint256 tokenIndex = ownedTokensIndex[_tokenId];
    uint256 lastTokenIndex = balanceOf(_from).sub(1);
    uint256 lastToken = ownedTokens[_from][lastTokenIndex];

    tokenOwner[_tokenId] = 0;
    ownedTokens[_from][tokenIndex] = lastToken;
    ownedTokens[_from][lastTokenIndex] = 0;
    // Note that this will handle single-element arrays. In that case, both tokenIndex and lastTokenIndex are going to
    // be zero. Then we can make sure that we will remove _tokenId from the ownedTokens list since we are first swapping
    // the lastToken to the first position, and then dropping the element placed in the last position of the list

    ownedTokens[_from].length--;
    ownedTokensIndex[_tokenId] = 0;
    ownedTokensIndex[lastToken] = tokenIndex;
    totalTokens = totalTokens.sub(1);
  }

  function _isContract(address addr) internal view returns (bool) {
    uint size;
    assembly { size := extcodesize(addr) }
    return size > 0;
  }
}
