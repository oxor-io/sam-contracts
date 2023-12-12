// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Contracts
import {Singleton} from "./common/Singleton.sol";
import {Groth16Verifier} from "./utils/Verifier.sol";

// Libs
import {PubSignalsConstructor} from "./libraries/PubSignalsConstructor.sol";

// Interfaces
import {ISafeAnonymizationModule} from "./interfaces/ISafeAnonymizationModule.sol";
import {ISafe} from "./interfaces/Safe/ISafe.sol";

contract SafeAnonymizationModule is Singleton, ISafeAnonymizationModule {
    ///////////////////////
    //Immutable Variables//
    ///////////////////////
    Groth16Verifier private immutable VERIFIER = new Groth16Verifier();

    //////////////////////
    // State Variables  //
    //////////////////////
    ISafe private s_safe;
    uint64 private s_nonce;

    uint256 private s_participantsRoot;
    uint256 private s_threshold;

    mapping(uint256 commit => uint256 isUsed) private s_isCommitUsed;

    //////////////////////////////
    // Functions - Constructor  //
    //////////////////////////////
    constructor() {
        s_threshold = 1;
    }

    ///////////////////////////
    // Functions - External  //
    ///////////////////////////
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

    function executeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) external returns (bool success) {
        (success,) = _executeTransaction(to, value, data, operation, proofs);
    }

    function executeTransactionReturnData(
        address to,
        uint256 value,
        bytes memory data,
        ISafe.Operation operation,
        Proof[] calldata proofs
    ) external returns (bool success, bytes memory returnData) {
        (success, returnData) = _executeTransaction(to, value, data, operation, proofs);
    }

    //////////////////////////////
    // Functions - View & Pure  //
    //////////////////////////////

    function getSafe() external view returns (address safe) {
        return address(s_safe);
    }

    function getParticipantsRoot() external view returns (uint256 root) {
        return s_participantsRoot;
    }

    function getThreshold() external view returns (uint256 threshold) {
        return s_threshold;
    }

    function getNonce() external view returns (uint256 nonce) {
        return s_nonce;
    }

    function getCommitStatus(uint256 commit) external view returns (uint256 isCommitUsed) {
        return s_isCommitUsed[commit];
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
        uint256 threshold = s_threshold;
        if (threshold == 0) {
            revert SafeAnonymizationModule__thresholdIsZero();
        }

        if (threshold > proofs.length) {
            revert SafeAnonymizationModule__notEnoughProofs(proofs.length, threshold);
        }

        // 0 slot is reserved for commits
        uint256[6] memory pubSignals =
            PubSignalsConstructor.getPubSignals(s_participantsRoot, to, value, data, operation, s_nonce++);

        for (uint256 i; i < proofs.length; i++) {
            Proof memory currentProof = proofs[i];

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

        return s_safe.execTransactionFromModuleReturnData(to, value, data, operation);
    }
}
