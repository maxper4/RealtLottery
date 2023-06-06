// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";

contract RealtLottery is Ownable, ERC721, ERC721Holder {
    struct Ticket {
        address token;
        uint256 id;
        uint256 enteredAt;
    }

    mapping(address => uint256) public interestsPerToken;
    mapping(uint256 => Ticket) public tickets;

    uint256 private ticketCounter;

    address[] public rentTokens;
    
    constructor(address[] memory tokens, uint256[] memory interests) ERC721("RealtLottery", "RTL") Ownable() {
        for (uint256 i = 0; i < tokens.length; i++) {
            interestsPerToken[tokens[i]] = interests[i];
        }

        rentTokens = new address[](0);
        rentTokens.push(0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83);
        rentTokens.push(0x7349C9eaA538e118725a6130e0f8341509b9f8A0);
    }

    function setInterests(address[] memory tokens, uint256[] memory interests) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            interestsPerToken[tokens[i]] = interests[i];
        }
    }

    function enter(address[] memory tokens, uint256[] memory ids) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            if(interestsPerToken[tokens[i]] > 0) {
                ERC721(tokens[i]).transferFrom(msg.sender, address(this), ids[i]);  // Take custody of the property token

                // Mint a ticket to be reedemed later for the property token
                tickets[ticketCounter] = Ticket(tokens[i], ids[i], block.timestamp);
                _safeMint(msg.sender, ticketCounter++);
            }
        }
    }

    function exit(uint256[] memory ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            if(ownerOf(ids[i]) == msg.sender) {
                Ticket memory ticket = tickets[ids[i]];
                
                // remove the ticket
                _burn(ids[i]);
                delete tickets[ids[i]];

                // Send back the property token
                ERC721(ticket.token).transferFrom(address(this), msg.sender, ticket.id);
            }
        }
    }

    function draw() public {
        uint256 ticketWinner = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % ticketCounter; // TODO: improve randomness, add probability, skip burned ids
        address winner = ownerOf(ticketWinner);

        // TODO require winner to be a renter (check if the token was stacked before the last reception of the last rent)

        for(uint256 i = 0; i < rentTokens.length; i++) {    // Transfer rent tokens
            uint256 reward = IERC20(rentTokens[i]).balanceOf(address(this));
            IERC20(rentTokens[i]).transferFrom(address(this), winner, reward);
        }

        payable(winner).transfer(address(this).balance);        // Transfer xDai
    }
}
