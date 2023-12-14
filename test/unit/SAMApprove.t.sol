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
                0x05dc5b7ef24ecf1c06efdaa127d0173fd2e672f4a3e0bf8e106bd88ed1975d5c,
                0x2180234fde27e43f4eb6da20fc0fb117705593e8affa7b51064066d1b7648ee3
                ),
            _pB: ArrHelper._arr(
                0x22c2e6d65961d673cfc48a6afcf78eca6db52924c8de48ee1fb06e3d5b934bd6,
                0x18a942350d268c5bbac85a0e5e9e23a0a2eb2488b767a42c762ae27885cf6cba,
                0x1770ab1b8ad3007b748164c8880e22ac532c643c8c507e13c5a0a6ed269a0bf1,
                0x144351c649a36414b3bb8526e89aa94364dc18eed608537375d6171fc8df87bb
                ),
            _pC: ArrHelper._arr(
                0x2882f2bd68f8188992d502bf16a0563317365e5b726a491a1da27caef890ddb2,
                0x10f27f40e23e66d07c7609ac6093a72a855864456f3f704c8487d3b293adc049
                ),
            commit: 0x21a1f4b4f3e94b4dc202dc298125439d7a146f6a9e93a60b004146ff5bf61768
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
                0x0ecd13086204dddf2ac7edfa0419f2fc401e9899a0657e8437ff3815b496110f,
                0x1e04b1eaf368c1c4e0aa9b34df492b545c6a28996dad067f1283c79283a13ee3
                ),
            _pB: ArrHelper._arr(
                0x077c2e81d9800d48550a80c2c45f481d1b35f1aa99789d09c4a33edbfd96d4a5,
                0x2e1ba3045ed604ba28a6ce2410b4b25c8c964df41648c36639795aea586e7860,
                0x0fd310057418bb526c799fd4eb0362b89012aa1a4bc08c70a97e15ceffaea0d3,
                0x10121c8b918f599819d298be0343d66ea0027f2128e667e7bc62513c4c4c692e
                ),
            _pC: ArrHelper._arr(
                0x07435c5070977a01eb1fe4eff4982a8e0c93204b2912c0d0d62365d1ef9f77d9,
                0x2fdac2e8388a96e3bb3ff08d14064ed3f44fa2df404bc079d7169236ff466171
                ),
            commit: 0x1d20b7b575c3903469ff41ab51e2c2bf7ec981010f38e94dab0b8d778b32cbf6
        });

        ISafeAnonymizationModule.Proof memory proof3 = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x12fcb89427012748f66079c1614eb121ed5253ac2703a22197391001eefeb05e,
                0x1daef9d52b95c9dc7e5b91d3979faa878ba729c3937e1e429bce03b3c7a71277
                ),
            _pB: ArrHelper._arr(
                0x1fe06d5ce9fcc00f1ba957ef84bf1146ae99870d37f6d6040141713720b31b2c,
                0x093eb62073e993b10f5f24daa653579e0a71be532700ff2e92c3693d4c712987,
                0x13a46812c6d2a63761437cea937eaa0237e940c954fc898841828918dca41076,
                0x2d529cc9f6515297af64da1a9da899b9ca776160ceba2586925014db5b4b95a9
                ),
            _pC: ArrHelper._arr(
                0x26e67a61d9e189a17ccb8d1fc321eea0358f8c6deba812fd50379881a460a5e8,
                0x063652af8ad04ed983aebfbf9b18b538cc9ce4a8dd4d5e8f8d99cd37c32f4c69
                ),
            commit: 0x19a2a0746431ec206a56a9c4c4ac8ef3eaed7b251b0309d4c0b59cbdca4d31a6
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
