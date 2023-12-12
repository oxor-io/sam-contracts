// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ISafeAnonymizationModuleErrors {
    error SafeAnonymizationModule__alreadyInitialized();
    error SafeAnonymizationModule__safeIsZero();
    error SafeAnonymizationModule__rootIsZero();
    error SafeAnonymizationModule__thresholdIsZero();
    error SafeAnonymizationModule__notEnoughProofs(uint256 amountOfGivenProofs, uint256 threshold);
    error SafeAnonymizationModule__commitAlreadyUsed(uint256 usedCommitIndex);
    error SafeAnonymizationModule__proofVerificationFailed(uint256 failedProofIndex);
    error SafeAnonymizationModule__notSafe();
    error SafeAnonymizationModule__fileArgIsZero();
    error SafeAnonymizationModule__invalidFileParameter(bytes32 what);
}
