// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}