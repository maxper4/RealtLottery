// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RealtLottery.sol";

contract UpdateRentTokens is Script {
    function setUp() public {}

    function run() public {
        address[] memory tokens = new address[](1);
        tokens[0] = 0x063Fbb248945656898938137A7A048bdCe847327;
        vm.startBroadcast();
        RealtLottery lottery = RealtLottery(payable(0x8c33FfdeD8B413ea6180826f0de464117d829615));
        lottery.setRentTokens(tokens);
        vm.stopBroadcast();
    }
}
