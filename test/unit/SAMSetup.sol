// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {SafeAnonymizationModule} from "../../src/SafeAnonymizationModule.sol";
import {SafeProxyFactory} from "../../src/proxy/SafeProxyFactory.sol";

import {ISafe} from "../../src/interfaces/Safe/ISafe.sol";
import {IMinimalSafeModuleManager} from "../../src/interfaces/Safe/IMinimalSafeModuleManager.sol";

import {console} from "forge-std/console.sol";

contract SAMSetup is Test {
    //////////////////////
    //    Constants     //
    //////////////////////

    // Safe in Mainnet
    address internal constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    SafeProxyFactory internal constant SAFE_PROXY_FACTORY = SafeProxyFactory(0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67);

    // For tests
    uint256 internal constant DEFAULT_ROOT =
        7378323513472991738372527896654445137493089583233093119951646841738120031371; // From 10 default anvil accounts
    uint64 internal constant DEFAULT_THRESHOLD = 1;
    uint256 internal constant DEFAULT_SALT = uint256(keccak256(abi.encode(777)));

    //////////////////////
    // State Variables  //
    //////////////////////

    // Safe
    ISafe internal safe;

    // SAM
    SafeAnonymizationModule internal sam;
    SafeAnonymizationModule internal samSingleton;
    SafeProxyFactory internal samProxyFactory;

    function setUp() public virtual {
        // Create fork
        string memory RPC_URL = vm.envString("MAINNET_RPC");
        vm.createSelectFork(RPC_URL);

        // Create minimal Safe
        address[] memory owners = new address[](1);
        owners[0] = address(this);
        safe = _createMinimalSafeWallet(owners);

        // Create SAM module
        samSingleton = new SafeAnonymizationModule();
        samProxyFactory = new SafeProxyFactory();

        bytes memory initializeDataSam =
            abi.encodeCall(SafeAnonymizationModule.setup, (address(safe), DEFAULT_ROOT, DEFAULT_THRESHOLD));

        sam = SafeAnonymizationModule(
            address(
                samProxyFactory.createChainSpecificProxyWithNonce(
                    address(samSingleton), initializeDataSam, DEFAULT_SALT
                )
            )
        );
    }

    //////////////////////
    //  Help functions  //
    //////////////////////

    // Create Safe wallet with minimal settings
    function _createMinimalSafeWallet(address[] memory owners) internal returns (ISafe) {
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
                DEFAULT_THRESHOLD,
                optionalDelegateCallTo,
                optionalDelegateCallData,
                fallbackHandler,
                paymentToken,
                payment,
                paymentReceiver
            )
        );

        return ISafe(
            address(
                SAFE_PROXY_FACTORY.createChainSpecificProxyWithNonce(SAFE_SINGLETON, initializeDataSafe, DEFAULT_SALT)
            )
        );
    }

    function enableModule(address module) internal {
        bytes memory cd = abi.encodeCall(IMinimalSafeModuleManager.enableModule, (module));
        sendTxToSafe(address(this), address(safe), 0, cd, IMinimalSafeModuleManager.Operation.Call, 1e5);
    }

    function sendTxToSafe(
        address sender,
        address to,
        uint256 value,
        bytes memory data,
        IMinimalSafeModuleManager.Operation operation,
        uint256 gasForExec
    ) internal returns (bool success) {
        bytes memory sig = encodeSenderSignature(sender);

        return safe.execTransaction(
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
}
