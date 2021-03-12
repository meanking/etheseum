//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../registry/EthaRegistry.sol";

contract EthaRegistryMockV2 is EthaRegistry {
    function foo() external pure returns (string memory) {
        return "buzz";
    }
}
