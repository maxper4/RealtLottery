// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockNFT} from "./Mocks/MockNFT.sol";
import {MockWitnet} from "./Mocks/MockWitnet.sol";
import {RealtLottery, NotTicketOwner, TokenNotSupported, TicketNotReady, DrawTooEarly} from "../src/RealtLottery.sol";
import {ERC721Holder} from "openzeppelin/token/ERC721/utils/ERC721Holder.sol";

contract RealtLotteryTest is Test, ERC721Holder {
    RealtLottery public lottery;
    MockWitnet public witnet;
    MockNFT public tokenA;
    MockNFT public tokenB;

    function setUp() public {
        tokenA = new MockNFT("TOKEN A", "TKA");
        tokenB = new MockNFT("TOKEN B", "TKB");

        witnet = new MockWitnet();

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory interests = new uint256[](2);
        interests[0] = 10;
        interests[1] = 5;

        address[] memory rentTokens = new address[](0);

        lottery = new RealtLottery(tokens, interests, rentTokens, block.timestamp - 1, address(witnet));

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
        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;
        lottery.stack(tickets);

        lottery.requestDraw();

        assertEq(lottery.nextDrawTimestamp(), block.timestamp + lottery.drawInterval());

        // try to draw again
        vm.expectRevert(DrawTooEarly.selector);
        lottery.requestDraw();
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
        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](2);
        tickets[0] = 0;
        tickets[1] = 1;
        lottery.stack(tickets);


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
        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](3);
        tickets[0] = 0;
        tickets[1] = 1;
        tickets[2] = 2;
        lottery.stack(tickets);


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
        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](3);
        tickets[0] = 0;
        tickets[1] = 1;
        tickets[2] = 2;
        lottery.stack(tickets);

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

    function testOnlyStackedCanWin(uint256 randomness) public {
        tokenA.mint(address(this), 1);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[][] memory ids = new uint256[][](2);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        uint256[] memory id2 = new uint256[](1);
        id2[0] = 1;

        ids[0] = id;
        ids[1] = id2;

        lottery.enter(tokens, ids);
        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;
        lottery.stack(tickets);

        uint256 winner0 = lottery.findRandomNFT(randomness % lottery.interestsCumulated());
        assertEq(winner0, 0);
    }

    function testCantEnterWithUnsupportedToken() public {
        MockNFT tokenC = new MockNFT("TOKEN C", "TKC");
        tokenC.mint(address(this), 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenC);

        uint256[][] memory ids = new uint256[][](1);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;

        vm.expectRevert(abi.encodeWithSelector(TokenNotSupported.selector, address(tokenC)));
        lottery.enter(tokens, ids);

        assertEq(lottery.balanceOf(address(this)), 0);
    }

    function testCantStackBeforeTheDelay(uint256 _delay) public {
        vm.assume(_delay < lottery.drawInterval());
        tokenA.mint(address(this), 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[][] memory ids = new uint256[][](1);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;

        lottery.enter(tokens, ids);
        skip(_delay);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(TicketNotReady.selector, 0));
        lottery.stack(tickets);

        assertEq(lottery.balanceOf(address(this)), 1);
    }

    function testStackSomeoneTicket() public {
        address someone = address(0x1);
        tokenA.mint(someone, 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[][] memory ids = new uint256[][](1);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;

        vm.prank(someone);
        tokenA.approve(address(lottery), 1);
        vm.prank(someone);
        lottery.enter(tokens, ids);
        skip(lottery.drawInterval() + 1);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(NotTicketOwner.selector, 0));
        lottery.stack(tickets);
    }

    function testExitSomeoneTicket() public {
        address someone = address(0x1);
        tokenA.mint(someone, 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[][] memory ids = new uint256[][](1);
        uint256[] memory id = new uint256[](1);
        id[0] = 1;
        ids[0] = id;

        vm.prank(someone);
        tokenA.approve(address(lottery), 1);
        vm.prank(someone);
        lottery.enter(tokens, ids);
        skip(lottery.drawInterval() + 1);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;

        vm.prank(someone);
        lottery.stack(tickets);

        vm.expectRevert(abi.encodeWithSelector(NotTicketOwner.selector, 0));
        lottery.exit(tickets);
    }

    function testDraw() public {
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
        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](3);
        tickets[0] = 0;
        tickets[1] = 1;
        tickets[2] = 2;
        lottery.stack(tickets);

        lottery.requestDraw();
    }

    function testSetInterests() public {
        address someone = address(0x1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amount = new uint256[](1);
        amount[0] = 1;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(someone);
        lottery.setInterests(tokens, amount);

        lottery.setInterests(tokens, amount);
    }

    function testAddTokens() public {
        address someone = address(0x1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amount = new uint256[](1);
        amount[0] = 1;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(someone);
        lottery.addTokens(tokens, amount);

        lottery.addTokens(tokens, amount);
    }

    function testSetDrawInterval() public {
        address someone = address(0x1);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(someone);
        lottery.setDrawInterval(1);

        lottery.setDrawInterval(1);
        assertEq(lottery.drawInterval(), 1);
    }

    function setRentTokens() public {
        address someone = address(0x1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(someone);
        lottery.setRentTokens(tokens);

        lottery.setRentTokens(tokens);

        assertEq(lottery.rentTokens(0), address(tokenA));
    }
}
