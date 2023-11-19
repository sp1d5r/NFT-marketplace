pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/contracts/PurchaseToken.sol";
import "../src/interfaces/ITicketNFT.sol";
import "../src/contracts/PrimaryMarket.sol";
import "../src/contracts/SecondaryMarket.sol";

contract TicketCreation is Test {
    address public alice = makeAddr("alice");
    PurchaseToken public purchaseToken;
    ITicketNFT public ticketNFT;
    string public eventName;
    uint256 totalTickets = 100;

    function setUp() public {
        purchaseToken = new PurchaseToken();
        payable(alice).transfer(1e18);
        eventName = "Test Event";
        totalTickets = 100;
        ticketNFT = new TicketNFT(eventName, totalTickets, alice);
    }

    function testEventNameMatch() external {
        vm.prank(alice);
        assertEq(ticketNFT.eventName(), "Test Event", "Event name should match");
    }

    function testCreator() external {
        vm.prank(alice);
        assertEq(ticketNFT.creator(), alice, "Event name should match");
        vm.prank(address(this));
        assertEq(ticketNFT.creator(), alice, "Event name should match");
    }

    function testCreatorHasntGotTickets() external {
        vm.prank(alice);
        assertEq(ticketNFT.balanceOf(alice), 0, "Creator shouldn't have tickets.");
    }

    function testTotalNumberOfTickets() external {
        assertEq(ticketNFT.maxNumberOfTickets(), totalTickets, "Total tickets should match");
    }

    function testTicketsShouldntExist() external {
        vm.expectRevert("ERC-721: Ticket doesn't exist.");
        ticketNFT.holderOf(0);
        vm.expectRevert("ERC-721: Ticket doesn't exist.");
        ticketNFT.holderOf(101);
    }

    function testTicketsThatExist() external {
        assertEq(ticketNFT.holderOf(1), address(0), "Ticket exists but no one hold it.");
        assertEq(ticketNFT.holderOf(25), address(0), "Ticket exists but no one hold it.");
        assertEq(ticketNFT.holderOf(50), address(0), "Ticket exists but no one hold it.");
        assertEq(ticketNFT.holderOf(75), address(0), "Ticket exists but no one hold it.");
        assertEq(ticketNFT.holderOf(90), address(0), "Ticket exists but no one hold it.");
        assertEq(ticketNFT.holderOf(99), address(0), "Ticket exists but no one hold it.");
        assertEq(ticketNFT.holderOf(100), address(0), "Ticket exists but no one hold it.");
    }
}