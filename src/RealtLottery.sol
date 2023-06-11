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
        uint256 enteredAt;
    }

    mapping(address => uint256) public interestsPerToken;
    mapping(uint256 => Ticket) public tickets;
    uint256[] public interestsCumulated;                               // cumulative sum of interestsPerToken TODO: find a better way because this is not updatable if the interests of one token change

    uint256 private ticketCounter;

    address[] public rentTokens;

    uint256 public nextDrawTimestamp;                                  // when the next draw can be done 
    uint256 public drawInterval;                                       // how often a draw can be done
    
    constructor(address[] memory tokens, uint256[] memory interests, address[] memory _rentTokens, uint256 nextDraw) ERC721("RealtLottery", "RTL") Ownable() {
        for (uint256 i = 0; i < tokens.length; i++) {
            interestsPerToken[tokens[i]] = interests[i];
        }

        rentTokens = _rentTokens;
        nextDrawTimestamp = nextDraw;
        drawInterval = 6 days + 12 hours;
    }

    function enter(address[] memory tokens, uint256[] memory ids) external {
        for (uint256 i = 0; i < tokens.length;) {
            if(interestsPerToken[tokens[i]] > 0) {
                // owner must approve this contract first
                ERC721(tokens[i]).transferFrom(msg.sender, address(this), ids[i]);  // Take custody of the property token

                // Mint a ticket to be reedemed later for the property token
                tickets[ticketCounter] = Ticket(tokens[i], ids[i], block.timestamp);
                interestsCumulated.push(interestsCumulated.length == 0 ? interestsPerToken[tokens[i]] : interestsCumulated[interestsCumulated.length - 1] + interestsPerToken[tokens[i]]);
                _safeMint(msg.sender, ticketCounter++);
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

                // TODO handle interests cumulated

                // Send back the property token
                ERC721(ticket.token).transferFrom(address(this), msg.sender, ticket.id);
            }

            unchecked {
                ++i;
            }
        }
    }

    function draw() external {
        uint256 randomness = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % interestsCumulated[ticketCounter - 1]; // TODO: improve randomness, skip burned ids
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
        uint256 indexMin = 0;
        uint256 indexMax = ticketCounter - 1;
        uint256 index = indexMax / 2;

        while(indexMin <= indexMax) {
            if(interestsCumulated[index] >= randomness && (index == 0 || interestsCumulated[index - 1] < randomness)){
                return index;
            }
            else{
                if(interestsCumulated[index] < randomness){
                    indexMin = index + 1;
                }
                else{
                    indexMax = index - 1;
                }
                index = (indexMin + indexMax) / 2;
            }
        }

        return ticketCounter - 1;
    }

    function setInterests(address[] memory tokens, uint256[] memory interests) external onlyOwner {
        for (uint256 i = 0; i < tokens.length;) {
            interestsPerToken[tokens[i]] = interests[i];

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
