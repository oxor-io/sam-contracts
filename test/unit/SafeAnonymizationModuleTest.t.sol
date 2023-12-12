// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SAMSetup, Test, IMinimalSafeModuleManager} from "./SAMSetup.sol";
import {
    ISafeAnonymizationModuleErrors, ISafeAnonymizationModule
} from "../../src/interfaces/ISafeAnonymizationModule.sol";
import {ArrHelper} from "../helpers/ArrHelper.sol";

contract SafeAnonymizationModuleTest is Test, SAMSetup {
    function setUp() public override {
        super.setUp();
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
        assertEq(sam.getParticipantsRoot(), DEFAULT_ROOT, "Setup failed! Root does not match the default");
    }

    function test_impossibleToSetupMultiplyTimes() external {
        vm.expectRevert(ISafeAnonymizationModuleErrors.SafeAnonymizationModule__alreadyInitialized.selector);
        sam.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }

    function test_callCanBeDone() external {
        enableModule(address(sam));

        // Proof:
        // Tree constructed from all Anvil addresses
        // From: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (0 Anvil address)
        // Calldata: 0xe75235b8 (getThreshold())
        // Call type: Call
        // Nonce: 0
        // ChainId: 1 (ETH)
        ISafeAnonymizationModule.Proof memory proof = ISafeAnonymizationModule.Proof({
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

        bytes memory cd = abi.encodeWithSignature("getThreshold()");

        (bool result, bytes memory returnData) = sam.executeTransactionReturnData(
            address(sam), 0, cd, IMinimalSafeModuleManager.Operation.Call, ArrHelper._proofArr(proof)
        );

        assertTrue(result);
        assertEq(abi.decode(returnData, (uint256)), DEFAULT_THRESHOLD);
    }
}
