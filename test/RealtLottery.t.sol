// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockNFT} from "./Mocks/MockNFT.sol";
import {MockWitnet} from "./Mocks/MockWitnet.sol";
import {RealtLottery, NotTicketOwner, TokenNotSupported, TicketNotReady, DrawTooEarly} from "../src/RealtLottery.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract RealtLotteryTest is Test, ERC721Holder {
    RealtLottery public lottery;
    MockWitnet public witnet;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;

    address bob = makeAddr("Bob");

    function setUp() public {
        tokenA = new ERC20Mock("TOKEN A", "TKA", address(this), 1);
        tokenB = new ERC20Mock("TOKEN B", "TKB", address(this), 1);

        witnet = new MockWitnet();

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory interests = new uint256[](2);
        interests[0] = 10;
        interests[1] = 5;

        address[] memory rentTokens = new address[](0);

        lottery = new RealtLottery(tokens, interests, rentTokens, block.timestamp - 1, address(witnet));

        tokenA.approve(address(lottery), type(uint256).max);
        tokenB.approve(address(lottery), type(uint256).max);
    }

    function testEnter() public {
        tokenA.mint(address(this), 1);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        lottery.enter(tokens, amounts);

        assertEq(tokenA.balanceOf(address(lottery)), 1);
        assertEq(tokenB.balanceOf(address(lottery)), 1);
        assertEq(lottery.owner(), address(this));
    }

    function testExit() public {
        assertEq(tokenA.balanceOf(address(this)), 1);
        assertEq(tokenB.balanceOf(address(this)), 1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        lottery.enter(tokens, amounts);
        assertEq(tokenA.balanceOf(address(lottery)), 1);
        assertEq(tokenB.balanceOf(address(lottery)), 1);
        assertEq(tokenA.balanceOf(address(this)), 0);
        assertEq(tokenB.balanceOf(address(this)), 0);

        uint256[] memory tickets = new uint256[](2);
        tickets[0] = 0;
        tickets[1] = 1;

        lottery.exit(tickets);

        assertEq(tokenA.balanceOf(address(this)), 1);
        assertEq(tokenB.balanceOf(address(this)), 1);
        assertEq(lottery.balanceOf(address(this)), 0);
        assertEq(lottery.balanceOf(address(lottery)), 0);
    }

    function testDrawDelay() public {
        tokenA.mint(address(this), 1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        lottery.enter(tokens, amounts);
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

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        lottery.enter(tokens, amounts);
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

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenA);
        tokens[2] = address(tokenB);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 2;
        amounts[2] = 1;
        
        lottery.enter(tokens, amounts);

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

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenA);
        tokens[2] = address(tokenB);
        

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 2;
        amounts[2] = 1;
        lottery.enter(tokens, amounts);
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

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        lottery.enter(tokens, amounts);
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

        vm.expectRevert(abi.encodeWithSelector(TokenNotSupported.selector, address(tokenC)));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        lottery.enter(tokens, amounts);

        assertEq(lottery.balanceOf(address(this)), 0);
    }

    function testCantStackBeforeTheDelay(uint256 _delay) public {
        vm.assume(_delay < lottery.drawInterval());
        tokenA.mint(address(this), 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        lottery.enter(tokens, amounts);
        skip(_delay);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(TicketNotReady.selector, 0));
        lottery.stack(tickets);

        assertEq(lottery.balanceOf(address(this)), 1);
    }

    function testStackSomeoneTicket() public {
        tokenA.mint(bob, 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        vm.prank(bob);
        tokenA.approve(address(lottery), 1);
        vm.prank(bob);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        lottery.enter(tokens, amounts);

        skip(lottery.drawInterval() + 1);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(NotTicketOwner.selector, 0));
        lottery.stack(tickets);
    }

    function testExitSomeoneTicket() public {
        tokenA.mint(bob, 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        vm.prank(bob);
        tokenA.approve(address(lottery), 1);
        vm.prank(bob);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        lottery.enter(tokens, amounts);

        skip(lottery.drawInterval() + 1);

        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;

        vm.prank(bob);
        lottery.stack(tickets);

        vm.expectRevert(abi.encodeWithSelector(NotTicketOwner.selector, 0));
        lottery.exit(tickets);
    }

    function testDraw() public {
        tokenA.mint(address(this), 1);
        tokenA.mint(address(this), 2);
        tokenB.mint(address(this), 1);

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 2;
        amounts[2] = 1;
        lottery.enter(tokens, amounts);

        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](3);
        tickets[0] = 0;
        tickets[1] = 1;
        tickets[2] = 2;
        lottery.stack(tickets);

        vm.deal(address(this), 1 ether);
        uint256 balanceBefore = address(this).balance;
        lottery.requestDraw{value: 1 ether}();
        assertEq(address(this).balance, balanceBefore - (9 ether / 10));
        skip(lottery.drawInterval() + 1);

        witnet.setDrainAllTheFee(true);
        lottery.requestDraw{value: address(this).balance}();
        assertEq(address(this).balance, 0.1 ether);
        witnet.setDrainAllTheFee(false);
    }

    function testSetInterests() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amount = new uint256[](1);
        amount[0] = 1;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        lottery.setInterests(tokens, amount);

        lottery.setInterests(tokens, amount);
    }

    function testAddTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amount = new uint256[](1);
        amount[0] = 1;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        lottery.addTokens(tokens, amount);

        lottery.addTokens(tokens, amount);
    }

    function testSetDrawInterval() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        lottery.setDrawInterval(1);

        lottery.setDrawInterval(1);
        assertEq(lottery.drawInterval(), 1);
    }

    function testSetRentTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        lottery.setRentTokens(tokens);

        lottery.setRentTokens(tokens);

        assertEq(lottery.rentTokens(0), address(tokenA));
    }

    function testEditWitnetContract() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        lottery.setWitnet(bob);

        lottery.setWitnet(bob);
        assertEq(address(lottery.witnetRandomness()), bob);
    }

    /// @notice allows to receive back funds
    receive() external payable {}
}
