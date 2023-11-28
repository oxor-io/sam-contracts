// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {SafeAnonymizationModule} from "../src/SafeAnonymizationModule.sol";

contract SafeAnonymizationModuleTest is Test {
    SafeAnonymizationModule public sam;

    function setUp() public {
        sam = new SafeAnonymizationModule();
    }

    function test_mainContractSetupWillRevert() external {
        vm.expectRevert(SafeAnonymizationModule.SafeAnonymizationModule__alreadyInitialized.selector);
        sam.setup(address(1), bytes32(uint256(1)), 1);
    }
}
