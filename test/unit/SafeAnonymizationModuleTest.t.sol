// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SAMSetup, Test, IMinimalSafeModuleManager, SafeAnonymizationModule, ISafe, ArrHelper} from "./SAMSetup.sol";
import {
    ISafeAnonymizationModuleErrors, ISafeAnonymizationModule
} from "../../src/interfaces/ISafeAnonymizationModule.sol";

contract SafeAnonymizationModuleTest is Test, SAMSetup {
    //////////////////////
    //    Constants     //
    //////////////////////
    bytes constant DEFAULT_CALLDATA = abi.encodeWithSignature("getThreshold()");

    //////////////////////
    //    Modifiers     //
    //////////////////////
    modifier enableModuleForSafe(ISafe safeContract, SafeAnonymizationModule module) {
        enableModule(address(safeContract), address(module));
        _;
    }

    //////////////////////
    //      Tests       //
    //////////////////////

    function test_singletonSetupWillRevert() external {
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__alreadyInitialized.selector);
        samSingleton.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }

    // Simply check that setup was ok
    function test_rootIsInitializedCorrectly() external {
        assertEq(sam.getParticipantsRoot(), DEFAULT_ROOT, "Setup failed! Root does not match the default one");
    }

    function test_impossibleToSetupMultiplyTimes() external {
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__alreadyInitialized.selector);
        sam.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }

    // Correct proof must be verified and tx getThreshold executed.
    // Call result must be true and returned data must be equal to default threshold.
    function test_correctProofCanBeVerifiedAndTxExecuted() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        (bool result, bytes memory returnData) = sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(abi.decode(returnData, (uint256)), DEFAULT_THRESHOLD);
    }

    // Invalid proof must fail the verification process, tx must be reverted
    function test_incorrectProofWillRevert() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();
        proof._pA[0] = 0; // Invalidate the proof

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__proofVerificationFailed.selector, 0
            )
        );
        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );
    }

    // If the module enabled and has not passed the setup process it must not execute transaction via wallet.
    function test_moduleWithoutSetupCantCallTheWallet() external {
        SafeAnonymizationModule newSAM = createSAM("", DEFAULT_SALT); // Empty init calldata -> no setup
        enableModule(address(safe), address(newSAM));

        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__thresholdIsZero.selector);
        newSAM.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );
    }

    // Same proof can not be used for twice in different tx.
    // TODO remove this test later, when we will get rid from commits.
    function test_sameProofCantBeUsedTwiceInDifferentTx() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        (bool result, bytes memory returnData) = sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(abi.decode(returnData, (uint256)), DEFAULT_THRESHOLD);

        // First execution is ok, but second must revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__commitAlreadyUsed.selector, 0
            )
        );
        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );
    }

    // This test must not be removed.
    // Same proof can not be used in the same transaction.
    function test_sameProofCantBeUsedTwiceInSameTx() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__commitAlreadyUsed.selector, 1
            )
        );
        sam.executeTransactionReturnData(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            ArrHelper._proofArr(proof, proof)
        );
    }

    // If executor provides amount of proofs less than threshold tx must be reverted.
    function test_notEnoughProofsWillRevert() external enableModuleForSafe(safe, sam) {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__notEnoughProofs.selector, 0, 1
            )
        );
        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr()
        );
    }

    // Verifier contract in bytecode of singleton works fine for all modules.
    function test_sameVerifierContractForAllModulesOk() external {
        uint256 salt = 123456;

        ISafe newSafe = createMinimalSafeWallet(ArrHelper._arr(address(this)), DEFAULT_THRESHOLD, salt);

        // Deploy SAM for newSafe and enable it
        bytes memory initializeDataSAM =
            abi.encodeCall(SafeAnonymizationModule.setup, (address(newSafe), DEFAULT_ROOT, DEFAULT_THRESHOLD));

        SafeAnonymizationModule newSAM = createSAM(initializeDataSAM, salt);
        enableModule(address(newSafe), address(newSAM));

        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x04d393a7603c83c64be89d9c8ba4e986281f5a05e23a12742a74bf8e772b76b2,
                0x1c7ab852608d045a9466d7a8acdd609c738dced2322906d1dd849ae3a964196e
                ),
            _pB: ArrHelper._arr(
                0x23176251315fa9fde2234ff717dd87bf559327b7a20959cbfeef12334165e0dd,
                0x1183cb2f2aabd83177d78d7af669567c22da0279ab4f97442a5146cd9d8e8e6b,
                0x0cc961fa3a2fb2f8d6c80a92ffa2c08a5dc06d28ce4054d830572d98302de53d,
                0x086d7627e9d452710a6040ef9c289dbe97176d267882185c151ff0c8528b610b
                ),
            _pC: ArrHelper._arr(
                0x283a9b58abf3d67aa92ff71f911ca5757b213c990526fc6388829fac3a0e5e2e,
                0x11dd514e8b5481e08595d4c04b3cada59d65dc872ec4b2ed2b043a839b803c0e
                ),
            commit: 0x25db7f52d8edc8cd5f3a08e9521367fd9a86dc1d467362b0af9bdefa2dd81670
        });

        (bool result, bytes memory returnData) = newSAM.executeTransactionReturnData(
            address(newSAM), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(abi.decode(returnData, (uint256)), DEFAULT_THRESHOLD);
    }

    // Since after each contract change, its bytecode changes, and thus previous proofs become invalid.
    // In order not to change the proofs in each test, we will make a default proof.
    function defaultCorrectProof() internal pure returns (ISafeAnonymizationModule.Proof memory) {
        // Proof:
        // Tree constructed from all Anvil addresses
        // From: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (0 Anvil address)
        // Calldata: 0xe75235b8 (getThreshold())
        // Call type: Call
        // Nonce: 0
        // ChainId: 1 (ETH)
        return ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x1b70e7f68fa1d33e9c3f6505fd0b75e08fecca0cfa2b69a4551c1898623bbfda,
                0x02ac77b55d583337054b616e576487b4d85a384c4cb66bd5a131fb33f004a09e
                ),
            _pB: ArrHelper._arr(
                0x2c6aa4fc5fb5e8e08e700d665c5c50d6143bda464cbf22985cb5147535dd2970,
                0x00beaa0a6e4e580d5480d352e9826800750fa40ed872af280d372ae20e1c547a,
                0x2c1d946e0472ee958e00a2f00e9f3da57a6ad095391a7172d416968b5738169f,
                0x289ef7709475c3b858d8b45cd28b3ab0b889377b815c6a2a4dc6b8ea850310ce
                ),
            _pC: ArrHelper._arr(
                0x02e8b0aa466edb599ffb3897407776c23b6b7a63e3f4108d5ccf8126e6575bbf,
                0x0a1f56b50759072b0620d60a4c4a92ecdac5f93c30663ea96ce53786f6526c3c
                ),
            commit: 0x0b7386c6ee5ebefc31a4c1defe57282c00b303394f976224ec87a01bfad562f0
        });
    }
}
