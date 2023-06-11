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

        address[] memory rentTokens = new address[](0);

        lottery = new RealtLottery(tokens, interests, rentTokens, block.timestamp - 1);

        tokenA.setApprovalForAll(address(lottery), true);
        tokenB.setApprovalForAll(address(lottery), true);
    }

    function testEnter() public {
        tokenA.mint(address(this), 1);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[][] memory ids = new uint256[][](2);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;
        ids[1] = id;

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

        uint256[][] memory ids = new uint256[][](2);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;
        ids[1] = id;

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

    function testDrawDelay() public {
        tokenA.mint(address(this), 1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[][] memory ids = new uint256[][](1);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;

        lottery.enter(tokens, ids);

        lottery.draw();

        assertEq(lottery.nextDrawTimestamp(), block.timestamp + lottery.drawInterval());

        // try to draw again
        vm.expectRevert(DrawTooEarly.selector);
        lottery.draw();
    }

    function testSelectionOfNFTBasedOnRandomness2() public {
        tokenA.mint(address(this), 1);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[][] memory ids = new uint256[][](2);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;
        ids[1] = id;

        lottery.enter(tokens, ids);

        uint256 winner0 = lottery.findRandomNFT(0);
        assertEq(winner0, 0);

        uint256 winner1 = lottery.findRandomNFT(1);
        assertEq(winner1, 0);

        uint256 winner2 = lottery.findRandomNFT(10);
        assertEq(winner2, 1);

        uint256 winner3 = lottery.findRandomNFT(11);
        assertEq(winner3, 1);

        uint256 winner4 = lottery.findRandomNFT(15);
        assertEq(winner4, 1);
    }

    function testSelectionOfNFTBasedOnRandomness3() public {
        tokenA.mint(address(this), 1);
        tokenA.mint(address(this), 2);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[][] memory ids = new uint256[][](2);
        uint256[] memory id = new uint256[](2);
        id[0] = 1;
        id[1] = 2;
        uint256[] memory id2 = new uint256[](1);
        id2[0] = 1;

        ids[0] = id;
        ids[1] = id2;

        lottery.enter(tokens, ids);

        uint256 winner0 = lottery.findRandomNFT(0);
        assertEq(winner0, 0);

        uint256 winner1 = lottery.findRandomNFT(1);
        assertEq(winner1, 0);

        uint256 winner2 = lottery.findRandomNFT(10);
        assertEq(winner2, 1);

        uint256 winner3 = lottery.findRandomNFT(11);
        assertEq(winner3, 1);

        uint256 winner4 = lottery.findRandomNFT(15);
        assertEq(winner4, 1);

        uint256 winner5 = lottery.findRandomNFT(19);
        assertEq(winner5, 1);

        uint256 winner6 = lottery.findRandomNFT(20);
        assertEq(winner6, 2);

        uint256 winner7 = lottery.findRandomNFT(24);
        assertEq(winner7, 2);
    }

    function testSelectionOfNFTBasedOnRandomnessAfterBurn() public {
        tokenA.mint(address(this), 1);
        tokenA.mint(address(this), 2);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[][] memory ids = new uint256[][](2);
        uint256[] memory id = new uint256[](2);
        id[0] = 1;
        id[1] = 2;
        uint256[] memory id2 = new uint256[](1);
        id2[0] = 1;

        ids[0] = id;
        ids[1] = id2;

        lottery.enter(tokens, ids);

        uint256[] memory toBurn = new uint256[](1);
        toBurn[0] = 1;

        lottery.exit(toBurn);

        uint256 winner0 = lottery.findRandomNFT(0);
        assertEq(winner0, 0);

        uint256 winner1 = lottery.findRandomNFT(1);
        assertEq(winner1, 0);

        uint256 winner2 = lottery.findRandomNFT(9);
        assertEq(winner2, 0);

        uint256 winner3 = lottery.findRandomNFT(10);
        assertEq(winner3, 2);

        uint256 winner4 = lottery.findRandomNFT(15);
        assertEq(winner4, 2);
    }
}
