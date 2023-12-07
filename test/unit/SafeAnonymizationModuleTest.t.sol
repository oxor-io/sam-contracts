// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SAMSetup, Test, SafeAnonymizationModule} from "./SAMSetup.sol";

contract SafeAnonymizationModuleTest is Test, SAMSetup {
    function setUp() public override {
        super.setUp();
    }

    //////////////////////
    //      Tests       //
    //////////////////////

    function test_singletonSetupWillRevert() external {
        vm.expectRevert(SafeAnonymizationModule.SafeAnonymizationModule__alreadyInitialized.selector);
        samSingleton.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }

    // Simply check that setup was ok
    function test_rootIsInitializedCorrectly() external {
        assertEq32(sam.getParticipantsRoot(), DEFAULT_ROOT, "Setup failed! Root does not match the default");
    }

    function test_impossibleToSetupMultiplyTimes() external {
        vm.expectRevert(SafeAnonymizationModule.SafeAnonymizationModule__alreadyInitialized.selector);
        sam.setup(address(1), DEFAULT_ROOT, DEFAULT_THRESHOLD);
    }
}
