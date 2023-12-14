// SPDX-License-Identifier: GPL-3
/**
 *     Safe Anonymization Module
 *     Copyright (C) 2023 OXORIO-FZCO
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity 0.8.23;

import {ISafe} from "../Safe/interfaces/ISafe.sol";
import {ISafeAnonymizationModuleEvents} from "./ISafeAnonymizationModuleEvents.sol";
import {ISafeAnonymizationModuleErrors} from "./ISafeAnonymizationModuleErrors.sol";
import {ISafeAnonymizationModuleGetters} from "./ISafeAnonymizationModuleGetters.sol";

interface ISafeAnonymizationModule is
    ISafeAnonymizationModuleEvents,
    ISafeAnonymizationModuleErrors,
    ISafeAnonymizationModuleGetters
{
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

    function approveHash(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        uint256 nonce,
        Proof[] calldata proofs
    ) external;

    function file(bytes32 what, uint256 value) external;
}
