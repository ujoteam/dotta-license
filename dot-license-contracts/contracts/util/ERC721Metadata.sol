pragma solidity 0.5.0;

import "./ERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721Metadata is ERC721 {
    string public name;
    string public symbol;
    // function name() external view returns (string memory);
    // function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}