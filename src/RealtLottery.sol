// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract RealtLottery is Ownable {
    mapping(address => uint256) public interestsPerToken;
    mapping(address => mapping(address => mapping(uint256 => bool))) public tokensOfUsers;

    constructor(address[] memory tokens, uint256[] memory interests) {
        for (uint256 i = 0; i < tokens.length; i++) {
            interestsPerToken[tokens[i]] = interests[i];
        }
    }

    function setInterests(address[] memory tokens, uint256[] memory interests) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            interestsPerToken[tokens[i]] = interests[i];
        }
    }

    function enter(address[] memory tokens, uint256[] memory amounts) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            if(interestsPerToken[tokens[i]] > 0)
                tokensOfUsers[msg.sender][tokens[i]] = true;
        }
    }

    function exit(address[] memory tokens, uint256[] memory amounts) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            if(!tokensOfUsers[msg.sender][tokens[i]])
                tokensOfUsers[msg.sender][tokens[i]] = false;        
        }
    }

}
