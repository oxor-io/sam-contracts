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

// Contracts
import {Singleton} from "./Safe/common/Singleton.sol";
import {Groth16Verifier} from "./utils/Verifier.sol";

// Libs
import {PubSignalsConstructor} from "./libraries/PubSignalsConstructor.sol";

// Interfaces
import {ISafeAnonymizationModule} from "./interfaces/ISafeAnonymizationModule.sol";
import {ISafe} from "./Safe/interfaces/ISafe.sol";

/// @title Safe Anonymization Module
/// @author Vladimir Kumalagov (@KumaCrypto)
/// @notice This contract is a module for Safe Wallet (Gnosis Safe), aiming to provide anonymity for users.
/// It allows users to execute transactions for a specified Safe without revealing the addresses of the participants who voted to execute the transaction.
/// @dev This contract should be used as a singleton. And proxy contracts must use delegatecall to use the contract logic.
contract SafeAnonymizationModule is Singleton, ISafeAnonymizationModule {
    ///////////////////////
    //Immutable Variables//
    ///////////////////////

    // Verifier from repository: https://github.com/oxor-io/sam-circuits
    Groth16Verifier private immutable VERIFIER = new Groth16Verifier();

    //////////////////////
    // State Variables  //
    //////////////////////
    ISafe private s_safe;
    // The value of type(uint64).max is large enough to hold the maximum possible amount of proofs.
    uint64 private s_threshold;

    // The root of the Merkle tree from the addresses of all SAM participants (using MimcSpoonge)
    uint256 private s_participantsRoot;
    uint256 private s_nonce;

    mapping(uint256 commit => uint256 isUsed) private s_isCommitUsed;
    mapping(bytes32 msgHash => uint256 amountOfApprovals) private s_hashApprovalAmount;

    //////////////////////////////
    // Functions - Constructor  //
    //////////////////////////////
    constructor() {
        // To lock the singleton contract so no one can call setup.
        s_threshold = 1;
    }

    ///////////////////////////
    // Functions - External  //
    ///////////////////////////

    /**
     * @notice Initializes the contract.
     * @dev This method can only be called once.
     * If a proxy was created without setting up, anyone can call setup and claim the proxy.
     * Revert in case:
     *  - The contract has already been initialized.
     *  - One of the passed parameters is 0.
     * @param safe The address of the Safe.
     * @param participantsRoot The Merkle root of participant addresses.
     * @param threshold The minimum number of proofs required to execute a transaction.
     */
    function setup(address safe, uint256 participantsRoot, uint64 threshold) external {
        if (s_threshold != 0) {
            revert SafeAnonymizationModule__alreadyInitialized();
        }

        // Parameters validation block
        {
            if (safe == address(0)) {
                revert SafeAnonymizationModule__safeIsZero();
            }

            if (participantsRoot == 0) {
                revert SafeAnonymizationModule__rootIsZero();
            }

            if (threshold == 0) {
                revert SafeAnonymizationModule__thresholdIsZero();
            }
        }

        s_safe = ISafe(safe);
        s_participantsRoot = participantsRoot;
        s_threshold = threshold;

        emit Setup(msg.sender, safe, participantsRoot, threshold);
    }

    /**
     * @notice Executes a transaction with zk proofs without returning data.
     * @dev Revert in case:
     *          - Not enough proofs provided (threshold > hash approval amount + amount of provided proofs).
     *          - Contract not initialized.
     *          - One of the proof commits has already been used.
     *          - One of the proof is invalid.
     * @param to The target address to be called by safe.
     * @param value The value in wei to be sent.
     * @param data The data payload of the transaction.
     * @param operation The type of operation (CALL, DELEGATECALL).
     * @param proofs An array of zk proofs.
     * @return success A boolean indicating whether the transaction was successful.
     */
    function executeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) external returns (bool success) {
        (success,) = _executeTransaction(to, value, data, operation, proofs);
    }

    /**
     * @notice Executes a transaction with zk proofs and returns the returned by the transaction execution.
     * @dev Revert in case:
     *          - Not enough proofs provided (threshold > hash approval amount + amount of provided proofs).
     *          - Contract not initialized.
     *          - One of the proof commits has already been used.
     *          - One of the proof is invalid.
     * @param to The target address to be called by safe.
     * @param value The value in wei to be sent.
     * @param data The data payload of the transaction.
     * @param operation The type of operation (CALL, DELEGATECALL).
     * @param proofs An array of zk proofs.
     * @return success A boolean indicating whether the transaction was successful.
     * @return returnData The data returned by the transaction execution.
     */
    function executeTransactionReturnData(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) external returns (bool success, bytes memory returnData) {
        (success, returnData) = _executeTransaction(to, value, data, operation, proofs);
    }

    /**
     * @notice Approves a transaction hash using zk proofs.
     * @dev Increases the approval count of the hash.
     * Revert in case:
     *      - No proofs provided.
     *      - Contract not initialized.
     *      - Transaction with this nonce has already been executed.
     *      - One of the proof commits has already been used.
     *      - One of the proof is invalid.
     * @param to The target address to be called by safe.
     * @param value The value in wei to be sent.
     * @param data The data payload of the transaction.
     * @param operation The type of operation (CALL, DELEGATECALL).
     * @param nonce The nonce used for the transaction.
     */
    function approveHash(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        uint256 nonce,
        Proof[] calldata proofs
    ) external {
        uint256 proofLen = proofs.length;
        if (proofLen == 0) {
            revert SafeAnonymizationModule__proofsLengthIsZero();
        }

        // Do not allow to approve hashes with used nonce
        if (s_nonce > nonce) {
            revert SafeAnonymizationModule__hashApproveToInvalidNonce();
        }

        uint256 root = s_participantsRoot;

        // Check root to prevent calls when contract is not initialized
        if (root == 0) {
            revert SafeAnonymizationModule__rootIsZero();
        }

        (uint256[6] memory pubSignals, bytes32 msgHash) =
            PubSignalsConstructor.getPubSignalsAndMsgHash(root, to, value, data, operation, nonce);

        _checkNProofs(proofs, pubSignals);
        s_hashApprovalAmount[msgHash] += proofLen;

        emit ApproveHash(msgHash, proofLen);
    }

    /**
     * @notice Updates configuration parameters of the contract.
     * Caller must be the Safe wallet associated with this module.
     * @dev Revert in case:
     *      - Caller is not the Safe.
     *      - `Value` is zero.
     *      - `Value` too big for threshold.
     *      - Unrecognized `what`.
     * @param what The parameter to be updated ("threshold" or "root").
     * @param value The new value for the parameter.
     */
    function file(bytes32 what, uint256 value) external {
        if (msg.sender != address(s_safe)) {
            revert SafeAnonymizationModule__notSafe();
        }

        if (value == 0) {
            revert SafeAnonymizationModule__fileArgIsZero();
        }

        if (what == "threshold") {
            if (value > type(uint64).max) {
                revert SafeAnonymizationModule__thresholdIsTooBig();
            }

            s_threshold = uint64(value);
        } else if (what == "root") {
            s_participantsRoot = value;
        } else {
            revert SafeAnonymizationModule__invalidFileParameter(what);
        }

        emit File(what, value);
    }

    //////////////////////////////
    // Functions  -   View      //
    //////////////////////////////

    /// @notice Retrieves the address of the Safe associated with this module.
    /// @return safe The address of the associated Safe.
    function getSafe() external view returns (address safe) {
        return address(s_safe);
    }

    /// @notice Retrieves the current participants root.
    /// @return root The Merkle root of participant addresses.
    function getParticipantsRoot() external view returns (uint256 root) {
        return s_participantsRoot;
    }

    /// @notice Retrieves the threshold number of proofs required for transaction execution.
    /// @return threshold The current threshold value.
    function getThreshold() external view returns (uint64 threshold) {
        return s_threshold;
    }

    /// @notice Retrieves the current nonce value.
    /// @return nonce The current nonce.
    function getNonce() external view returns (uint256 nonce) {
        return s_nonce;
    }

    /**
     * @notice Checks whether a commit has been used.
     * @param commit The commit to check.
     * @return isCommitUsed `1` if the commit has been used, otherwise `0`.
     */
    function getCommitStatus(uint256 commit) external view returns (uint256 isCommitUsed) {
        return s_isCommitUsed[commit];
    }

    /**
     * @notice Retrieves the number of approvals for a given hash.
     * @param hash The hash for which to count the approvals.
     * @return approvalAmount The number of approvals for the hash.
     */
    function getHashApprovalAmount(bytes32 hash) external view returns (uint256 approvalAmount) {
        return s_hashApprovalAmount[hash];
    }

    /**
     * @notice Generates a message hash based on transaction parameters.
     * @param to The target address to be called by safe.
     * @param value The value in wei of the transaction.
     * @param data The data payload of the transaction.
     * @param operation The type of operation (CALL, DELEGATECALL).
     * @param nonce The nonce to be used for the transaction.
     * @return msgHash The resulting message hash.
     */
    function getMessageHash(address to, uint256 value, bytes memory data, ISafe.Operation operation, uint256 nonce)
        external
        view
        returns (bytes32 msgHash)
    {
        return PubSignalsConstructor.getMsgHash(to, value, data, operation, nonce);
    }

    //////////////////////////////
    //   Functions - Private    //
    //////////////////////////////
    function _executeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) private returns (bool success, bytes memory returnData) {
        uint256 root = s_participantsRoot;

        // Check root to prevent calls when contract is not initialized.
        if (root == 0) {
            revert SafeAnonymizationModule__rootIsZero();
        }

        // pubSignals = [commit, root, msg hash by chunks]
        (uint256[6] memory pubSignals, bytes32 msgHash) =
            PubSignalsConstructor.getPubSignalsAndMsgHash(root, to, value, data, operation, s_nonce++);

        uint256 approvalAmount = s_hashApprovalAmount[msgHash];
        if (s_threshold > (proofs.length + approvalAmount)) {
            revert SafeAnonymizationModule__notEnoughProofs(proofs.length, s_threshold);
        }

        _checkNProofs(proofs, pubSignals);

        if (approvalAmount != 0) {
            // This hash will never be used again, since nonce is part of it.
            // Therefore, we can delete the value that is stored to get a refund.
            delete s_hashApprovalAmount[msgHash];
        }

        return s_safe.execTransactionFromModuleReturnData(to, value, data, operation);
    }

    function _checkNProofs(Proof[] calldata proofs, uint256[6] memory pubSignals) private {
        uint256 proofsLength = proofs.length;
        for (uint256 i; i < proofsLength; i++) {
            Proof memory currentProof = proofs[i];

            // Commit must be uniq, because it is a hash(userAddress, msgHash)
            if (s_isCommitUsed[currentProof.commit] != 0) {
                revert SafeAnonymizationModule__commitAlreadyUsed(i);
            }
            s_isCommitUsed[currentProof.commit] = 1;

            pubSignals[0] = currentProof.commit;
            bool result = VERIFIER.verifyProof({
                _pA: currentProof._pA,
                _pB: currentProof._pB,
                _pC: currentProof._pC,
                _pubSignals: pubSignals
            });

            if (!result) {
                revert SafeAnonymizationModule__proofVerificationFailed(i);
            }
        }
    }
}
