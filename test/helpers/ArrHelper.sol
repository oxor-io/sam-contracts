// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISafeAnonymizationModule} from "../../src/interfaces/ISafeAnonymizationModule.sol";

library ArrHelper {
    function _proofArr(ISafeAnonymizationModule.Proof memory _proof)
        internal
        pure
        returns (ISafeAnonymizationModule.Proof[] memory arr)
    {
        arr = new ISafeAnonymizationModule.Proof[](1);
        arr[0] = _proof;
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
}
