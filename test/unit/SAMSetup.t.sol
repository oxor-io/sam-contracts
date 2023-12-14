// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {Setup, Test, SafeAnonymizationModule} from "./Setup.sol";
import {
    ISafeAnonymizationModuleErrors, ISafeAnonymizationModule
} from "../../src/interfaces/ISafeAnonymizationModule.sol";

contract SAMExecuteTxTest is Test, Setup {
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

    function test_setupWithZeroThresholdWillRevert() external {
        bytes memory initData = abi.encodeCall(SafeAnonymizationModule.setup, (address(safe), DEFAULT_ROOT, 0));
        vm.expectRevert(); // Since factory will revert with 0 data
        createSAM(initData, 12317);
    }

    function test_setupWithZeroRootWillRevert() external {
        bytes memory initData = abi.encodeCall(SafeAnonymizationModule.setup, (address(safe), 0, DEFAULT_THRESHOLD));
        vm.expectRevert(); // Since factory will revert with 0 data
        createSAM(initData, 12317);
    }

    function test_setupWithZeroSafeWillRevert() external {
        bytes memory initData =
            abi.encodeCall(SafeAnonymizationModule.setup, (address(0), DEFAULT_ROOT, DEFAULT_THRESHOLD));
        vm.expectRevert(); // Since factory will revert with 0 data
        createSAM(initData, 12317);
    }
}
