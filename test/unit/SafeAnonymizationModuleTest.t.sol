// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {SafeAnonymizationModule} from "../../src/SafeAnonymizationModule.sol";
import {SafeProxyFactory} from "../../src/proxy/SafeProxyFactory.sol";

import {ISafe} from "../../src/interfaces/Safe/ISafe.sol";

contract SafeAnonymizationModuleTest is Test {
    //////////////////////
    //    Constants     //
    //////////////////////

    // Safe in Mainnet
    address private constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    SafeProxyFactory private constant SAFE_PROXY_FACTORY = SafeProxyFactory(0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67);

    // For tests
    bytes32 private constant DEFAULT_ROOT = bytes32(uint256(1));
    uint256 private constant DEFAULT_THRESHOLD = 1;
    uint256 private constant DEFAULT_SALT = uint256(keccak256(abi.encode(777)));

    //////////////////////
    // State Variables  //
    //////////////////////

    // Safe
    ISafe private safe;

    // SAM
    SafeAnonymizationModule private sam;
    SafeAnonymizationModule private samSingleton;
    SafeProxyFactory private samProxyFactory;

    function setUp() public {
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
    //      Tests       //
    //////////////////////

    function test_mainContractSetupWillRevert() external {
        vm.expectRevert(SafeAnonymizationModule.SafeAnonymizationModule__alreadyInitialized.selector);
        samSingleton.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }

    // Simply check that setup was ok
    function test_rootIsSetupCorrectly() external {
        assertEq32(sam.getParticipantsRoot(), DEFAULT_ROOT, "Setup failed! Root does not match the default");
    }

    function test_impossibleToSetupMultiplyTimes() external {
        vm.expectRevert(SafeAnonymizationModule.SafeAnonymizationModule__alreadyInitialized.selector);
        samSingleton.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }

    //////////////////////
    //  Help functions  //
    //////////////////////

    function _createMinimalSafeWallet(address[] memory owners) private returns (ISafe) {
        // Create Safe wallet with minimal settings
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
}
