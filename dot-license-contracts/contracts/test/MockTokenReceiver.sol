pragma solidity ^0.5.0;

import "../interfaces/ERC721Receiver.sol";

contract MockTokenReceiver is ERC721Receiver {
	function onERC721Received(address /* _from */, uint256 /* _tokenId */, bytes calldata /*data */)
    external
    returns(bytes4)
  {
    return bytes4(keccak256("onERC721Received(address,uint256,bytes)"));
  }
}
