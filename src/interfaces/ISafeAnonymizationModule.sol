// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ISafeAnonymizationModule {
    function executeTransaction() external;
    function executeTransactionEmitReturnedData() external;
    function setup(address safe, bytes32 participantsRoot, uint256 threshold) external;
}
