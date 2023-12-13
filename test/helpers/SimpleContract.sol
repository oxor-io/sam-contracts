// SPDX-License-Identifier: GPL-3
pragma solidity 0.8.23;

contract SimpleContract {
    mapping(address account => bool isCaller) private s_magicMapping;

    function call() external {
        s_magicMapping[msg.sender] = true;
    }

    function getMagicValue(address acc) external view returns (bool isCaller) {
        return s_magicMapping[acc];
    }
}
