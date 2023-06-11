// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";

error DrawTooEarly();

contract RealtLottery is Ownable, ERC721, ERC721Holder {
    struct Ticket {
        address token;
        uint256 id;
        uint256 indexInToken;
        uint256 enteredAt;
    }

    struct Token {
        uint256 interests;
        uint256[] tickets;
    }

    Token[] public tokens;
    mapping(address => uint256) public indexOfTokens;

    mapping(uint256 => Ticket) public tickets;
    uint256 public interestsCumulated;

    uint256 private ticketCounter;

    address[] public rentTokens;

    uint256 public nextDrawTimestamp;                                  // when the next draw can be done 
    uint256 public drawInterval;                                       // how often a draw can be done
    
    constructor(address[] memory _tokens, uint256[] memory interests, address[] memory _rentTokens, uint256 nextDraw) ERC721("RealtLottery", "RTL") Ownable() {
        for (uint256 i = 0; i < _tokens.length; ++i) {
            tokens.push(Token(interests[i], new uint256[](0)));
            indexOfTokens[_tokens[i]] = i;
        }

        rentTokens = _rentTokens;
        nextDrawTimestamp = nextDraw;
        drawInterval = 6 days + 12 hours;
    }

    function enter(address[] memory _tokens, uint256[][] memory ids) external {
        for (uint256 i = 0; i < _tokens.length;) {
            if(tokens[indexOfTokens[_tokens[i]]].interests != 0) {
                for (uint256 indexToken = 0; indexToken < ids[i].length; ++indexToken) {
                     // owner must approve this contract first
                    ERC721(_tokens[i]).transferFrom(msg.sender, address(this), ids[i][indexToken]);  // Take custody of the property token

                    // Mint a ticket to be reedemed later for the property token
                    tickets[ticketCounter] = Ticket(_tokens[i], ids[i][indexToken], tokens[indexOfTokens[_tokens[i]]].tickets.length, block.timestamp);
                    tokens[indexOfTokens[_tokens[i]]].tickets.push(ticketCounter);
                    interestsCumulated += tokens[indexOfTokens[_tokens[i]]].interests;

                    _safeMint(msg.sender, ticketCounter++);
                }
               
            }

            unchecked {
                ++i;
            }
        }
    }

    function exit(uint256[] memory ids) external {
        for (uint256 i = 0; i < ids.length;) {
            if(ownerOf(ids[i]) == msg.sender) {
                Ticket memory ticket = tickets[ids[i]];
                
                // remove the ticket
                _burn(ids[i]);
                delete tickets[ids[i]];

                uint256 swapped = tokens[indexOfTokens[ticket.token]].tickets[tokens[indexOfTokens[ticket.token]].tickets.length - 1];
                tickets[swapped].indexInToken = ticket.indexInToken;
                tokens[indexOfTokens[ticket.token]].tickets[ticket.indexInToken] = swapped;
                tokens[indexOfTokens[ticket.token]].tickets.pop();

                interestsCumulated -= tokens[indexOfTokens[ticket.token]].interests;

                // Send back the property token
                ERC721(ticket.token).transferFrom(address(this), msg.sender, ticket.id);
            }

            unchecked {
                ++i;
            }
        }
    } 

    function draw() external {
        uint256 randomness = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % interestsCumulated; // TODO: improve randomness
        uint256 ticketWinner = findRandomNFT(randomness);
        address winner = ownerOf(ticketWinner);

        if(block.timestamp < nextDrawTimestamp) {
            revert DrawTooEarly();
        }
        
        nextDrawTimestamp = block.timestamp + drawInterval;

        // TODO require winner to be a renter (check if the token was stacked before the last reception of the last rent)

        for(uint256 i = 0; i < rentTokens.length;) {    // Transfer rent tokens
            uint256 reward = IERC20(rentTokens[i]).balanceOf(address(this));
            IERC20(rentTokens[i]).transferFrom(address(this), winner, reward);

            unchecked {
                ++i;
            }
        }

        winner.call{value: address(this).balance}(""); // Transfer xDai, if this fail then the next winner will have a double prize !
    }

    function findRandomNFT(uint256 randomness) public view returns(uint256) {
        for(uint256 i = 0; i < tokens.length; ++i) {
            Token memory token = tokens[i];
            uint256 maxWeightToken = token.tickets.length * token.interests;
            if(randomness < maxWeightToken) {
                return token.tickets[randomness /= token.interests];
            }

            randomness -= maxWeightToken;
        }

        return tokens[tokens.length - 1].tickets[tokens[tokens.length - 1].tickets.length - 1];
    }

    function setInterests(address[] memory _tokens, uint256[] memory interests) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length;) {
            tokens[indexOfTokens[_tokens[i]]].interests = interests[i];

            unchecked {
                ++i;
            }
        }
    }

    function setDrawInterval(uint256 interval) external onlyOwner {
        drawInterval = interval;
    }

    function setRentTokens(address[] memory _rentTokens) external onlyOwner {
        rentTokens = _rentTokens;
    }
}
