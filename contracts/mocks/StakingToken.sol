// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "hardhat/console.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

/**
 * @title Mock contract for ETHA LP Staking Token
 */
contract StakingToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("LP", "LP"){}
}
