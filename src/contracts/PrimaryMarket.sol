pragma solidity ^0.8.10;

import "../interfaces/IPrimaryMarket.sol";
import "./PurchaseToken.sol";
import "./TicketNFT.sol";

contract PrimaryMarket is IPrimaryMarket {
    PurchaseToken pToken;
    mapping(address => ITicketNFT) events;
    mapping(address => uint256) prices;

    constructor (PurchaseToken _pToken) {
        pToken = _pToken;
    }

    /**
     *
     * @param eventName is the name of the event to create
     * @param price is the price of a single ticket for this event
     * @param maxNumberOfTickets is the maximum number of tickets that can be created for this event
     */
    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection) {
        ticketCollection = new TicketNFT(eventName, maxNumberOfTickets, msg.sender);
        events[address(ticketCollection)] = ticketCollection;
        prices[address(ticketCollection)] = price;
        return ticketCollection;
    }

    /**
     * @notice Allows a user to purchase a ticket from `ticketCollectionNFT`
     * @dev Takes the initial NFT token holder's name as a string input
     * and transfers ERC20 tokens from the purchaser to the creator of the NFT collection
     * @param ticketCollection the collection from which to buy the ticket
     * @param holderName the name of the buyer
     * @return id of the purchased ticket
     */
    function purchase(
        address ticketCollection,
        string memory holderName
    ) external returns (uint256 id) {
        require(address(events[ticketCollection]) != address(0), "PrimaryMarket: Invalid event address");
        ITicketNFT ticketNFT = events[ticketCollection];
        uint256 ticketPrice = prices[ticketCollection];
        require(pToken.allowance(msg.sender, address(this)) >= ticketPrice, "Insufficient token allowance");
        pToken.transferFrom(msg.sender, ticketNFT.creator(), ticketPrice);
        return ticketNFT.mint(msg.sender, holderName);
    }

    /**
     * @param ticketCollection the collection from which to get the price
     * @return price of a ticket for the event associated with `ticketCollection`
     */
    function getPrice(
        address ticketCollection
    ) external view returns (uint256 price) {
        return prices[ticketCollection];
    }
}