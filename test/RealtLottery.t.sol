// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockWitnet} from "./Mocks/MockWitnet.sol";
import {RealtLottery, NotTicketOwner, TokenNotSupported, TicketNotReady, DrawTooEarly} from "../src/RealtLottery.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract RealtLotteryTest is Test, ERC721Holder {
    RealtLottery public lottery;
    MockWitnet public witnet;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public rentTokenA;
    ERC20Mock public rentTokenB;

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

        rentTokenA = new ERC20Mock("RENT A", "RKA", address(this), 0);
        rentTokenB = new ERC20Mock("RENT B", "RKB", address(this), 0);

        address[] memory rentTokens = new address[](2);
        rentTokens[0] = address(rentTokenA);
        rentTokens[1] = address(rentTokenB);

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

        uint256 balanceABefore = tokenA.balanceOf(address(this));
        uint256 balanceBBefore = tokenB.balanceOf(address(this));

        lottery.enter(tokens, amounts);

        assertEq(tokenA.balanceOf(address(lottery)), 1);
        assertEq(tokenA.balanceOf(address(this)), balanceABefore - 1);
        assertEq(tokenB.balanceOf(address(lottery)), 1);
        assertEq(tokenB.balanceOf(address(this)), balanceBBefore - 1);
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

    function testOnlyStackedCanWin(uint256 _randomness) public {
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

        lottery.tickets(0);

        uint256 winner0 = lottery.findRandomNFT(_randomness % lottery.interestsCumulated());
        assertEq(winner0, 0);
    }

    function testFrequency(uint256 _amount1, uint256 _amount2) public {
        vm.assume(_amount1 > 0);
        vm.assume(_amount2 > 0);
        vm.assume(_amount1 < 100);       // otherwise it's too long to run for each possible random value
        vm.assume(_amount2 < 100);

        tokenA.mint(address(this), _amount1);
        tokenB.mint(address(this), _amount2);
        
        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _amount1;
        amounts[1] = _amount2;

        lottery.enter(tokens, amounts);

        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](2);
        tickets[0] = 0;
        tickets[1] = 1;
        lottery.stack(tickets);

        uint256[] memory winsCount = new uint256[](2);
        winsCount[0] = 0;
        winsCount[1] = 0;

        uint256 nbDraw = lottery.interestsCumulated();
        uint256 interestsCumulated = lottery.interestsCumulated();

        for (uint256 i = 0; i < nbDraw; i++) {
            uint256 winner = lottery.findRandomNFT(i % interestsCumulated);
            winsCount[winner] += 1;
        }

        assertApproxEqRel(winsCount[0], nbDraw * 10 * _amount1 / (10 * _amount1 + 5 * _amount2), 0.1e18);
        assertApproxEqRel(winsCount[1], nbDraw * 5 * _amount2 / (10 * _amount1 + 5 * _amount2), 0.1e18);
    }

    function testLastWinnerIsOwnerOfNFT(uint32 _randomness, uint256 _amount1, uint256 _amount2) public {
        vm.assume(_amount1 > 0);
        vm.assume(_amount2 > 0);
        vm.assume(_amount1 < 1e6);
        vm.assume(_amount2 < 1e6);

        tokenA.mint(address(this), _amount1);
        tokenB.mint(bob, _amount2);

        vm.startPrank(bob);
        tokenB.approve(address(lottery), _amount2);
        vm.stopPrank();
        
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount1;

        lottery.enter(tokens, amounts);

        vm.startPrank(bob);
        tokens[0] = address(tokenB);
        amounts[0] = _amount2;
        lottery.enter(tokens, amounts);
        vm.stopPrank();

        skip(lottery.drawInterval() + 1);
        uint256[] memory tickets = new uint256[](1);
        tickets[0] = 0;
        lottery.stack(tickets);

        vm.startPrank(bob);
        tickets[0] = 1;
        lottery.stack(tickets);
        vm.stopPrank();

        uint256 winnerNFT = lottery.findRandomNFT(_randomness % lottery.interestsCumulated());
        address winner = lottery.ownerOf(winnerNFT);

        vm.deal(address(this), 1 ether);
        lottery.requestDraw{value: 1 ether}();

        witnet.setRandomness(_randomness);

        lottery.doDraw();

        assertEq(lottery.lastWinner(), winner);
    }

    function testCantEnterWithUnsupportedToken() public {
        ERC20Mock tokenC = new ERC20Mock("Bad Token", "BAD", address(this), 1);

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
        tokens[0] = address(rentTokenA);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        lottery.setRentTokens(tokens);

        lottery.setRentTokens(tokens);

        assertEq(lottery.rentTokens(0), address(rentTokenA));
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
