pragma solidity 0.5.0;

import "./ownership/Ownable.sol";
import "./interfaces/IERC20.sol";

contract DAITransactor is Ownable {
  IERC20 daiContract;

  function setDAIContract(address _daiContract) public {
    require(msg.sender == owner());
    daiContract = IERC20(_daiContract);
  }
}
