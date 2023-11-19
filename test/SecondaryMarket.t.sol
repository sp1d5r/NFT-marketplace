// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/SecondaryMarket.sol";
import "../src/contracts/PrimaryMarket.sol";

contract SecondaryMarketTest is Test {
    PrimaryMarket primaryMarket;
    PurchaseToken purchaseToken;
    SecondaryMarket secondaryMarket;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    string eventName = "Concert";
    uint256 ticketPrice = 1 ether;
    uint256 maxTickets = 100;
    uint256 feePercentage = 5;

    ITicketNFT ticketNFT;
    uint256 ticketID;

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);
        secondaryMarket = new SecondaryMarket(purchaseToken);
        payable(alice).transfer(10000 ether);
        payable(bob).transfer(10000 ether);
        payable(charlie).transfer(10000 ether);

        vm.startPrank(alice);
        purchaseToken.mint{value: 1000 ether}();
        purchaseToken.approve(address(primaryMarket), 5000 ether);
        purchaseToken.approve(address(secondaryMarket), 5000 ether);
        assertEq(purchaseToken.balanceOf(alice), 1000 ether * 100, "Alice Balance is Off");
        vm.stopPrank();

        vm.startPrank(bob);
        purchaseToken.mint{value: 1000 ether}();
        purchaseToken.approve(address(primaryMarket), 5000 ether);
        purchaseToken.approve(address(secondaryMarket), 5000 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        purchaseToken.mint{value: 1000 ether}();
        purchaseToken.approve(address(primaryMarket), 5000 ether);
        purchaseToken.approve(address(secondaryMarket), 5000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);
        ticketID = primaryMarket.purchase(address(ticketNFT), "Alice");

        // Transfer to Charlie;
        ticketNFT.transferFrom(alice, charlie, ticketID);
        vm.stopPrank();

        vm.startPrank(charlie);
        // Transfer the ticket to the SecondaryMarket contract
        ticketNFT.approve(address(secondaryMarket), ticketID);
        secondaryMarket.listTicket(address(ticketNFT), ticketID, ticketPrice);
        vm.stopPrank();
    }


    // Test Listing a Ticket
    function testListingTicket() public {
        // Verify that the ticket is held by the SecondaryMarket contract
//        ITicketNFT ticketNFT = ITicketNFT(primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets));
        assertEq(ticketNFT.holderOf(ticketID), address(secondaryMarket), "SecondaryMarket should hold the listed ticket");
    }

    // Test Submitting a Bid
    function testSubmittingBid() public {
        vm.prank(bob);
        secondaryMarket.submitBid(address(ticketNFT), ticketID, 2 ether, "Bob");

        // Verify bid details
        assertEq(secondaryMarket.getHighestBid(address(ticketNFT), ticketID), 2 ether, "Bid amount should be recorded");
        assertEq(secondaryMarket.getHighestBidder(address(ticketNFT), ticketID), bob, "Bob should be the highest bidder");
    }

    // Test Accepting a Bid
    function testAcceptingBid() public {
        vm.prank(bob);
        secondaryMarket.submitBid(address(ticketNFT), ticketID, 2 ether, "Bob");

        assertEq(purchaseToken.balanceOf(alice), 1000 ether * 100, "Alice has 1000 * 100 ether.");
        assertEq(purchaseToken.balanceOf(charlie), 1000 ether * 100, "Charlie has 1000 * 100 ether.");
        assertEq(secondaryMarket.getHighestBid(address(ticketNFT), ticketID), 2 ether, "Highest Bid is 2 Ether");
        vm.prank(charlie);
        secondaryMarket.acceptBid(address(ticketNFT), ticketID);

        uint256 totalValue = (2 ether * 95) / 100;
        uint256 transactionValue = (2 ether * 5) / 100;

        // Verify post-acceptance details
        ticketNFT = ITicketNFT(address(ticketNFT));
        assertEq(ticketNFT.holderOf(ticketID), bob, "Bob should now own the ticket");

        assertEq(purchaseToken.balanceOf(alice), 1000 ether * 100 + transactionValue, "Alice should recieve the 5% fees");
        assertEq(purchaseToken.balanceOf(charlie), 1000 ether * 100 + totalValue, "Charlie should bid value minus fees");
    }

    // Test Delisting a Ticket
    function testDelistingTicket() public {
        vm.prank(charlie);
        secondaryMarket.delistTicket(address(ticketNFT), ticketID);
        assertEq(ticketNFT.holderOf(ticketID), charlie, "Charlie should get the ticket back after delisting");
    }

    // Testing for insufficient values
    function testBiddingWithInsufficientFunds() public {
        vm.prank(alice); // Alice has insufficient funds
        vm.expectRevert("Token allowance too low");
        secondaryMarket.submitBid(address(ticketNFT), ticketID, 20000 ether, "Alice");
    }

    // Testing more bids - charlie bidding for his own ticket? bit of a weird one...
    function testIncreasingBidAmount() public {
        submitBidForTicket(ticketID, bob, 2 ether);

        vm.prank(charlie);
        vm.expectRevert("Secondary Market: Bid amount is not high enough");
        secondaryMarket.submitBid(address(ticketNFT), ticketID, 1 ether, "Charlie");
    }

    // Making sure non-owners can't delist something
    function testNonOwnerDelistingRejection() public {
        vm.prank(bob); // Bob is not the lister
        vm.expectRevert("Secondary Market: Only the owner can delist a ticket");
        secondaryMarket.delistTicket(address(ticketNFT), ticketID);
    }

    // make sure you can't list a ticket that's already listed
    function testListingAlreadyListedTicket() public {
        vm.prank(charlie);
        vm.expectRevert("Secondary Market: Ticket already listed");
        secondaryMarket.listTicket(address(ticketNFT), ticketID, ticketPrice);
    }

    // Making sure people who didn't lsit can't accept
    function testAcceptBidByNonLister() public {
        submitBidForTicket(ticketID, bob, 2 ether);

        vm.prank(bob); // Bob is not the lister
        vm.expectRevert("Secondary Market: Only lister can accept bid");
        secondaryMarket.acceptBid(address(ticketNFT), ticketID);
    }

    // Test Attempting to Accept a Bid with No Active Bids
    function testAttemptAcceptBidWithNoActiveBids() public {
        // Check initial states: ticket holder is the Secondary Market
        assertEq(ticketNFT.holderOf(ticketID), address(secondaryMarket), "Secondary Market should initially hold the ticket");

        // Attempt to accept a bid when no bids are active
        vm.prank(charlie);
        secondaryMarket.acceptBid(address(ticketNFT), ticketID);

        // Check that the ticket is returned to Charlie
        assertEq(ticketNFT.holderOf(ticketID), charlie, "Charlie should regain possession of the ticket after accepting bid with no active bids");
    }



    function testBidOnExpiredOrUsedTicket() public {
        vm.warp(block.timestamp + 11 days);
        vm.prank(bob);
        vm.expectRevert("SecondaryMarket: Cannot bid on used or expired tickets");
        secondaryMarket.submitBid(address(ticketNFT), ticketID, 2 ether, "Bob");
    }

    // Test Delisting a Ticket with an Active Bid
    function testDelistingTicketWithBid() public {
        submitBidForTicket(ticketID, bob, 2 ether);

        // Check initial balances
        uint256 bobBalanceBeforeDelisting = purchaseToken.balanceOf(bob);

        // Delist the ticket
        vm.prank(charlie);
        secondaryMarket.delistTicket(address(ticketNFT), ticketID);

        // Assert that the ticket is returned to the original lister (Charlie)
        assertEq(ticketNFT.holderOf(ticketID), charlie, "Charlie should get the ticket back after delisting");

        // Assert that the bid amount is refunded to the bidder (Bob)
        uint256 bobBalanceAfterDelisting = purchaseToken.balanceOf(bob);
        assertEq(bobBalanceAfterDelisting, bobBalanceBeforeDelisting + 2 ether, "Bob should be refunded the bid amount");
    }


    // Helper function to submit a bid for a ticket
    function submitBidForTicket(uint256 _ticketID, address bidder, uint256 bidAmount) internal {
        vm.prank(bidder);
        secondaryMarket.submitBid(address(ticketNFT), _ticketID, bidAmount, "New Ticket Name");
    }

    // More tests on bid deductions
    function testFeeDeductionOnBidAcceptance() public {
        submitBidForTicket(ticketID, bob, 2 ether);

        uint256 charlieBalanceBefore = purchaseToken.balanceOf(charlie);
        uint256 aliceBalanceBefore = purchaseToken.balanceOf(alice);

        vm.prank(charlie);
        secondaryMarket.acceptBid(address(ticketNFT), ticketID);

        uint256 expectedFee = (2 ether * feePercentage) / 100;
        assertEq(purchaseToken.balanceOf(charlie), charlieBalanceBefore + (2 ether - expectedFee), "Charlie should receive bid amount minus fee");
        assertEq(purchaseToken.balanceOf(alice), aliceBalanceBefore + expectedFee, "Alice should receive the fee");
    }


    function testListingOfUsedTicket() public {
        vm.prank(alice);
        ticketNFT.setUsed(ticketID);

        vm.prank(charlie); // Charlie attempts to list the used ticket
        vm.expectRevert("Secondary Market: Ticket is Expired");
        secondaryMarket.listTicket(address(ticketNFT), ticketID, ticketPrice);
    }

    function testBiddingOnOwnTicket() public {
        vm.prank(charlie); // Charlie attempts to bid on his own ticket
        vm.expectRevert("Secondary Market: Cannot bid on own ticket");
        secondaryMarket.submitBid(address(ticketNFT), ticketID, 2 ether, "Charlie");
    }

    function testMultipleBidsAndBidOverwriting() public {
        submitBidForTicket(ticketID, bob, 2 ether);
        submitBidForTicket(ticketID, alice, 3 ether);
        vm.expectRevert("Secondary Market: Bid amount is not high enough");
        submitBidForTicket(ticketID, alice, 3 ether);

        assertEq(secondaryMarket.getHighestBid(address(ticketNFT), ticketID), 3 ether, "Alice's bid should be the highest");
        assertEq(secondaryMarket.getHighestBidder(address(ticketNFT), ticketID), alice, "Alice should be the highest bidder");
    }


}
