pragma solidity 0.5.0;

import "./ownership/Ownable.sol";
import "./interfaces/ERC20.sol";

contract DAITransactor is Ownable {
  ERC20 daiContract;

  function setDAIContract(address _daiContract) public {
    require(msg.sender == owner());
    daiContract = ERC20(_daiContract);
  }
}
