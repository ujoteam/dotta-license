pragma solidity ^0.5.0;

import "../util/ERC721Receiver.sol";

contract MockTokenReceiver is ERC721Receiver {
	function onERC721Received(address /* operator */, address /* _from */, uint256 /* _tokenId */, bytes memory /*data */)
    public
    returns(bytes4)
  {
    return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }
}
