// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {SAMSetup, Test, IMinimalSafeModuleManager, SafeAnonymizationModule, ISafe, ArrHelper} from "./SAMSetup.sol";
import {
    ISafeAnonymizationModuleErrors, ISafeAnonymizationModule
} from "../../src/interfaces/ISafeAnonymizationModule.sol";
import {SimpleContract} from "../helpers/SimpleContract.sol";
import {SimpleContractDelegateCall} from "../helpers/SimpleContractDelegateCall.sol";

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

    // File can not be called not from {self} account
    function test_fileWillRevertIfNotSafe() external {
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__notSafe.selector);
        sam.file("root", 1);
    }

    // File can not be called not from {self} account.
    function test_fileCanNotChangeValueToZero() external enableModuleForSafe(safe, sam) {
        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x04218f39e325c86aa520bfbe646886969b0805dcfe46d377d12155cb0950aa6e,
                0x17c290d031fe7fdc34e3f5422df2136e65d22874ae46728070e76f137b42e099
                ),
            _pB: ArrHelper._arr(
                0x05439d03f1faf21cea7f868dfd5dc21f00e288aca0c6c4d048b1084dc0ed936d,
                0x225afb8f9415100cce1ee0a988c8a426fc81cb8759aed43eb4a9c8aa893e7270,
                0x2bf07fd5eb88cd5b403fd83c9982d0e17975f947a72a6297ee26be35f3b41a72,
                0x177bbb2b4c32d5bf7dba8e52d3c9451de3f8c8374469a62b46b379815d6952a2
                ),
            _pC: ArrHelper._arr(
                0x295c26867b0f4fc348733ecf07d7123e3c7044e1fc7dd7b52f9afabfae6e3d17,
                0x09e6c80d094b83701274efc4fde160e0ca6f3beb5cc597dbd2e27a071a4aa39e
                ),
            commit: 0x1b80684a12d80a190cb01aa9601534d89c8f8202c0524118ecf9536f58e21c2a
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
                0x09720043b473e65dc14abf0780d15fe03036e0ed746f05b3b2f701ae3db013ea,
                0x1c202e773e1efc6ec8f267cef6fc50c21b1e9b3016ae543ecf1497853a8b70e6
                ),
            _pB: ArrHelper._arr(
                0x056c22f2a360679e0c52c875ba826b17127fd018852d6f395564d9de376a3536,
                0x11889a6d60e239f218b1acf65443187462df335b1903bca7f7c3fb23dfd807f3,
                0x04ea2e9b750352b3f0f228a9028f00d323c61ead0a82b29d96db686a46b71f80,
                0x03a7704d23635e877857c962537c8323a33daeb8687c004191051d0d7089bc24
                ),
            _pC: ArrHelper._arr(
                0x07d1e469aa31c8a8057ba7aecdf6c9be4ecbba82232c6c23062e263672b4bb71,
                0x227f92a80f78e104595673753fdaf3f43a41d75218d2897ccf4d8d6a4ce46f7c
                ),
            commit: 0x0de30072291e5d374a5ef963015ff9e0362f5bf980c0a4a34082f7c4fa9ce457
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
                0x2789dab844fbba0bd22bec652dd5fa1c626df159d48ec72594f49d0024bd049b,
                0x2e102c0a153914f26fa17bdb47356d1fe3850c748160b1430cc622f4347cef12
                ),
            _pB: ArrHelper._arr(
                0x00b11de2fb820baf85e6f3b74cf2588997df34f70f2174d9ab1cfa21a30e3808,
                0x0605abb6e3f476f850b3d640d11dfb6879445c6625374db2bc01d4d2e84b3401,
                0x190867512863dec7fd6a101b2aeb3d93a2b20f87537fa9ed1d498d19eeeae7ca,
                0x13b58ad387b1072253ab66b052a8d255989c1a997e31447f210c06148c070cd4
                ),
            _pC: ArrHelper._arr(
                0x22b3c2cb8baee286c2e9a765c618514e64c05a58e3b068940de5e31938138839,
                0x24ada268ad6ae805b034dae87a8132b4edc6199856d317914eb4755d49847b14
                ),
            commit: 0x03c4379fe6c22ba3135e0cb7f5ea7d2bacc0dde7bd6daeae391512cd468c111b
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
                0x2fe94e80c6914433e7472551d4ed4818fee3e28b698222095633cc37920ffcf0,
                0x0619973663f58e7535b7fee01690d7e50c7965a4ba6bf23e0c93835595c62fa8
                ),
            _pB: ArrHelper._arr(
                0x0f338d4fca9b0d50126b9d7f2712ef86430ca0669f855bb82f41241baeffe475,
                0x067b1d90b83c5a2eb7134400f2a8c6622e024993f6e1d3c43525ba1a04a99485,
                0x297a022b4abc122733775d0ed562615ff6c7c1f76e49a34f55de98a5a6a726a9,
                0x05b1e22c1d35d0e64df24a18b42f1ec403fd2f028e104fb4cbb74c7e7ece4ad2
                ),
            _pC: ArrHelper._arr(
                0x006bbdadb45d9c9b8c8b9bb85fd848ed1a9fd32670df81fd28cf052a89683311,
                0x1249f1fa25901448999f8652b73f6f29a16765a7cc571148e1c84ee54f5c8f59
                ),
            commit: 0x2f700cf514b7ff9d1c7483c848bc593255a65bd24e0f41f203b9ce4ad04d816e
        });

        uint256 newRoot = 2;
        bytes memory cd = abi.encodeCall(SafeAnonymizationModule.file, ("root", newRoot));

        (bool result,) = sam.executeTransactionReturnData(
            address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(sam.getParticipantsRoot(), newRoot);
    }

    // SAM must be able to initiate Safe to call external contract.
    function test_walletCanCallExternalContractFromModuleCall() external enableModuleForSafe(safe, sam) {
        SimpleContractDelegateCall target = new SimpleContractDelegateCall();

        uint256 value = 777;
        bytes memory cd = abi.encodeCall(SimpleContractDelegateCall.call, (value));

        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x2ae8c0e564bea51560cc55c41056c442760ea496369c8d69e68408d28f7f514e,
                0x14108a1f3fbebe9ccb567ecccc63105c453846207986306c8c06039422a6caa7
                ),
            _pB: ArrHelper._arr(
                0x0747dbc19c193042b54e36c6cd88ed1b9754ff71b690e4450a89c0bba6b8398a,
                0x0a6e35fd76c01c60e29284e9f6907bda608d237d64212776ee6894019e2ad156,
                0x06820c09302ba57c3e0cba20db4ef50cb5b5d1afe7155ca55ee7a228ef35accf,
                0x09b2d35413b612f287122bb79e13e8912e59de88de463d15aebba3049a3db88f
                ),
            _pC: ArrHelper._arr(
                0x0d459d84bb97350be499105cadc10d827c272325efc2974a76ce27580e7ffc6d,
                0x0ea8fa1e86fe0f7c2af371585788adddfb6cf9b98706c46db1e323fbaf80bfbd
                ),
            commit: 0x23a86b8311583d078cdb725ca8cecd657d7ddac6e3ee39136550cf2be235d60b
        });

        (bool result,) = sam.executeTransactionReturnData(
            address(target), 0, cd, IMinimalSafeModuleManager.Operation.DelegateCall, ArrHelper._proofArr(proof)
        );

        assertTrue(result);

        bytes32 valueFromSlot = vm.load(address(safe), bytes32(target.MAGIC_SLOT()));
        assertEq(uint256(valueFromSlot), value);
    }

    // SAM must be able to initiate Safe to delegatecall external contract.
    function test_walletCanDelegateCallExternalContractFromModuleCall() external enableModuleForSafe(safe, sam) {
        SimpleContract target = new SimpleContract();

        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
            _pA: ArrHelper._arr(
                0x1557bc54edd29ca7cdd4cec48830e4e29129573df8efe294660f63d40b3930ab,
                0x01b0887199beb15461ab3051701f96fa8fd69a7071ac5489480b0525a53c707f
                ),
            _pB: ArrHelper._arr(
                0x25e41aa0c41d2b2118f84088ab00820acf663c1f16ba4fa349b07df84001eea3,
                0x1ce7db95df0385eb8e790f575bc0e596438116253b3001e38b1c11188630f9ee,
                0x2cd7af43839a8aa14c2216363c880ba4b5a03749a73fe9ade052740006d96eb9,
                0x281e2c70a576f9d63dc56d862e7ee6b28316aa697fe21bf3920a09835f67671b
                ),
            _pC: ArrHelper._arr(
                0x177492e52d1e0bdebfc9afc8cfd0dbdcdae6b899a1dddb2a43c54840a3cc1347,
                0x0aa7ae884e68cdc2bd0abdeb9c21efb9b32312777061f889c404906ee2a04615
                ),
            commit: 0x21942c5132c58db5ba6f4b89f0d533b30f292f2b29b6d3d4372287e7346d35ce
        });

        bytes memory cd = abi.encodeCall(SimpleContract.call, ());

        (bool result,) = sam.executeTransactionReturnData(
            address(target), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertTrue(target.getMagicValue(address(safe)));
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
                0x221b220a3eca8ed6ee64bf14fa7353240bb3ef375a669f849c49b25205997af2,
                0x0b6e9cc2d6c1ab8aabe89eb60d4c6b24821ce1f0341e3cd80f4ee1f502292f7b
                ),
            _pB: ArrHelper._arr(
                0x253cfc6a0f1d54822fabd747099cd0ddbb4e9bd7d27c5f2b7291c0eb8cad5669,
                0x16d7975e4dc8a529379f86fe624bea93b77e568f8de31228cfddbd27e5c85319,
                0x14da807174eabec09b20f428023f3d058aa6a19ee8fb098271b0183aa3b30263,
                0x0bee5978910710b661f04e387b76269b09d8a1cf672f0dafdaf6c4f58b216e46
                ),
            _pC: ArrHelper._arr(
                0x15b25390fc76e92eaaad3892ae67bb075efad757a46d8071a3e251d74e624554,
                0x210a9c0ee28d8b5f6aef03ecb9726e55017d84e509d0979d544c115a41d9bc45
                ),
            commit: 0x0b7386c6ee5ebefc31a4c1defe57282c00b303394f976224ec87a01bfad562f0
        });
    }
}
