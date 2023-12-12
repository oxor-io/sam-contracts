// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISafe} from "../interfaces/Safe/ISafe.sol";

library PubSignalsConstructor {
    // Chosen specifically because it is the most convenient representation of numbers at the moment.
    uint256 private constant SIZE_OF_CHUNK = 64;
    uint256 private constant AMOUNT_OF_CHUNKS = 4;
    uint256 private constant MASK = (1 << SIZE_OF_CHUNK) - 1;

    function getMessageHashChunks(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        uint256 nonce
    ) internal view returns (uint256[AMOUNT_OF_CHUNKS] memory msgHashChunks) {
        bytes32 calldataHash = keccak256(data);
        bytes32 msgHash = keccak256(abi.encode(to, value, calldataHash, operation, nonce, address(this), block.chainid));

        return splitValueByChunks(uint256(msgHash));
    }

    function splitValueByChunks(uint256 value) private pure returns (uint256[AMOUNT_OF_CHUNKS] memory chunks) {
        for (uint256 i; i < AMOUNT_OF_CHUNKS; i++) {
            chunks[i] = value & MASK;
            value >>= SIZE_OF_CHUNK;
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
