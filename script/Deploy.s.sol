// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RealtLottery.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(0x0);
        uint256[] memory interests = new uint256[](1);
        interests[0] = 1000000000000000000;
        address[] memory rentTokens = new address[](1);
        rentTokens[0] = address(0x0);
        uint256 nextDraw = block.timestamp;         // For debug
        // uint256 nextDraw = block.timestamp + 7 days;  // For production
        address witnet = 0x0123456fbBC59E181D76B6Fe8771953d1953B51a;        // For gnosis testnet

        vm.startBroadcast();
        RealtLottery lottery = new RealtLottery(tokens, interests, rentTokens, nextDraw, witnet);
        vm.stopBroadcast();
    }
}
