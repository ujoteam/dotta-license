pragma solidity 0.5.0;

import "./util/Ownable.sol";
import "./util/IERC20.sol";

contract DAITransactor is Ownable
{
    IERC20 public daiContract;

    function setDAIContract(address _daiContract) public {
        require(msg.sender == owner());
        daiContract = IERC20(_daiContract);
    }
}
