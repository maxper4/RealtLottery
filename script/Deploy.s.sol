// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RealtLottery.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        address[] memory tokens = new address[](1);
        uint256[] memory interests = new uint256[](1);
        interests[0] = 1000;
        address[] memory rentTokens = new address[](1);
        rentTokens[0] = 0x063Fbb248945656898938137A7A048bdCe847327;
        uint256 nextDraw = block.timestamp;         // For debug
        // uint256 nextDraw = block.timestamp + 7 days;  // For production
        address witnet = 0x0123456fbBC59E181D76B6Fe8771953d1953B51a;        // For gnosis testnet

        vm.startBroadcast();
        address token = address(new ERC20Mock("Test Token", "TST", 0xfdf3403d3426C6ecC7C2acb9cdE70ca369445836, 100));     // For debug
        address tokenRent = address(new ERC20Mock("Test Rent", "TRR", 0xfdf3403d3426C6ecC7C2acb9cdE70ca369445836, 100));     // For debug
        tokens[0] = token;
        rentTokens[0] = tokenRent;
        RealtLottery lottery = new RealtLottery(tokens, interests, rentTokens, nextDraw, witnet);
        vm.stopBroadcast();
    }
}
