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
