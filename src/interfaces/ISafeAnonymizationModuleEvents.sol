// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ISafeAnonymizationModuleEvents {
    event Setup(address indexed initiator, address indexed safe, uint256 initialSetupRoot, uint64 threshold);
    event File(bytes32 what, uint256 value);
}
