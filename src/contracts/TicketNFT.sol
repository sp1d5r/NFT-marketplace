pragma solidity ^0.8.1;

import "../interfaces/ITicketNFT.sol";

contract TicketNFT is ITicketNFT {
    // Metadata
    string private collectionName;
    address private owner;
    address private primaryMarket;
    uint256 private totalTickets;

    // Ticket Mapping
    struct Ticket {
        address holder;
        address approved;
        string holderName;
        bool used;
        uint256 expiration;
    }

    // Ticket ID -> Ticket data
    mapping(uint256 => Ticket) private tickets;

    // Address mapping
    mapping(address => uint256) private addressBalances;

    /* Handle Unique ID for token */
    uint256 private tokensMinted;

    constructor (string memory _eventName, uint256 _totalTickets, address _creator) {
        collectionName = _eventName;
        owner = _creator;
        primaryMarket = msg.sender;
        totalTickets = _totalTickets;
        tokensMinted = 0;
    }

    /**
     * @dev Returns the address of the user who created the NFT collection
     * This is the address of the user who called `createNewEvent` in the primary market
     */
    function creator() external view returns (address) {
        return owner;
    }

    /**
     * @dev Returns the maximum number of tickets that can be minted for this event.
     */
    function maxNumberOfTickets() external view returns (uint256) {
        return totalTickets;
    }

    /**
     * @dev Returns the name of the event for this TicketNFT
     */
    function eventName() external view returns (string memory) {
        return collectionName;
    }


    function assignUniqueID() private returns (uint256 id) {
        tokensMinted += 1;
        return tokensMinted;
    }

    /**
     * Mints a new ticket for `holder` with `holderName`.
     * The ticket must be assigned the following metadata:
     * - A unique ticket ID. Once a ticket has been used or expired, its ID should not be reallocated
     * - An expiry time of 10 days from the time of minting
     * - A boolean `used` flag set to false
     * On minting, a `Transfer` event should be emitted with `from` set to the zero address.
     *
     * Requirements:
     *
     * - The caller must be the primary market
     */
    function mint(address holder, string memory holderName) external returns (uint256 id) {
        require(totalTickets > tokensMinted, "ERC-721: Maximum Tokens minted");
        require(msg.sender == primaryMarket, "ERC-721: Owner must be primary market");
        uint256 ticketId = assignUniqueID();

        // Update the Ticket NFT Variables
        tickets[ticketId] = Ticket({
            holder: holder,
            approved: address(0),
            holderName: holderName,
            used: false,
            expiration: block.timestamp + 10 * 1 days
        });

        // Update the balance for the holder
        addressBalances[holder] += 1;
        emit Transfer(address(0), holder, ticketId);
        return ticketId;
    }

    /**
     * @dev Returns the number of tickets a `holder` has.
     */
    function balanceOf(address holder) external view returns (uint256 balance) {
        return addressBalances[holder];
    }

    /**
     * @dev Returns the address of the holder of the `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderOf(uint256 ticketID) external view returns (address holder) {
        require(0 < ticketID && ticketID <= totalTickets, "ERC-721: Ticket doesn't exist.");

        return tickets[ticketID].holder;
    }

    /**
     * @dev Transfers `ticketID` ticket from `from` to `to`.
     * This should also set the approved address for this ticket to the zero address
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - the caller must either:
     *   - own `ticketID`
     *   - be approved to move this ticket using `approve`
     *
     * Emits a `Transfer` and an `Approval` event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external {
        require(ticketID < totalTickets, "ERC-721: Ticket ID is not valid ticket");
        require(tickets[ticketID].holder == from, "ERC-721: Incorrect from address");
        require(tickets[ticketID].approved == msg.sender || tickets[ticketID].holder == msg.sender, "ERC-721: Not authorized");

        // Perform the transfer
        tickets[ticketID].holder = to;
        tickets[ticketID].approved = address(0);
        addressBalances[from] -= 1;
        addressBalances[to] += 1;
        emit Transfer(from, to, ticketID);
        emit Approval(to, address(0), ticketID);
    }

    /**
     * @dev Gives permission to `to` to transfer `ticketID` ticket to another account.
     * The approval is cleared when the ticket is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the ticket
     * - `ticketID` must exist.
     *
     * Emits an `Approval` event.
     */
    function approve(address to, uint256 ticketID) external {
        require(ticketID <= totalTickets, "ERC-721: Ticket doesn't exist.");
        require(to != address(0), "ERC-721: Zero Address.");
        require(msg.sender == tickets[ticketID].holder, "ERC-721: caller does not own the ticket.");
        tickets[ticketID].approved = to;
        emit Approval(msg.sender, to, ticketID);
    }

    /**
     * @dev Returns the account approved for `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function getApproved(uint256 ticketID)
    external
    view
    returns (address operator) {
        return tickets[ticketID].approved;
    }

    /**
     * @dev Returns the current `holderName` associated with a `ticketID`.
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderNameOf(uint256 ticketID)
    external
    view
    returns (string memory holderName) {
        return tickets[ticketID].holderName;
    }

    /**
     * @dev Updates the `holderName` associated with a `ticketID`.
     * Note that this does not update the actual holder of the ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exists
     * - Only the current holder can call this function
     */
    function updateHolderName(uint256 ticketID, string calldata newName)
    external {
        require(msg.sender == tickets[ticketID].holder, "ERC-721: Only ticket holder can call function.");
        tickets[ticketID].holderName = newName;
    }

    /**
     * @dev Sets the `used` flag associated with a `ticketID` to `true`
     *
     * Requirements:
     *
     * - `ticketID` must exist
     * - the ticket must not already be used
     * - the ticket must not be expired
     * - Only the creator of the collection can call this function
     */
    function setUsed(uint256 ticketID) external {
        require(ticketID <= totalTickets, "ERC-721: Ticket ID not valid");
        require(!tickets[ticketID].used, "ERC-721: Ticket already used");
        require(tickets[ticketID].expiration > block.timestamp, "ERC-721: Ticket expired");
        require(msg.sender == owner, "ERC-721: Only the creator of the collection can call used");
        tickets[ticketID].used = true;
    }

    /**
     * @dev Returns `true` if the `used` flag associated with a `ticketID` if `true`
     * or if the ticket has expired, i.e., the current time is greater than the ticket's
     * `expiryDate`.
     * Requirements:
     *
     * - `ticketID` must exist
     */
    function isExpiredOrUsed(uint256 ticketID) external view returns (bool) {
        require(ticketID <= totalTickets, "ERC-721: Ticket ID not valid");
        return tickets[ticketID].expiration < block.timestamp || tickets[ticketID].used;
    }
}
