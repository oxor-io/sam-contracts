// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {SafeAnonymizationModule, ISafeAnonymizationModule} from "../../src/SafeAnonymizationModule.sol";
import {SafeProxyFactory} from "../../src/Safe/proxy/SafeProxyFactory.sol";

import {ISafe} from "../../src/Safe/interfaces/ISafe.sol";
import {IMinimalSafeModuleManager} from "../../src/Safe/interfaces/IMinimalSafeModuleManager.sol";
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
    bytes32 internal constant DEFAULT_TX_HASH = 0x09b086d54be973c0cae8f289b9a308969c3a0d336ba3000651cffcde84ce5fb3;

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
                0x0066f6ad349f60b724e6f96a5dbe5c1b050f6dd738134efaeebf02c8dcf3d0db,
                0x1fbeeb8b371db192bedbc4561d6315a47d8ed0f837fb3fa1d6fad75da0da858d
                ),
            _pB: ArrHelper._arr(
                0x143a09e94cfa0bd1adfafb39c2b251eb67014912c4ff29d9ef912dbed15a65d0,
                0x16805b466b41489060ab41d80e9a2458146877701e1f7c60b3140e75620d5ab2,
                0x2f43c2c42c006f8c05b78cc20890ad5aa6f6e4865155c4cec3720e74d4a9c4b9,
                0x1e9a0429d365072995f6919bc29ba7f171ac28c0bc9083cd39285ed7a3aa879e
                ),
            _pC: ArrHelper._arr(
                0x161e34e7d5dd24f4998b995bef58eca0578d7549a4c4a0ca96cd4e52965d1f19,
                0x064935e8410a403e6b385788a2dcf27d8be4cc5b095a03d005797b33358110d4
                ),
            commit: 0x0d3703c4cc8e88dc9aba3f2c34d00101f580d572b9c09bf27530bbee06d62831
        });
    }
}
