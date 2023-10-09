//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

error MintAmountMustBeGreaterThanZero();
contract DEBUGERC20 is ERC20 {

    constructor() ERC20("DEBUG XDAI", "XDAI") { 
    }

    function mint(uint256 mintAmount) external {
        if(mintAmount == 0) {
            revert MintAmountMustBeGreaterThanZero();
        }
        _mint(msg.sender, mintAmount);
    }
}