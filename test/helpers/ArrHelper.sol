// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

import {ISafeAnonymizationModule} from "../../src/interfaces/ISafeAnonymizationModule.sol";

library ArrHelper {
    function _proofArr() internal pure returns (ISafeAnonymizationModule.Proof[] memory arr) {
        arr = new ISafeAnonymizationModule.Proof[](0);
    }

    function _proofArr(ISafeAnonymizationModule.Proof memory proof)
        internal
        pure
        returns (ISafeAnonymizationModule.Proof[] memory arr)
    {
        arr = new ISafeAnonymizationModule.Proof[](1);
        arr[0] = proof;
    }

    function _proofArr(ISafeAnonymizationModule.Proof memory a, ISafeAnonymizationModule.Proof memory b)
        internal
        pure
        returns (ISafeAnonymizationModule.Proof[] memory arr)
    {
        arr = new ISafeAnonymizationModule.Proof[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _arr(uint256 a, uint256 b) internal pure returns (uint256[2] memory arr) {
        arr[0] = a;
        arr[1] = b;
    }

    function _arr(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256[2][2] memory arr) {
        arr[0][0] = a;
        arr[0][1] = b;
        arr[1][0] = c;
        arr[1][1] = d;
    }

    function _arr(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }
}
