// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract Blau is ERC20 {
    constructor() ERC20("BLAU", "BLAU", 18) {
        _mint(msg.sender, 0);
    }
}
