// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Blau is ERC20 {
    constructor() ERC20("BLAU", "BLAU", 18) {
        _mint(msg.sender, 0);
    }

    function startStake(address burnAddress, uint256 term) public {}

    function startStake(uint256 amount, uint256 term) public {}

    function deferStake() public {}

    function endStake() public {}
}
