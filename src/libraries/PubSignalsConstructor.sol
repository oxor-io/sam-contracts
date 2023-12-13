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

import {ISafe} from "../interfaces/Safe/ISafe.sol";

library PubSignalsConstructor {
    // Chosen specifically because it is the most convenient representation of numbers at the moment.
    uint256 private constant CHUNK_SIZE = 64;
    uint256 private constant CHUNK_AMOUNT = 4;
    uint256 private constant MASK = (1 << CHUNK_SIZE) - 1;

    function getMessageHashChunks(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        uint256 nonce
    ) internal view returns (uint256[CHUNK_AMOUNT] memory msgHashChunks) {
        bytes32 calldataHash = keccak256(data);
        bytes32 msgHash = keccak256(abi.encode(to, value, calldataHash, operation, nonce, address(this), block.chainid));

        return splitValueByChunks(uint256(msgHash));
    }

    function splitValueByChunks(uint256 value) private pure returns (uint256[CHUNK_AMOUNT] memory chunks) {
        for (uint256 i; i < CHUNK_AMOUNT; i++) {
            chunks[i] = value & MASK;
            value >>= CHUNK_SIZE;
        }
    }

    function getPubSignals(
        uint256 participantsRoot,
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        uint256 nonce
    ) internal view returns (uint256[6] memory pubSignals) {
        uint256[4] memory msgHashChunks = getMessageHashChunks(to, value, data, operation, nonce);

        pubSignals[1] = participantsRoot;
        for (uint256 i = 2; i < 6; i++) {
            pubSignals[i] = msgHashChunks[i - 2];
        }
    }
}
