// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./MockNFT.sol";
import "../src/RealtLottery.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";

contract RealtLotteryTest is Test, ERC721Holder {
    RealtLottery public lottery;
    MockNFT public tokenA;
    MockNFT public tokenB;

    function setUp() public {
        tokenA = new MockNFT("TOKEN A", "TKA");
        tokenB = new MockNFT("TOKEN B", "TKB");

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory interests = new uint256[](2);
        interests[0] = 10;
        interests[1] = 5;

        lottery = new RealtLottery(tokens, interests);

        tokenA.setApprovalForAll(address(lottery), true);
        tokenB.setApprovalForAll(address(lottery), true);
    }

    function testEnter() public {
        tokenA.mint(address(this), 1);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        lottery.enter(tokens, ids);

        assertEq(tokenA.ownerOf(1), address(lottery));
        assertEq(tokenB.ownerOf(1), address(lottery));
        assertEq(lottery.ownerOf(0), address(this));
        assertEq(lottery.ownerOf(1), address(this));
    }

    function testExit() public {
        tokenA.mint(address(this), 1);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        lottery.enter(tokens, ids);

        uint256[] memory tickets = new uint256[](2);
        tickets[0] = 0;
        tickets[1] = 1;

        lottery.exit(tickets);

        assertEq(tokenA.ownerOf(1), address(this));
        assertEq(tokenB.ownerOf(1), address(this));
        assertEq(lottery.balanceOf(address(this)), 0);
        assertEq(lottery.balanceOf(address(lottery)), 0);
    }
}
