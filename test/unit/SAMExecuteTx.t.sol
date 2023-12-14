// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {Setup, Test, IMinimalSafeModuleManager, SafeAnonymizationModule, ISafe, ArrHelper} from "./Setup.sol";
import {
    ISafeAnonymizationModuleErrors, ISafeAnonymizationModule
} from "../../src/interfaces/ISafeAnonymizationModule.sol";

import {SimpleContract} from "../helpers/SimpleContract.sol";
import {SimpleContractDelegateCall} from "../helpers/SimpleContractDelegateCall.sol";

contract SAMExecuteTxTest is Test, Setup {
    // Correct proof must be verified and tx getThreshold executed.
    // Call must be successful and returned data correct
    function test_correctProofCanBeVerifiedAndTxExecutedReturnData() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        (bool result, bytes memory returnData) = sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(abi.decode(returnData, (uint256)), DEFAULT_THRESHOLD);
    }

    // Same with the test above, but with another function.
    // Call must be successful.
    function test_correctProofCanBeVerifiedAndTxExecuted() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        (bool result) = sam.executeTransaction(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
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

        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__rootIsZero.selector);
        newSAM.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );
    }

    // Same proof can not be used for twice in different tx.
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
                0x02dc0527c299eb8e40c4146132cb0220e5ca8365c67b1c087200ca7330cc7911,
                0x302a3b0fcbcb5e3a131a281b6bb847c3e137e976e4a131793ba67e5181a291af
                ),
            _pB: ArrHelper._arr(
                0x163c03a61b350f56d838a4a14998052ee87ac15f620b1f73af5008443bbbc8d1,
                0x2630a094fc2ac048b2d389633531ed56aaeab7a6283db35231219219b1e348e8,
                0x27bd74febbcc23cfb72d07141d649bee9b6cb4e9f74aee9378fe27546c6e6aac,
                0x275eb36a2ca228aa5e50f64cad67277a984e24213d3e4d9f712421e4be2fe0ff
                ),
            _pC: ArrHelper._arr(
                0x1f89971430280a4ec77219388c5375c8bcc3c81f36d3f421a319315f602719b0,
                0x1c51f3c808f1fd78cce5518e70e6c87786af149ce212e7da2d0a5ffb459ddeeb
                ),
            commit: 0x03677670c1fa50a33b4b697942dbfab3d2c170fef219b0d16ec7418504973795
        });

        (bool result, bytes memory returnData) = newSAM.executeTransactionReturnData(
            address(newSAM), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(abi.decode(returnData, (uint256)), DEFAULT_THRESHOLD);
    }

    // File can not be called not from {self} account
    function test_fileWillRevertIfNotSafe() external {
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__notSafe.selector);
        sam.file("root", 1);
    }

    // File can not be called not from {self} account.
    function test_fileCanNotChangeValueToZero() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x16816f68966932e94955ab2d08379173069f4008b24bc0239a90521b95201cf4,
                0x14ffdab6d474167573cb626d746d15976f4e03e7dc553e7a16cac553e1739f52
                ),
            _pB: ArrHelper._arr(
                0x1c1e7644fa09d9cc7e211da608bf22bc8a35a366f74aa854881fad2a0a9e1dca,
                0x1c10ad3e9c52a5c319cf9709959126b85ece1be55ff3f713c7095ea26530eb65,
                0x215344f418a736347e9f4a2e6a56072e37978ac925110f5cbed6b3c96d9e9e97,
                0x077e27fe9a350e6304b3346ca16b4470b0a1f9036084781a31ca37b58f51279b
                ),
            _pC: ArrHelper._arr(
                0x08413b035c274fd509a1426ad486b925e96598a2a1bd30b417603741979f20c9,
                0x2e3001a1cdc71a180caa12e493ad2060331ee7d3314e3b163eefc7f9dc658bc8
                ),
            commit: 0x1727678219936e164f33c3b5e3c6684d661b6b21dcd362125d3e6dd17491338c
        });

        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("root", 0));

        (bool success, bytes memory data) = sam.executeTransactionReturnData(
            address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertFalse(success);
        assertEq(
            abi.encodeWithSelector(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__fileArgIsZero.selector), data
        );

        assertEq(sam.getThreshold(), DEFAULT_THRESHOLD);
        assertEq(sam.getParticipantsRoot(), DEFAULT_ROOT);
    }

    // If what is unknown file must revert.
    function test_fileWillRevertWithUnknownWhat() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x24641742649deef84d3311a2b4e53101218c069687a403776f285822f82b3411,
                0x1a548144bd535cc45bf15059da87593af8c22e4c71131b62f52cd199a3fa80e9
                ),
            _pB: ArrHelper._arr(
                0x1a4e5fd383146da92940408b35ce89f63f36f9c39c3013d426c1c4c867389714,
                0x2dabecf653a3f51d71cdcc9545555ebdde6d06141953f215275b7b6130c3fa11,
                0x29c5b1a8960c66652434e5c834d6a142c80c5d8cb1b9aa4d8636de80d3960b23,
                0x1a7fcaca129b3ff8d8c853f5165d3ec9136cf2095b01a4d17710fdc3da299ff9
                ),
            _pC: ArrHelper._arr(
                0x04b1d53a004b4db57d12cb885cd71ce0192f143be49b4c523e28cbe4bbdf7838,
                0x0918c369526aeb9007bbd1052c59a5204945a76fd35aa366d780ff9ab1497304
                ),
            commit: 0x2bf7bb19a7fe26e6058308a62a8b70ef6f926b8e38b5245a483935019b4f9ab6
        });

        bytes32 what = "QWERTY";
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, (what, 12345));

        (bool success, bytes memory data) = sam.executeTransactionReturnData(
            address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertFalse(success);
        bytes memory revertData = abi.encodeWithSelector(
            ISafeAnonymizationModuleErrors.SafeAnonymizationModule__invalidFileParameter.selector, what
        );
        assertEq(revertData, data);
        assertEq(sam.getThreshold(), DEFAULT_THRESHOLD);
        assertEq(sam.getParticipantsRoot(), DEFAULT_ROOT);
    }

    // If SAM is call file with threshold argument - value must be changed.
    function test_fileCanChangeThreshold() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x19f844c422fe9e84c1bca2aa175351ab2af221dffeeedf024f2ec98c046a4e25,
                0x075fb3c24d7f3ceb4809f8be21758e6261a373f6cc8572c8d4634a986a58af28
                ),
            _pB: ArrHelper._arr(
                0x20e03e9111f85d217301af6268486d6fd9630b71cd23c86d298960b2caf295b0,
                0x13035c429a3a2345a665c78e5a0194be18494c479564153cd1a199368e149863,
                0x01933bf881f3c06ece6c39f70c8f0e15539058243abb8fbcee30796fa9f0eb11,
                0x0db43dabfec9a37f5320af2d779c6ab29b246db6412e2bde5d8945cf46259612
                ),
            _pC: ArrHelper._arr(
                0x26514dbf495f13a015408d69f4450ccd755fa9ebc668d45f7665cf8e49ba860f,
                0x09f47ebc6929b9f5f017e7db1f4d46458d72ad204104aa352cfe8c6eb00e5f09
                ),
            commit: 0x13df9e8388e0262957b0dea2b3573e39b27e1e734e2aab68f4c43d7061d04ed0
        });

        uint256 newThreshold = 2;
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("threshold", newThreshold));

        (bool result,) = sam.executeTransactionReturnData(
            address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(sam.getThreshold(), newThreshold);
    }

    // If SAM is call file with threshold argument - value must be changed.
    function test_fileCanChangeRoot() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x23e737b3bc34b1450937dd13ad834801623da3e3e991d3429dc19c637809f696,
                0x0372257a38469e8613f67f1c272fe90bb10e9a79a92174ca7737134b8670a5da
                ),
            _pB: ArrHelper._arr(
                0x1154d448fd582863e48e5780bd67da6682e1b2832b5ca67f7c52a8aa872a0530,
                0x07899f9bdf2fafcf861279bbd3017306533ace41c541c2550bb2a414a7136625,
                0x1425072f8b24ebc70c4c928c79dccbc3fc19760b18074e11f45905d6485cc1be,
                0x1e3f9079b16075d43c01a141da38b33d5259e199a1b109706e18e8cefa7061b8
                ),
            _pC: ArrHelper._arr(
                0x0f526faf75b3ed410184e6f2aecd4549838e1818c9bf874dcd0dc68f354a2dd0,
                0x2744ddfe67c7622f14ac5d41838cdddff2391e7b8e52e7a91fa704353928446e
                ),
            commit: 0x1357ca0b271d0a4afd21d926d41c735cf882f63d810e063a8cd3dcfce6ccee51
        });

        uint256 newRoot = 2;
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("root", newRoot));

        (bool result,) = sam.executeTransactionReturnData(
            address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(sam.getParticipantsRoot(), newRoot);
    }

    // SAM must be able to initiate Safe to delegatecall external contract.
    function test_walletCanDelegateCallExternalContractFromModuleCall() external enableModuleForSafe(safe, sam) {
        SimpleContractDelegateCall target = new SimpleContractDelegateCall();

        uint256 value = 777;
        bytes memory cd = abi.encodeCall(SimpleContractDelegateCall.call, (value));

        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x14656ecdd85525870c6f6b56ba87a457dc818d51a2e842aaf9b3056127805ad1,
                0x2b9c0a5697ddfc2c5532fda4c122f191fb02b9a3ac9e240f1a408b8a153c77fd
                ),
            _pB: ArrHelper._arr(
                0x068e54761e1b43bd721f0314c6d4a2f82bd5419ee929b896c26e2790994dbf01,
                0x0a06ff3cd3c0b594ad70fe9f4e8c7f82b16bf8a179a4b82089906f720f9664c3,
                0x141371a5f6347d8ad66ff0a333cd1667bc39838cdecf913b9d20a4659dd806e3,
                0x2a2ef71cc3b34ee66247299b0b67f991efd959aa2560ffb1806f41c0777d28de
                ),
            _pC: ArrHelper._arr(
                0x18b36abae279d0c7ac69c3875ebf499d1053c314677ba683ac14a71aaa319efa,
                0x2ce14cb95d2226e0772b02268b36c9f8188857579a6e952bfe922832f6aae081
                ),
            commit: 0x2b844e81e9d83eda1d3106326d3a8d30f06f639de2abb59d3166623cda5ff165
        });

        (bool result,) = sam.executeTransactionReturnData(
            address(target), 0, cd, IMinimalSafeModuleManager.Operation.DelegateCall, ArrHelper._proofArr(proof)
        );

        assertTrue(result);

        bytes32 valueFromSlot = vm.load(address(safe), bytes32(target.MAGIC_SLOT()));
        assertEq(uint256(valueFromSlot), value);
    }

    // SAM must be able to initiate Safe to call external contract.
    function test_walletCanCallExternalContractFromModuleCall() external enableModuleForSafe(safe, sam) {
        SimpleContract target = new SimpleContract();

        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x2753d002cb25c73b2b8e9dea21f7c7cf7aecaddd15f4ab619b4e0c32c29d35b6,
                0x14d67e5df41ebe0c7ec27fbc445cd2dafc0d603d58eaa79446f6269fe0b4dc42
                ),
            _pB: ArrHelper._arr(
                0x1cf2a46e12bc12213166b0c3c1ca97f9ca5ff1f4cf90abc044753662146104e2,
                0x058d323696933638c4a4dd5597398661dc7df006ef6c3199e2f22171ec79c808,
                0x034bfc5f0cb14800dc1d4ae38897fe62eb0c77a532a0b4db40a75748111b0d8e,
                0x01693e93170a172b6b318a1f79e313549a67c329b906ce97a3b794432a6a01c7
                ),
            _pC: ArrHelper._arr(
                0x077cfde9ef62e5c7d1fcd243380c63cddc434d2af2efdb89f2a62e497ae20e6b,
                0x0387d99d56caffff0c2e39bfadec8538c7ddf7d9f2ff4500a60eed70deb92650
                ),
            commit: 0x05bc0da9e8811fd302ada9ed9ec4c9d810b886a73e81ce388800381f06e60e44
        });

        bytes memory cd = abi.encodeCall(SimpleContract.call, ());

        (bool result,) = sam.executeTransactionReturnData(
            address(target), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertTrue(target.getMagicValue(address(safe)));
    }

    // Safe Wallet can directly set parameters in SAM.
    function test_walletCanSetParamsDirectly() external enableModuleForSafe(safe, sam) {
        uint256 newValue = 999;

        // Try to set threshold
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("threshold", newValue));

        sendTxToSafe(address(safe), address(this), address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, 1e5);
        assertEq(sam.getThreshold(), newValue);

        // Try to set root
        cd = abi.encodeCall(SafeAnonymizationModule.file, ("root", newValue));

        sendTxToSafe(address(safe), address(this), address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, 1e5);
        assertEq(sam.getParticipantsRoot(), newValue);
    }

    // Root change must invalidate all old proofs which was not used.
    function test_afterRootChangeOldProofsCanNotBeUsed() external enableModuleForSafe(safe, sam) {
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("root", 100));
        sendTxToSafe(address(safe), address(this), address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, 1e5);

        ISafeAnonymizationModule.Proof memory proof = defaultCorrectProof();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeAnonymizationModuleErrors.SafeAnonymizationModule__proofVerificationFailed.selector, 0
            )
        );
        sam.executeTransactionReturnData(
            address(sam), 0, DEFAULT_CALLDATA, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );
    }

    // When threshold is bigger than 1, multiple proofs can be verified and tx executed
    function test_multipleProofsCanBeVerifiedAndTxExecuted() external enableModuleForSafe(safe, sam) {
        // Set threshold to 3
        uint256 newThreshold = 3;
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("threshold", newThreshold));
        sendTxToSafe(address(safe), address(this), address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, 1e5);

        // Prepare proofs and execute tx
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

        (bool result, bytes memory data) = sam.executeTransactionReturnData(
            address(sam),
            0,
            DEFAULT_CALLDATA,
            IMinimalSafeModuleManager.Operation.Call,
            ArrHelper._proofArr(proof1, proof2, proof3)
        );

        assertTrue(result);
        assertEq(abi.decode(data, (uint256)), newThreshold);
    }
}
