// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISafe} from "./Safe/ISafe.sol";
import {ISafeAnonymizationModuleEvents} from "./ISafeAnonymizationModuleEvents.sol";
import {ISafeAnonymizationModuleErrors} from "./ISafeAnonymizationModuleErrors.sol";

interface ISafeAnonymizationModule is ISafeAnonymizationModuleEvents, ISafeAnonymizationModuleErrors {
    struct Proof {
        uint256[2] _pA;
        uint256[2][2] _pB;
        uint256[2] _pC;
        uint256 commit;
    }

    function setup(address safe, uint256 participantsRoot, uint64 threshold) external;

    function executeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) external returns (bool success);

    function executeTransactionReturnData(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) external returns (bool success, bytes memory returnData);
}
