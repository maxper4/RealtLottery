// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721Enumerable, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IWitnetRandomness} from "witnet-solidity-bridge/interfaces/IWitnetRandomness.sol";

error DrawTooEarly();
error TokenNotSupported(address token);
error TicketNotReady(uint256 ticket);
error NotTicketOwner(uint256 ticket);
error NoRandomness();
error CouldNotRefund();

/// @title RealT Lottery: a lottery where you can win the rent of every staked property
/// @author maxper
/// @notice  Users can enter with a token from RealT, stack it and wait for the next draw
contract RealtLottery is Ownable, ERC721Enumerable {
    struct Ticket {             // A ticket is a wrapper around a property token
        address token;
        uint256 amount;
        uint256 indexInToken;
        uint256 enteredAt;
        bool stacked;
        TierTicket[] tiers;
    }

    struct TierTicket {
        uint256 tier;
        uint256 indexInTicket;
    }

    struct Token {
        // A token represent a property that generate interests
        uint256 interests;
        uint256[] tickets;
        uint256 interestsCumulated; // sum of interests cumulated for this token
    }

    address[] private tokensSupported; // list of supported property tokens
    mapping(address => Token) public tokens; // all tokens

    mapping(uint256 => Ticket) public tickets; // all tickets
    uint256 public interestsCumulated;

    mapping(address => mapping(uint256 => uint256[])) public buckets; // buckets of tickets for each tier and for each token
    mapping(address => uint256) public greatestTier;        // maximum tier

    uint256 private ticketCounter; // counter for ticket ids

    address[] public rentTokens; // every token that can be used to pay rent (xDai, USDC, etc..)

    uint256 public nextDrawTimestamp; // when the next draw can be done
    uint256 public drawInterval; // minimum delay between two draws

    address public lastWinner;
    uint256[] public lastPrize;

    IWitnetRandomness public witnetRandomness; // Witnet randomness contract
    uint256 public witnetRandomnessBlock; // block number of the last Witnet randomness request, 0 if the draw was executed

    constructor(
        address[] memory _tokens,
        uint256[] memory _interests,
        address[] memory _rentTokens,
        uint256 _nextDraw,
        address _witnet
    ) ERC721("RealtLottery", "RTL") Ownable() {
        for (uint256 i = 0; i < _tokens.length; ++i) {
            tokens[_tokens[i]] = Token(_interests[i], new uint256[](0), 0);
            tokensSupported.push(_tokens[i]);
        }

        rentTokens = _rentTokens;
        nextDrawTimestamp = _nextDraw;
        drawInterval = 6 days + 12 hours;

        witnetRandomness = IWitnetRandomness(_witnet);
    }

    /// @notice Enter the lottery with a list of property tokens
    /// @param _tokens The list of property tokens
    /// @param _amounts  Amount of each property token
    function enter(address[] memory _tokens, uint256[] memory _amounts) external {
        for (uint256 i = 0; i < _tokens.length;) {
            if (tokens[_tokens[i]].interests != 0) {
                // owner must approve this contract first
                ERC20(_tokens[i]).transferFrom(msg.sender, address(this), _amounts[i]); // Take custody of the property token

                // Mint a ticket to be reedemed later for the property token
                tickets[ticketCounter].token = _tokens[i];
                tickets[ticketCounter].amount = _amounts[i];
                tickets[ticketCounter].enteredAt = block.timestamp;                

                _safeMint(msg.sender, ticketCounter++);
            } else {
                revert TokenNotSupported(_tokens[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Stack a list of tickets
    /// @param _tickets The list of tickets
    /// @dev The ticket must have been entered at least one drawInterval ago to avoid abuse (being able to win without having contributed to the rent)
    function stack(uint256[] memory _tickets) external {
        for (uint256 i = 0; i < _tickets.length;) {
            if (ownerOf(_tickets[i]) == msg.sender) {
                Ticket storage ticket = tickets[_tickets[i]];
                if (!ticket.stacked && block.timestamp - ticket.enteredAt >= drawInterval) {
                    ticket.stacked = true;
                    ticket.indexInToken = tokens[ticket.token].tickets.length;
                    tokens[ticket.token].tickets.push(_tickets[i]);

                    uint256 interests =
                        tokens[ticket.token].interests * ticket.amount * 10 ** (18-ERC20(ticket.token).decimals());
                    tokens[ticket.token].interestsCumulated += interests;
                    interestsCumulated += interests;

                    uint256 bucket = 1;
                    while (bucket <= ticket.amount) {           // binary decomposition of the ticket amount
                        if (bucket & ticket.amount != 0) {
                            ticket.tiers.push(TierTicket(bucket, buckets[ticket.token][bucket].length));
                            buckets[ticket.token][bucket].push(_tickets[i]);
                        }

                        bucket <<= 1;
                    }

                    if (greatestTier[ticket.token] < bucket) {
                        greatestTier[ticket.token] = bucket;
                    }
                } else {
                    revert TicketNotReady(_tickets[i]);
                }
            } else {
                revert NotTicketOwner(_tickets[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Exit a list of tickets, the property token will be sent back to the user
    /// @param _ids The list of tickets
    function exit(uint256[] memory _ids) external {
        for (uint256 i = 0; i < _ids.length;) {
            if (ownerOf(_ids[i]) == msg.sender) {
                Ticket memory ticket = tickets[_ids[i]];

                // remove the ticket
                _burn(_ids[i]);
                delete tickets[_ids[i]];

                if (ticket.stacked) {
                    uint256 swapped = tokens[ticket.token].tickets[tokens[ticket.token].tickets.length - 1];
                    tickets[swapped].indexInToken = ticket.indexInToken;
                    tokens[ticket.token].tickets[ticket.indexInToken] = swapped;
                    tokens[ticket.token].tickets.pop();
                    uint256 interests =
                        tokens[ticket.token].interests * ticket.amount * 10 ** (18-ERC20(ticket.token).decimals());
                    tokens[ticket.token].interestsCumulated -= interests;
                    interestsCumulated -= interests;

                    for(uint256 t = 0; t < ticket.tiers.length; ++t){
                        buckets[ticket.token][ticket.tiers[t].tier][ticket.tiers[t].indexInTicket] = buckets[ticket.token][ticket.tiers[t].tier][buckets[ticket.token][ticket.tiers[t].tier].length - 1];
                        buckets[ticket.token][ticket.tiers[t].tier].pop();
                    }
                }
                
                // Send back the property token
                ERC20(ticket.token).transfer(msg.sender, ticket.amount);
            } else {
                revert NotTicketOwner(_ids[i]);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Request randomness to Witnet in order to do a draw
    function requestDraw() external payable {
        if (block.timestamp < nextDrawTimestamp) {
            revert DrawTooEarly();
        }

        witnetRandomnessBlock = block.number;
        nextDrawTimestamp = block.timestamp + drawInterval;

        uint256 usedFunds = witnetRandomness.randomize{value: msg.value}();
        if (usedFunds < msg.value) {
            (bool ok,) = payable(msg.sender).call{value: msg.value - usedFunds}("");
            if (!ok) {
                revert CouldNotRefund();
            }
        }
    }

    /// @notice Do the draw according to the randomness requested before
    /// @dev The randomness is used to find a winner among all the tickets, which receive the rent of all properties stacked
    function doDraw() external {
        if (witnetRandomnessBlock == 0) {
            revert NoRandomness();
        }

        uint256 randomness = witnetRandomness.random(uint32(interestsCumulated), 0, witnetRandomnessBlock);
        witnetRandomnessBlock = 0;

        uint256 ticketWinner = findRandomNFT(randomness);
        address winner = ownerOf(ticketWinner);

        uint256[] memory prize = prizeToBeWon();

        for (uint256 i = 0; i < rentTokens.length;) {
            // Transfer rent tokens
            uint256 reward = ERC20(rentTokens[i]).balanceOf(address(this));

            ERC20(rentTokens[i]).transferFrom(address(this), winner, reward);

            unchecked {
                ++i;
            }
        }

        uint256 rewardsETH = address(this).balance;
        (bool ok,) = winner.call{value: rewardsETH}(""); // Transfer xDai, if this fail then the next winner will have a double prize !

        if (!ok) {
            prize[0] = 0;
        }

        lastWinner = winner;
        lastPrize = prize;
    }

    /// @notice Find the winner according to the randomness
    function findRandomNFT(uint256 _randomness) public view returns (uint256) {
        for (uint256 i = 0; i < tokensSupported.length;) {
            Token memory token = tokens[tokensSupported[i]];
            
            if (_randomness < token.interestsCumulated) { // the winner is in this token
                for (uint256 tier = greatestTier[tokensSupported[i]]; tier > 0; --tier) {
                    uint256 sumBucket = buckets[tokensSupported[i]][tier].length * tier;

                    if (_randomness < sumBucket) {
                        return buckets[tokensSupported[i]][tier][_randomness / tier];
                    } else {
                        // no underflow possible because of the failed if randomness < sumBucket
                        unchecked {
                            _randomness -= sumBucket;
                        }
                    }
                }

                return tokens[tokensSupported[i]].tickets[tokens[tokensSupported[i]].tickets.length - 1];
            }

            unchecked {
                // no underflow possible because of the failed if randomness < maxWeightToken
                _randomness -= token.interestsCumulated;
                ++i;
            }
        }

        return tokens[tokensSupported[tokensSupported.length - 1]].tickets[tokens[tokensSupported[tokensSupported.length
            - 1]].tickets.length - 1];
    }

    /// @notice Get the prize to be won in the next draw
    function prizeToBeWon() public view returns (uint256[] memory) {
        uint256[] memory prize = new uint256[](rentTokens.length + 1);
        prize[0] = address(this).balance;

        for (uint256 i = 0; i < rentTokens.length;) {
            uint256 reward = ERC20(rentTokens[i]).balanceOf(address(this));
            prize[i + 1] = reward * 10 ** (18 - ERC20(rentTokens[i]).decimals()); // put every token on 18 decimals

            unchecked {
                ++i;
            }
        }

        return prize;
    }

    /// @notice Get the list of property tokens supported
    function getTokensSupported() public view returns (address[] memory) {
        return tokensSupported;
    }

    /// @notice Update the interests of a list of property tokens
    /// @param _tokens The list of property tokens
    /// @param _interests The list of interests
    function setInterests(address[] memory _tokens, uint256[] memory _interests) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length;) {
            uint256 oldInterests = tokens[_tokens[i]].interests;
            uint256 oldCumulated = tokens[_tokens[i]].interestsCumulated;

            tokens[_tokens[i]].interests = _interests[i];
            tokens[_tokens[i]].interestsCumulated = tokens[_tokens[i]].interestsCumulated * _interests[i] / oldInterests;
            interestsCumulated = interestsCumulated + tokens[_tokens[i]].interestsCumulated - oldCumulated;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Add a list of property tokens
    /// @param _tokens The list of property tokens
    /// @param _interests The list of interests
    function addTokens(address[] memory _tokens, uint256[] memory _interests) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length;) {
            tokens[_tokens[i]] = Token(_interests[i], new uint256[](0), 0);
            tokensSupported.push(_tokens[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Set the draw interval
    /// @param _interval The new draw interval
    function setDrawInterval(uint256 _interval) external onlyOwner {
        drawInterval = _interval;
    }

    /// @notice Set the rent tokens
    /// @param _rentTokens The new rent tokens
    function setRentTokens(address[] memory _rentTokens) external onlyOwner {
        rentTokens = _rentTokens;
    }

    /// @notice update witnet contract
    /// @param _witnet The new witnet contract
    function setWitnet(address _witnet) external onlyOwner {
        witnetRandomness = IWitnetRandomness(_witnet);
    }

    /// @notice allows to receive back funds
    receive() external payable {}
}
