// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/SecondaryMarket.sol";
import "../src/contracts/PrimaryMarket.sol";

contract PrimaryMarketTest is Test {
    PrimaryMarket primaryMarket;
    PurchaseToken purchaseToken;
    address alice = address(1);
    address bob = address(2);
    string eventName = "Concert";
    uint256 ticketPrice = 1 ether;
    uint256 maxTickets = 100;

    function setUp() public {
        purchaseToken = new PurchaseToken();
        primaryMarket = new PrimaryMarket(purchaseToken);

        // Assuming the deployer (this contract) initially holds all the tokens
        purchaseToken.mint{value: 2000 ether}();
        purchaseToken.transfer(alice, 1000 ether);
        purchaseToken.transfer(bob, 1000 ether);

        // Approve the primaryMarket to spend tokens on behalf of alice and bob
        vm.prank(alice);
        purchaseToken.approve(address(primaryMarket), 1000 ether);
        vm.prank(bob);
        purchaseToken.approve(address(primaryMarket), 1000 ether);
    }

    function testEventCreation() public {
        vm.prank(alice);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);

        assertEq(ticketNFT.eventName(), eventName, "Event name should match");
        assertEq(primaryMarket.getPrice(address(ticketNFT)), ticketPrice, "Price should match");
        assertEq(ticketNFT.maxNumberOfTickets(), maxTickets, "Max tickets should match");
    }

    function testPurchaseFunctionality() public {
        vm.prank(alice);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);

        uint256 aliceBalanceBefore = purchaseToken.balanceOf(alice);
        uint256 bobBalanceBefore = purchaseToken.balanceOf(bob);

        vm.prank(bob);
        uint256 ticketID = primaryMarket.purchase(address(ticketNFT), "Bob");

        assertEq(ticketNFT.holderOf(ticketID), bob, "Bob should be the holder of the purchased ticket");
        assertEq(purchaseToken.balanceOf(bob), bobBalanceBefore - ticketPrice, "Bob's balance should decrease by the ticket price");
        assertEq(purchaseToken.balanceOf(alice), aliceBalanceBefore + ticketPrice, "Alice's balance should increase by the ticket price");
    }


    // Test Purchase Limits
    function testPurchaseLimits() public {
        vm.prank(alice);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);

        // Bob tries to buy all available tickets
        for (uint i = 0; i < maxTickets; i++) {
            uint256 bobBalanceBefore = purchaseToken.balanceOf(bob);
            vm.prank(bob);
            primaryMarket.purchase(address(ticketNFT), "Bob");
            uint256 bobBalanceAfter = purchaseToken.balanceOf(bob);

            // Assert that Bob's balance decreases by the ticket price with each purchase
            assertEq(bobBalanceBefore - ticketPrice, bobBalanceAfter, "Bob's balance should decrease by the ticket price");
        }

        // Attempt to purchase one more ticket beyond the available limit
        uint256 bobBalanceBeforeExtraPurchase = purchaseToken.balanceOf(bob);
        vm.expectRevert("ERC-721: Maximum Tokens minted");
        vm.prank(bob);
        primaryMarket.purchase(address(ticketNFT), "Bob");

        // Assert that Bob's balance hasn't changed after the failed transaction
        uint256 bobBalanceAfterExtraPurchase = purchaseToken.balanceOf(bob);
        assertEq(bobBalanceBeforeExtraPurchase, bobBalanceAfterExtraPurchase, "Bob's balance should remain unchanged after failed purchase");
    }


    // Test Invalid Event Purchase
    function testInvalidEventPurchase() public {
        address invalidEventAddress = address(123); // Assuming this is not a valid event address
        vm.expectRevert("PrimaryMarket: Invalid event address");
        vm.prank(bob);
        primaryMarket.purchase(invalidEventAddress, "Bob");
    }

    // Test Multiple Event Creation
    function testMultipleEventCreation() public {
        // Create first event
        vm.prank(alice);
        ITicketNFT firstEvent = primaryMarket.createNewEvent("First Event", ticketPrice, maxTickets);

        // Create second event
        vm.prank(alice);
        ITicketNFT secondEvent = primaryMarket.createNewEvent("Second Event", ticketPrice, maxTickets);

        // Assert both events are different
        assertTrue(address(firstEvent) != address(secondEvent), "Each event should have a unique address");
    }

    // Test Zero Price Event Creation
    function testZeroPriceEventCreation() public {
        uint256 zeroPrice = 0;
        vm.prank(alice);
        ITicketNFT zeroPriceEvent = primaryMarket.createNewEvent("Free Event", zeroPrice, maxTickets);

        // Assert that a ticket can be purchased for free
        uint256 bobBalanceBefore = purchaseToken.balanceOf(bob);
        vm.prank(bob);
        uint256 ticketID = primaryMarket.purchase(address(zeroPriceEvent), "Bob");

        // Check that Bob's token balance remains the same
        assertEq(purchaseToken.balanceOf(bob), bobBalanceBefore, "Bob's balance should not change for a free ticket");
        assertEq(zeroPriceEvent.holderOf(ticketID), bob, "Bob should hold the purchased ticket");
    }

    function testNFTCollectionDeployment() public {
        string memory newEventName = "New Concert";
        uint256 newTicketPrice = 2 ether;
        uint256 newMaxTickets = 50;

        vm.prank(alice);
        ITicketNFT newTicketNFT = primaryMarket.createNewEvent(newEventName, newTicketPrice, newMaxTickets);

        assertEq(newTicketNFT.eventName(), newEventName, "Event name should match");
        assertEq(primaryMarket.getPrice(address(newTicketNFT)), newTicketPrice, "Ticket price should match");
        assertEq(newTicketNFT.maxNumberOfTickets(), newMaxTickets, "Max tickets should match");
    }

    function testTicketMintingRestriction() public {
        vm.prank(alice);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);

        vm.expectRevert("ERC-721: Owner must be primary market");
        vm.prank(bob);
        ticketNFT.mint(bob, "Bob's Ticket");
    }

    function testERC20TokenTransferOnPurchase() public {
        vm.prank(alice);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);
        uint256 bobTokenBalanceBefore = purchaseToken.balanceOf(bob);
        uint256 aliceTokenBalanceBefore = purchaseToken.balanceOf(alice);

        vm.prank(bob);
        primaryMarket.purchase(address(ticketNFT), "Bob");

        assertEq(purchaseToken.balanceOf(bob), bobTokenBalanceBefore - ticketPrice, "Bob's balance should decrease by the ticket price");
        assertEq(purchaseToken.balanceOf(alice), aliceTokenBalanceBefore + ticketPrice, "Alice's balance should increase by the ticket price");
    }

    function testApprovalRequirementBeforePurchase() public {
        vm.prank(alice);
        ITicketNFT ticketNFT = primaryMarket.createNewEvent(eventName, ticketPrice, maxTickets);

        // Resetting Bob's approval to zero
        vm.prank(bob);
        purchaseToken.approve(address(primaryMarket), 0);

        vm.expectRevert("Insufficient token allowance");
        vm.prank(bob);
        primaryMarket.purchase(address(ticketNFT), "Bob");
    }
}
