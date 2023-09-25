// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/DebugERC20.sol";

contract DeployDebugERC20 is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        ERC20 erc20 = new DEBUGERC20();
        vm.stopBroadcast();
    }
}
