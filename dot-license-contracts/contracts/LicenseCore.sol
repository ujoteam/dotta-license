pragma solidity 0.5.0;

import "./LicenseOwnership.sol";

/**
 * @title LicenseCore is the entry point of the contract
 * @notice LicenseCore is the entry point and it controls the ability to set a new
 * contract address, in the case where an upgrade is required
 */
contract LicenseCore is LicenseOwnership {
  address public newContractAddress;

  /**
   * @notice ContractUpgrade is the event that will be emitted if we set a new contract address
   */
  event ContractUpgrade(address newContract);

  function setNewAddress(address _v2Address) external onlyOwner whenPaused {
    newContractAddress = _v2Address;
    emit ContractUpgrade(_v2Address);
  }

  function() external {
    assert(false);
  }

  function unpause() public onlyOwner whenPaused {
    require(newContractAddress == address(0));
    super.unpause();
  }
}
