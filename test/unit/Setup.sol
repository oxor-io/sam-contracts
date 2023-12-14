// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {SafeAnonymizationModule, ISafeAnonymizationModule} from "../../src/SafeAnonymizationModule.sol";
import {SafeProxyFactory} from "../../src/proxy/SafeProxyFactory.sol";

import {ISafe} from "../../src/interfaces/Safe/ISafe.sol";
import {IMinimalSafeModuleManager} from "../../src/interfaces/Safe/IMinimalSafeModuleManager.sol";
import {ArrHelper} from "../helpers/ArrHelper.sol";

contract Setup is Test {
    //////////////////////
    //    Constants     //
    //////////////////////

    // Safe in mainnet
    address internal constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    SafeProxyFactory internal constant SAFE_PROXY_FACTORY = SafeProxyFactory(0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67);

    // Helpers for tests
    uint256 internal constant DEFAULT_ROOT =
        7378323513472991738372527896654445137493089583233093119951646841738120031371; // From 10 default anvil accounts

    uint64 internal constant DEFAULT_THRESHOLD = 1;
    bytes internal constant DEFAULT_CALLDATA = abi.encodeWithSignature("getThreshold()");
    uint256 internal constant DEFAULT_SALT = uint256(keccak256(abi.encode(777)));
    bytes32 internal constant DEFAULT_TX_HASH = 0x02cf47d991ff3ebcf9092d5258a4e23fb0ab4dba48ee355ec38343b6bb2ad48c;

    //////////////////////
    // State Variables  //
    //////////////////////

    // Safe
    ISafe internal safe;

    // SAM
    SafeAnonymizationModule internal sam;
    SafeAnonymizationModule internal samSingleton;
    SafeProxyFactory internal samProxyFactory;

    //////////////////////
    //    Modifiers     //
    //////////////////////

    modifier fork(string memory env_var) {
        string memory RPC_URL = vm.envString(env_var);
        vm.createSelectFork(RPC_URL);
        _;
    }

    modifier enableModuleForSafe(ISafe safeContract, SafeAnonymizationModule module) {
        enableModule(address(safeContract), address(module));
        _;
    }

    //////////////////////
    //  Help functions  //
    //////////////////////

    function setUp() public virtual fork("MAINNET_RPC") {
        safe = createMinimalSafeWallet(ArrHelper._arr(address(this)), DEFAULT_THRESHOLD, DEFAULT_SALT);

        // Create SAM module
        samSingleton = new SafeAnonymizationModule();
        samProxyFactory = new SafeProxyFactory();

        bytes memory initializeDataSAM =
            abi.encodeCall(SafeAnonymizationModule.setup, (address(safe), DEFAULT_ROOT, DEFAULT_THRESHOLD));

        sam = createSAM(initializeDataSAM, DEFAULT_SALT);
    }

    function createSAM(bytes memory initData, uint256 salt) internal returns (SafeAnonymizationModule newSAM) {
        return SafeAnonymizationModule(
            address(samProxyFactory.createChainSpecificProxyWithNonce(address(samSingleton), initData, salt))
        );
    }

    // Create Safe wallet with minimal settings
    function createMinimalSafeWallet(address[] memory owners, uint64 threshold, uint256 salt)
        internal
        returns (ISafe newSafeWallet)
    {
        address optionalDelegateCallTo = address(0);
        bytes memory optionalDelegateCallData = "";

        address fallbackHandler = address(0);
        address paymentToken = address(0);
        uint256 payment = 0;
        address payable paymentReceiver = payable(address(0));

        bytes memory initializeDataSafe = abi.encodeCall(
            ISafe.setup,
            (
                owners,
                threshold,
                optionalDelegateCallTo,
                optionalDelegateCallData,
                fallbackHandler,
                paymentToken,
                payment,
                paymentReceiver
            )
        );

        return ISafe(
            address(SAFE_PROXY_FACTORY.createChainSpecificProxyWithNonce(SAFE_SINGLETON, initializeDataSafe, salt))
        );
    }

    error TestRevert_moduleNotEnabled();

    function enableModule(address safeContract, address module) internal {
        bytes memory cd = abi.encodeCall(IMinimalSafeModuleManager.enableModule, (module));
        sendTxToSafe(safeContract, address(this), safeContract, 0, cd, IMinimalSafeModuleManager.Operation.Call, 1e5);

        if (!ISafe(safeContract).isModuleEnabled(module)) {
            revert TestRevert_moduleNotEnabled();
        }
    }

    function sendTxToSafe(
        address safeContract,
        address sender,
        address to,
        uint256 value,
        bytes memory data,
        IMinimalSafeModuleManager.Operation operation,
        uint256 gasForExec
    ) internal returns (bool success) {
        bytes memory sig = encodeSenderSignature(sender);

        vm.prank(sender);
        return ISafe(safeContract).execTransaction{value: value}(
            to, value, data, operation, gasForExec, block.basefee, tx.gasprice, address(0), payable(address(this)), sig
        );
    }

    function encodeSenderSignature(address signer) internal pure returns (bytes memory) {
        bytes memory sig = new bytes(96);

        assembly {
            mstore(add(sig, 0x20), signer) // encode address of approver into r
            mstore(add(sig, 0x60), shl(248, 1)) // v, indicate that it is a approved hash
        }

        return sig;
    }

    // Since after each contract change, its bytecode changes, and thus previous proofs become invalid.
    // In order not to change the proofs in each test, we will make a default proof.
    function defaultCorrectProof() internal pure returns (ISafeAnonymizationModule.Proof memory proof) {
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
