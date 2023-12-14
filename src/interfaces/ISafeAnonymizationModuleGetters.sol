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

interface ISafeAnonymizationModuleGetters {
    function getSafe() external view returns (address safe);

    function getParticipantsRoot() external view returns (uint256 root);

    function getThreshold() external view returns (uint64 threshold);

    function getNonce() external view returns (uint256 nonce);

    function getCommitStatus(uint256 commit) external view returns (uint256 isCommitUsed);

    function getHashApprovalAmount(bytes32 hash) external view returns (uint256 approvalAmount);

    function getMessageHash(address to, uint256 value, bytes memory data, ISafe.Operation operation, uint256 nonce)
        external
        view
        returns (bytes32 msgHash);
}
