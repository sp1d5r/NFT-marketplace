pragma solidity ^0.8.10;

import "../interfaces/ISecondaryMarket.sol";
import "../interfaces/ITicketNFT.sol";
import "./PurchaseToken.sol";

contract SecondaryMarket is ISecondaryMarket {
    PurchaseToken ptoken;
    address admin;

    uint256 private feePercentage = 5;

    struct Bid {
        uint256 amount;
        address bidder;
        string name;
    }

    struct TicketListing {
        bool isListed;
        uint256 price;
        address originalOwner;
    }

    // Ticket Collection -> Ticket ID -> Bid
    mapping(address => mapping(uint256 => Bid)) public highestBid;

    // Ticket Collection -> Ticket ID -> Listing
    mapping(address => mapping(uint256 => TicketListing)) public listings;



    constructor (PurchaseToken _ptoken) {
        ptoken = _ptoken;
        admin = msg.sender;
    }


    function acceptMoneyForEscrow(
        address from,
        uint256 amount
    ) private {
        require(ptoken.allowance(from, address(this)) >= amount, "Token allowance too low");
        bool sent = ptoken.transferFrom(from, address(this), amount);
        require(sent, "Secondary Market: Token transfer to escrow failed");
    }

    function returnMoneyFromEscrow(
        address to,
        uint256 amount
    ) private {
        ptoken.approve(to, amount);
        ptoken.approve(address(this), amount); // I know this seems weird but additional tests needed this
        require(ptoken.allowance(address(this), to) >= amount, "Token allowance too low");
        bool sent = ptoken.transferFrom(address(this), to, amount);
        require(sent, "Secondary Market: Token transfer from escrow failed");
    }

    function isTicketExpired(
        address ticketCollection,
        uint256 ticketID
    ) private returns (bool) {
        ITicketNFT _ticketCollection = ITicketNFT(ticketCollection);
        return _ticketCollection.isExpiredOrUsed(ticketID);
    }

    /**
     * @dev This method lists a ticket with `ticketID` for sale by transferring the ticket
     * such that it is held by this contract. Only the current owner of a specific
     * ticket is able to list that ticket on the secondary market. The purchase
     * `price` is specified in an amount of `PurchaseToken`.
     * Note: Only non-expired and unused tickets can be listed
     */
    function listTicket(
        address ticketCollection,
        uint256 ticketID,
        uint256 price
    ) external {
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection);
        require(!ticketNFT.isExpiredOrUsed(ticketID), "Secondary Market: Ticket is Expired");
        require(!listings[ticketCollection][ticketID].isListed, "Secondary Market: Ticket already listed");
        ticketNFT.transferFrom(msg.sender, address(this), ticketID);

        // Update listing information
        listings[ticketCollection][ticketID] = TicketListing({
        isListed: true,
        price: price,
        originalOwner: msg.sender
        });

        // Reset the highest bid for this listing
        highestBid[ticketCollection][ticketID] = Bid({
        amount: price,
        bidder: address(0),
        name: ""
        });

        emit Listing(
            msg.sender,
            ticketCollection,
            ticketID,
            price
            );
    }

    /**
     * Returns the current highest bid for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (uint256) {
        require(listings[ticketCollection][ticketId].isListed, "Secondary Market: Ticket ID is not Listed");
        return highestBid[ticketCollection][ticketId].amount;
    }

    /** @notice This method allows the msg.sender to submit a bid for the ticket from `ticketCollection` with `ticketID`
     * The `bidAmount` should be kept in escrow by the contract until the bid is accepted, a higher bid is made,
     * or the ticket is delisted.
     * If this is not the first bid for this ticket, `bidAmount` must be strictly higher that the previous bid.
     * `name` gives the new name that should be stated on the ticket when it is purchased.
     * Note: Bid can only be made on non-expired and unused tickets
     */
    function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    ) external {
        TicketListing storage listing = listings[ticketCollection][ticketID];
        Bid storage bid = highestBid[ticketCollection][ticketID];

        require(listing.isListed, "Secondary Market: Ticket ID is not Listed");
        require(bidAmount > bid.amount, "Secondary Market: Bid amount is not high enough");
        require(!isTicketExpired(ticketCollection, ticketID), "SecondaryMarket: Cannot bid on used or expired tickets");
        require(msg.sender != listing.originalOwner, "Secondary Market: Cannot bid on own ticket");
        // Send money to escrow
        acceptMoneyForEscrow(msg.sender, bidAmount);

        // Update the highest bid
        highestBid[ticketCollection][ticketID] = Bid({
            amount: bidAmount,
            bidder: msg.sender,
            name: name
        });

        emit BidSubmitted(msg.sender, ticketCollection, ticketID, bidAmount, name);
    }

    /**
     * Returns the current highest bidder for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (address) {
        require(listings[ticketCollection][ticketId].isListed, "Secondary Market: Ticket ID is not Listed");
        return highestBid[ticketCollection][ticketId].bidder;
    }

    /*
     * @notice Allow the lister of the ticket from `ticketCollection` with `ticketID` to accept the current highest bid.
     * This function reverts if there is currently no bid.
     * Otherwise, it should accept the highest bid, transfer the money to the lister of the ticket,
     * and transfer the ticket to the highest bidder after having set the ticket holder name appropriately.
     * A fee charged when the bid is accepted. The fee is charged on the bid amount.
     * The final amount that the lister of the ticket receives is the price
     * minus the fee. The fee should go to the creator of the `ticketCollection`.
     */
    function acceptBid(address ticketCollection, uint256 ticketID) external {
        TicketListing storage listing = listings[ticketCollection][ticketID];
        Bid storage bid = highestBid[ticketCollection][ticketID];

        require(listing.isListed, "Secondary Market: Ticket ID is not Listed");
        require(listing.originalOwner == msg.sender, "Secondary Market: Only lister can accept bid");

        // Check if a valid bid exists
        if (bid.bidder == address(0)) {
            // No bid has been placed; return ticket to original owner
            ITicketNFT(ticketCollection).transferFrom(address(this), listing.originalOwner, ticketID);
            listing.isListed = false;
        } else {
            // Accept the highest bid
            uint256 transactionFee = (bid.amount * feePercentage) / 100;
            uint256 payableAmount = (bid.amount * (100 - feePercentage)) / 100;

            // Transfer ticket to highest bidder and update holder name
            ITicketNFT ticketNFT = ITicketNFT(ticketCollection);
            ticketNFT.updateHolderName(ticketID, bid.name);
            ticketNFT.transferFrom(address(this), bid.bidder, ticketID);

            // Transfer funds
            ptoken.transfer(listing.originalOwner, payableAmount);
            ptoken.transfer(ticketNFT.creator(), transactionFee); // Assuming fee goes to contract admin

            // Reset listing and bid
            listing.isListed = false;
            delete highestBid[ticketCollection][ticketID];
            emit BidAccepted(bid.bidder, ticketCollection, ticketID, bid.amount, bid.name);
        }
    }


    /** @notice This method delists a previously listed ticket of `ticketCollection` with `ticketID`. Only the account that
     * listed the ticket may delist the ticket. The ticket should be transferred back
     * to msg.sender, i.e., the lister, and escrowed bid funds should be return to the bidder, if any.
     */
    function delistTicket(address ticketCollection, uint256 ticketID) external {
        TicketListing storage listing = listings[ticketCollection][ticketID];
        Bid storage bid = highestBid[ticketCollection][ticketID];

        require(listing.isListed, "Secondary Market: Ticket ID is not Listed");
        require(msg.sender == listing.originalOwner, "Secondary Market: Only the owner can delist a ticket");

        // Transfer the ownership back to the original lister
        ITicketNFT ticketNFT = ITicketNFT(ticketCollection);
        require(!ticketNFT.isExpiredOrUsed(ticketID), "Secondary Market: Ticket is Expired");
        ticketNFT.transferFrom(address(this), listing.originalOwner, ticketID);

        // Reset the listing
        listing.isListed = false;

        // If there's any bids, refund them
        if (bid.bidder != address(0)) {
            returnMoneyFromEscrow(bid.bidder, bid.amount);
        }

        // Reset the highest bid
        delete highestBid[ticketCollection][ticketID];
        emit Delisting(ticketCollection, ticketID);
    }
}