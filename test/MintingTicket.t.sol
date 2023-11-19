pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";


contract MintingTicket is Test {
    TicketNFT ticketNFT;
    address alice = address(1);
    address bob = address(2);
    string eventName = "Concert";
    uint256 totalTickets = 100;

    function setUp() public {
        vm.prank(alice);
        ticketNFT = new TicketNFT(eventName, totalTickets, alice);
    }

    function testMintingSuccess() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");
        assertEq(ticketNFT.holderOf(ticketID), bob, "Holder should be Bob");
        assertEq(ticketNFT.holderNameOf(ticketID), "Bob's Ticket", "Holder name should be Bob's Ticket");
    }

    function testMintingLimit() public {
        for (uint i = 0; i < totalTickets; i++) {
            vm.prank(alice);
            ticketNFT.mint(bob, "Bob's Ticket");
        }
        vm.expectRevert("ERC-721: Maximum Tokens minted");
        vm.prank(alice);
        ticketNFT.mint(bob, "Bob's Ticket");
    }

    function testBalanceOf() public {
        vm.prank(alice);
        ticketNFT.mint(bob, "Bob's Ticket");
        assertEq(ticketNFT.balanceOf(bob), 1, "Bob should have 1 ticket");
    }


    function testHolderOfInvalidTicketID() public {
        vm.expectRevert("ERC-721: Ticket doesn't exist.");
        ticketNFT.holderOf(totalTickets + 1);
    }

    function testTransfer() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        vm.prank(bob);
        ticketNFT.transferFrom(bob, alice, ticketID);
        assertEq(ticketNFT.holderOf(ticketID), alice, "Alice should now own the ticket");
    }

    function testApproval() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        vm.prank(bob);
        ticketNFT.approve(alice, ticketID);
        assertEq(ticketNFT.getApproved(ticketID), alice, "Alice should be approved for the ticket");
    }

    function testUpdateHolderName() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        vm.prank(bob);
        ticketNFT.updateHolderName(ticketID, "New Name");
        assertEq(ticketNFT.holderNameOf(ticketID), "New Name", "Holder name should be updated");
    }

    function testSetUsed() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        vm.prank(alice); // Assuming only creator can mark as used
        ticketNFT.setUsed(ticketID);
        assertEq(ticketNFT.isExpiredOrUsed(ticketID), true, "Ticket should be marked as used");
    }

    function testExpirationLogic() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        assertEq(!ticketNFT.isExpiredOrUsed(ticketID), true, "Ticket should not be expired initially");

        vm.warp(block.timestamp + 11 days); // Simulating time passing beyond expiration
        assertEq(ticketNFT.isExpiredOrUsed(ticketID), true, "Ticket should be expired now");
    }

    function testNoReMintingOfTicketID() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        // Simulate ticket use or expiration
        vm.prank(alice);
        ticketNFT.setUsed(ticketID);

        // Attempt to mint another ticket and assert the ID is different
        vm.prank(alice);
        uint256 newTicketID = ticketNFT.mint(bob, "Bob's New Ticket");
        assertTrue(ticketID!=newTicketID, "New ticket should have a different ID");
    }

    function testHolderNameChangeRestriction() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        // Attempt to change the holder name by a non-holder
        vm.expectRevert("ERC-721: Only ticket holder can call function.");
        vm.prank(alice);
        ticketNFT.updateHolderName(ticketID, "Alice's Ticket");
    }

    function testExpiredTicketCannotBeUsed() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        vm.warp(block.timestamp + 11 days); // Simulate time passing beyond expiration

        vm.expectRevert("ERC-721: Ticket expired");
        vm.prank(alice);
        ticketNFT.setUsed(ticketID);
    }

    function testApprovalClearingOnTransfer() public {
        vm.prank(alice);
        uint256 ticketID = ticketNFT.mint(bob, "Bob's Ticket");

        vm.prank(bob);
        ticketNFT.approve(alice, ticketID);

        vm.prank(bob);
        ticketNFT.transferFrom(bob, alice, ticketID);

        assertEq(ticketNFT.getApproved(ticketID), address(0), "Approval should be cleared after transfer");
    }
}
