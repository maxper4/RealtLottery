// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";

error DrawTooEarly();
error TokenNotSupported(address token);
error TicketNotReady(uint256 ticket);
error NotTicketOwner(uint256 ticket);

/// @title RealT Lottery: a lottery where you can win the rent of every staked property
/// @author maxper
/// @notice  Users can enter with a token from RealT, stack it and wait for the next draw
contract RealtLottery is Ownable, ERC721, ERC721Holder {
    struct Ticket {                                                     // A ticket is a wrapper around a property token
        address token;
        uint256 id;
        uint256 indexInToken;
        uint256 enteredAt;
        bool stacked;
    }

    struct Token {                                                      // A token represent a property that generate interests
        uint256 interests;
        uint256[] tickets;
    }

    address[] public tokensSupported;                                   // list of supported property tokens
    mapping(address => Token) public tokens;                            // all tokens

    mapping(uint256 => Ticket) public tickets;                          // all tickets
    uint256 public interestsCumulated;

    uint256 private ticketCounter;                                      // counter for ticket ids

    address[] public rentTokens;                                        // every token that can be used to pay rent (xDai, USDC, etc..)

    uint256 public nextDrawTimestamp;                                  // when the next draw can be done 
    uint256 public drawInterval;                                       // minimum delay between two draws
    
    constructor(address[] memory _tokens, uint256[] memory _interests, address[] memory _rentTokens, uint256 _nextDraw) ERC721("RealtLottery", "RTL") Ownable() {
        for (uint256 i = 0; i < _tokens.length; ++i) {
            tokens[_tokens[i]] = Token(_interests[i], new uint256[](0));
            tokensSupported.push(_tokens[i]);
        }

        rentTokens = _rentTokens;
        nextDrawTimestamp = _nextDraw;
        drawInterval = 6 days + 12 hours;
    }

    /// @notice Enter the lottery with a list of property tokens
    /// @param _tokens The list of property tokens
    /// @param _ids  Each id in each property token
    function enter(address[] memory _tokens, uint256[][] memory _ids) external {
        for (uint256 i = 0; i < _tokens.length;) {
            if(tokens[_tokens[i]].interests != 0) {
                for (uint256 indexToken = 0; indexToken < _ids[i].length; ++indexToken) {
                     // owner must approve this contract first
                    ERC721(_tokens[i]).transferFrom(msg.sender, address(this), _ids[i][indexToken]);  // Take custody of the property token

                    // Mint a ticket to be reedemed later for the property token
                    tickets[ticketCounter] = Ticket(_tokens[i], _ids[i][indexToken], 0, block.timestamp, false);

                    _safeMint(msg.sender, ticketCounter++);
                }
            }
            else {
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
            if(ownerOf(_tickets[i]) == msg.sender) {
                Ticket memory ticket = tickets[_tickets[i]];
                if(!ticket.stacked && block.timestamp - ticket.enteredAt >= drawInterval) {
                    ticket.stacked = true;
                    ticket.indexInToken = tokens[ticket.token].tickets.length;
                    tokens[ticket.token].tickets.push(_tickets[i]);
                    tickets[_tickets[i]] = ticket;

                    interestsCumulated += tokens[ticket.token].interests;
                }
                else {
                    revert TicketNotReady(_tickets[i]);
                }
            }
            else {
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
            if(ownerOf(_ids[i]) == msg.sender) {
                Ticket memory ticket = tickets[_ids[i]];
                
                // remove the ticket
                _burn(_ids[i]);
                delete tickets[_ids[i]];

                if(ticket.stacked) {
                     uint256 swapped = tokens[ticket.token].tickets[tokens[ticket.token].tickets.length - 1];
                    tickets[swapped].indexInToken = ticket.indexInToken;
                    tokens[ticket.token].tickets[ticket.indexInToken] = swapped;
                    tokens[ticket.token].tickets.pop();
                    interestsCumulated -= tokens[ticket.token].interests;
                }

                // Send back the property token
                ERC721(ticket.token).transferFrom(address(this), msg.sender, ticket.id);
            }
            else {
                revert NotTicketOwner(_ids[i]);
            }

            unchecked {
                ++i;
            }
        }
    } 

    /// @notice Draw a winner and send him the rent of every stacked property token
    function draw() external {
        if(block.timestamp < nextDrawTimestamp) {
            revert DrawTooEarly();
        }

        uint256 randomness = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % interestsCumulated; // TODO: improve randomness

        uint256 ticketWinner = findRandomNFT(randomness);
        address winner = ownerOf(ticketWinner);

        nextDrawTimestamp = block.timestamp + drawInterval;

        for(uint256 i = 0; i < rentTokens.length;) {    // Transfer rent tokens
            uint256 reward = IERC20(rentTokens[i]).balanceOf(address(this));
            IERC20(rentTokens[i]).transferFrom(address(this), winner, reward);

            unchecked {
                ++i;
            }
        }

        winner.call{value: address(this).balance}(""); // Transfer xDai, if this fail then the next winner will have a double prize !
    }

    /// @notice Find the winner according to the randomness
    function findRandomNFT(uint256 _randomness) public view returns(uint256) {
        for(uint256 i = 0; i < tokensSupported.length; ++i) {
            Token memory token = tokens[tokensSupported[i]];
            uint256 maxWeightToken = token.tickets.length * token.interests;
            if(_randomness < maxWeightToken) {
                return token.tickets[_randomness /= token.interests];
            }

            unchecked { // no underflow possible because of the failed if randomness < maxWeightToken
                _randomness -= maxWeightToken;
            }
        }

        return tokens[tokensSupported[tokensSupported.length - 1]].tickets[tokens[tokensSupported[tokensSupported.length - 1]].tickets.length - 1];
    }

    /// @notice Update the interests of a list of property tokens
    /// @param _tokens The list of property tokens
    /// @param _interests The list of interests
    function setInterests(address[] memory _tokens, uint256[] memory _interests) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length;) {
            tokens[_tokens[i]].interests = _interests[i];

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
            tokens[_tokens[i]] = Token(_interests[i], new uint256[](0));
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
}
