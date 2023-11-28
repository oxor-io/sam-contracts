// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Singleton} from "./common/Singleton.sol";
import {ISafeAnonymizationModule} from "./interfaces/ISafeAnonymizationModule.sol";

contract SafeAnonymizationModule is Singleton, ISafeAnonymizationModule {
    //////////////////////
    // State Variables  //
    //////////////////////
    address private s_safe;
    bytes32 private s_participantsRoot;
    uint256 private s_threshold;

    uint256 private s_nonce;
    mapping(bytes32 commit => bool isUsed) private s_isCommitUsed;

    /////////////
    // Events  //
    /////////////
    event Setup(address indexed initiator, address indexed safe, bytes32 initialSetupRoot, uint256 threshold);

    /////////////
    // Errors  //
    /////////////
    error SafeAnonymizationModule__alreadyInitialized();
    error SafeAnonymizationModule__safeIsZero();
    error SafeAnonymizationModule__rootIsZero();
    error SafeAnonymizationModule__thresholdIsZero();

    //////////////////////////////
    // Functions - Constructor  //
    //////////////////////////////
    constructor() {
        s_threshold = 1;
    }

    ////////////////////////////
    // Functions - External  //
    ///////////////////////////
    function setup(address safe, bytes32 participantsRoot, uint256 threshold) external {
        if (s_threshold != 0) {
            revert SafeAnonymizationModule__alreadyInitialized();
        }

        if (safe == address(0)) {
            revert SafeAnonymizationModule__safeIsZero();
        }

        if (participantsRoot == bytes32(0)) {
            revert SafeAnonymizationModule__rootIsZero();
        }

        if (threshold == 0) {
            revert SafeAnonymizationModule__thresholdIsZero();
        }

        s_safe = safe;
        s_participantsRoot = participantsRoot;
        s_threshold = threshold;

        emit Setup(msg.sender, safe, participantsRoot, threshold);
    }

    function executeTransaction() external {}
    function executeTransactionEmitReturnedData() external {}

    //////////////////////////////
    // Functions - View & Pure  //
    //////////////////////////////

    function getSafe() external view returns (address safe) {
        return s_safe;
    }

    function getParticipantsRoot() external view returns (bytes32 root) {
        return s_participantsRoot;
    }

    function getThreshold() external view returns (uint256) {
        return s_threshold;
    }

    function getNonce() external view returns (uint256) {
        return s_nonce;
    }

    function getCommitStatus(bytes32 commit) external view returns (bool isUsed) {
        return s_isCommitUsed[commit];
    }
}
