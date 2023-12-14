// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {Setup, Test, IMinimalSafeModuleManager, SafeAnonymizationModule, ArrHelper} from "./Setup.sol";
import {
    ISafeAnonymizationModuleErrors, ISafeAnonymizationModule
} from "../../src/interfaces/ISafeAnonymizationModule.sol";

contract SAMApproveTest is Test, Setup {
    // Check that function can be executed successfully and vote counted
    function test_hashCanBeApproved() external enableModuleForSafe(safe, sam) {
        approveHashWithDefaultProof();
        assertEq(1, sam.getHashApprovalAmount(DEFAULT_TX_HASH));
    }

    // If threshold reached after hash approval, tx can be executed
    function test_txCanBeExecutedAfterHashApproval() external enableModuleForSafe(safe, sam) {
        approveHashWithDefaultProof();
        (bool success, bytes memory data) = sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr()
        );

        assertTrue(success);
        assertEq(sam.getThreshold(), abi.decode(data, (uint256)));
    }

    // Same proof can't be used firstly in approve and after in executeTx
    function test_proofCannotBeUsedTwiceInApproveAndExecute() external enableModuleForSafe(safe, sam) {
        approveHashWithDefaultProof();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__commitAlreadyUsed.selector, 0
            )
        );

        ISafeAnonymizationModule.Proof memory sameProof = defaultCorrectProof();
        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(sameProof)
        );
    }

    // Same proof can't be used twice in approveHash in different transactions
    function test_sameProofCannotBeUsedInApproveDifferentTx() external enableModuleForSafe(safe, sam) {
        approveHashWithDefaultProof();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__commitAlreadyUsed.selector, 0
            )
        );

        approveHashWithDefaultProof();
    }

    // Same proof can't be used twice in approveHash in same transaction
    function test_sameProofCannotBeUsedInApproveSameTx() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__commitAlreadyUsed.selector, 1
            )
        );

        sam.approveHash(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            0,
            ArrHelper._proofArr(proof, proof)
        );
    }

    // Singleton contract can't count votes
    function test_singletonSAMWillRevertApproveWithProofs() external {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__rootIsZero.selector);
        samSingleton.approveHash(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            0,
            ArrHelper._proofArr(proof, proof)
        );
    }

    // Singleton contract will revert with 0 proofs
    function test_singletonSAMWillRevertApproveWithoutProofs() external {
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__proofsLengthIsZero.selector);

        samSingleton.approveHash(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, 0, ArrHelper._proofArr()
        );
    }

    // Not initialized module will revert
    function test_notInitializedModuleCannotCountVotes() external {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        SafeAnonymizationModule newSAM = createSAM("", 1273);
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__rootIsZero.selector);

        newSAM.approveHash(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, 0, ArrHelper._proofArr(proof)
        );
    }

    // Proof for old nonce will revert
    function test_proofForOldNonceWillRevert() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__hashApproveToInvalidNonce.selector);
        approveHashWithDefaultProof();
    }

    // Approve of tx with greater nonce than current will work as expected
    function test_approveFutureNonceAndExTx() external enableModuleForSafe(safe, sam) {
        // Approve future tx
        ISafeAnonymizationModule.Proof memory futureProof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x12c8e7599913a7ac9efe01733772310503d8859bdec0dd814ba81dd2ee94d972,
                0x0e1ea670f4700f3157d30ae5541667de8912e4af91c1d4c73051b585d81da5d7
                ),
            _pB: ArrHelper._arr(
                0x18a9ba235efd4505e48f22123ad0af0e279f1856ada0e4902deaaba481817794,
                0x2a2b376d10224bfe77a31797d13d7974b8c343725cb82360bae49c16733d6734,
                0x214c9bff267fad0037bf0555d07a6978ca9021a7930f5acd64318f36ac165d2c,
                0x0150442a2e0aed60630c0d5837bfe7041a9d285ece2363c89aa9bb9caede81ad
                ),
            _pC: ArrHelper._arr(
                0x2781374a72d49d6fcca5c2f55e1fb6928044e367c29f60db3c8b210dda9b3294,
                0x08a749e19ae662b2fcbafd118a6ac0390002683e90320bef1c7649f129d69562
                ),
            commit: 0x0e34a768e2dc3c4787a9758a53ce8db6d75edc76b2ddf199c25f335d862cc558
        });

        sam.approveHash(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            1,
            ArrHelper._proofArr(futureProof)
        );

        // Increase nonce
        ISafeAnonymizationModule.Proof memory currentProof = defaultCorrectProof();
        sam.executeTransaction(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            ArrHelper._proofArr(currentProof)
        );

        // Execute future tx without proofs, since one already was submitted
        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr()
        );

        // Check that 2 tx was executed
        assertEq(sam.getNonce(), 2);
    }

    function correctProofButForAnotherTxWillNotBeCounted() external {
        ISafeAnonymizationModule.Proof memory incorrectProof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x12c8e7599913a7ac9efe01733772310503d8859bdec0dd814ba81dd2ee94d972,
                0x0e1ea670f4700f3157d30ae5541667de8912e4af91c1d4c73051b585d81da5d7
                ),
            _pB: ArrHelper._arr(
                0x18a9ba235efd4505e48f22123ad0af0e279f1856ada0e4902deaaba481817794,
                0x2a2b376d10224bfe77a31797d13d7974b8c343725cb82360bae49c16733d6734,
                0x214c9bff267fad0037bf0555d07a6978ca9021a7930f5acd64318f36ac165d2c,
                0x0150442a2e0aed60630c0d5837bfe7041a9d285ece2363c89aa9bb9caede81ad
                ),
            _pC: ArrHelper._arr(
                0x2781374a72d49d6fcca5c2f55e1fb6928044e367c29f60db3c8b210dda9b3294,
                0x08a749e19ae662b2fcbafd118a6ac0390002683e90320bef1c7649f129d69562
                ),
            commit: 0x0e34a768e2dc3c4787a9758a53ce8db6d75edc76b2ddf199c25f335d862cc558
        });

        ISafeAnonymizationModule.Proof memory defaultProof = defaultCorrectProof();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__proofVerificationFailed.selector, 1
            )
        );

        sam.approveHash(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            0,
            ArrHelper._proofArr(defaultProof, incorrectProof)
        );
    }

    function test_severalProofsWillBeCountedInApproveHash() external {
        ISafeAnonymizationModule.Proof memory proof1 = defaultCorrectProof();

        ISafeAnonymizationModule.Proof memory proof2 = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x2afe908f83145d802cc3e50369585df7786b3b316b1e516b6733cfb7384dd4c9,
                0x2ba4550b3e1aa1c029a13de50805c514db11dc62013508709d4edbf8703f36c8
                ),
            _pB: ArrHelper._arr(
                0x0db4cba65c38af0bdeb84ed9274c474f5dd444de6e3aae48f1b77e1b8a7bbe7f,
                0x2843d75a220986c1328eabb6134f2095b74f532275e76fad76e77c4e6901d3ad,
                0x2338761769c478c408787c703c6d490764128135f10ebd1da93aca317305eaa5,
                0x037d35a6f23d567e3e5c39122bde4aeab506843ac6e5c971de0bfbbabd2bf2fc
                ),
            _pC: ArrHelper._arr(
                0x21a576b9e3ba508132d69c6335932d7a4587b267c90c16be40d9d2485872c933,
                0x08565baf5c3bdfaf998a8c42fc2669af51cfadce20ba459528d0888fafea243f
                ),
            commit: 0x16a2783612db151d79dcb5f97512328b79f4d171d3309f4fcec04a7f80a5c7cb
        });

        ISafeAnonymizationModule.Proof memory proof3 = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x2ceeedd5933a9eae0a9aaf9ef30b6d2e4ce8ad48268edc08dfd68025ac7c0a69,
                0x1ecff4b9fe0762cbb10473702f4ece7e1cec09f3fc5a82db854ac5569dde1e51
                ),
            _pB: ArrHelper._arr(
                0x190a36696796c11ad9af1f765cc81bde5073ba4b3c0e387d0ee960b148eefdfa,
                0x29ab9befabfeb2a4f6613d94c95839692e33566842e1916d571d1a043c199ab2,
                0x1a50f187086d0299ba491b54d49f5490ee671a7059495bba52b2a77e02a0fb94,
                0x2cbf3700a58b6a260e3d4ee58f929107e99327eb3a14c582fbfc7a24f418bd3c
                ),
            _pC: ArrHelper._arr(
                0x2cb929c15ef202dce1dd73bcd07c28d85ccb1fc3a857324d1ee688d6694e2398,
                0x0e3837c40bf296802ba7b78dd1a0a21563a28600966baa7af1b292ffb085b610
                ),
            commit: 0x200207958b8847abfe300c6eb3441bc3074cbc4d9bf4553153b343a3002547f0
        });

        sam.approveHash(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            0,
            ArrHelper._proofArr(proof1, proof2, proof3)
        );

        assertEq(sam.getHashApprovalAmount(DEFAULT_TX_HASH), 3);
    }

    // Helpers
    function approveHashWithDefaultProof() private {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();
        sam.approveHash(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, 0, ArrHelper._proofArr(proof)
        );
    }
}
