// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//import "hyperlane/Router.sol";
import "openzeppelin-contracts/access/Ownable2Step.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract Hyperchat is Ownable2Step {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                EVENTS/ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    event ConversationCreated(bytes32 indexed conversationID, bytes32 indexed initiator);
    event AdminApprovalAdded(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed approval);
    event AdminApprovalRemoved(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed approval);
    event AdminAdded(bytes32 indexed conversationID, bytes32 indexed admin);
    event AdminRemoved(bytes32 indexed conversationID, bytes32 indexed admin);
    event ParticipantAdded(bytes32 indexed conversationID, bytes32 indexed participant);
    event ParticipantRemoved(bytes32 indexed conversationID, bytes32 indexed participant);
    event ChainAdded(bytes32 indexed conversationID, bytes32 indexed domainID);
    event ChainRemoved(bytes32 indexed conversationID, bytes32 indexed domainID);
    event MessageSent(bytes32 indexed conversationID, bytes indexed message, bytes32 indexed sender);
    event MessageReceived(bytes32 indexed conversationID, bytes indexed message, bytes32 indexed sender);

    error InvalidConversation();
    error InvalidParticipant();
    error InvalidInstance();
    error InvalidLength();
    error NotAdmin();
    error AdminApprovals();
    error AlreadyApproved();

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Hyperlane data structures
    uint32 private immutable HYPERLANE_DOMAIN_IDENTIFIER;
    address private immutable HYPERLANE_OUTBOX;

    struct Message {
        uint256 conversationID;
        uint256 timestamp;
        bytes32 sender;
        bytes message;
    }
    // conversationID => messageNum => Message data struct
    mapping(bytes32 => mapping(uint256 => Message)) private _messages;

    struct Conversation {
        uint256 messageCount;
        bytes32 conversationID;
        uint32[] domainIDs;
        bytes32[] admins;
        mapping(bytes32 => bool) isAdmin;
        mapping(bytes32 => mapping(bytes32 => bool)) adminApprovals;
        mapping(bytes32 => bool) parties;
    }
    // conversationID => Conversation data struct
    mapping(bytes32 => Conversation) private _conversations;
    uint256 private conversationCount;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    modifier requireValid(bytes32 _conversationID) {
        if (_conversations[_conversationID].conversationID == 0) {
            revert InvalidConversation();
        }
        if (!_conversations[_conversationID].parties[addressToBytes32(msg.sender)]) {
            revert InvalidParticipant();
        }
        _;
    }

    modifier onlyAdmin(bytes32 _conversationID) {
        if (!_conversations[_conversationID].isAdmin[addressToBytes32(msg.sender)]) {
            revert NotAdmin();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    constructor(uint32 _hyperlaneDomainID, address _hyperlaneOutbox) payable {
        // Transfer ownership of the contract to deployer
        _transferOwnership(msg.sender);
        
        // Set to Hyperlane Domain Identifier of Station chain
        HYPERLANE_DOMAIN_IDENTIFIER = _hyperlaneDomainID;
        // Set to Hyperlane Outbox on Station chain
        HYPERLANE_OUTBOX = _hyperlaneOutbox;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                MANAGEMENT
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                LIBRARY
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Converts string to bytes
    function stringToBytes(string memory _string) public pure returns (bytes memory) {
        return bytes(_string);
    }

    // Converts bytes to string
    function bytesToString(bytes memory _message) public pure returns (string memory) {
        return string(_message);
    }

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    /*
    // Retrieves messages in hopefully a more RPC-efficient manner
    function retrieveMessages(
        uint256 _conversationID,
        uint256 initialMessage,
        uint256 finalMessage
    ) public view returns (bytes[] memory) {
        // Ensure finalMessage index isn't below initialMessage index
        require(initialMessage <= finalMessage, "Hyperchat::retrieveMessages::INVALID_RANGE");

        // Determine messages array size
        uint256 range = finalMessage - initialMessage + 1;

        // Create messages bytes[] array to store retrieved messages
        bytes[] memory messages = new bytes[](range);
        
        // Iterate across range and retrieve each message
        for (uint256 i; i + initialMessage <= finalMessage;) {
            messages[i] = _messages[_conversationID][i].message;
            // Cant overflow as we confirm range bounds before loop
            unchecked { ++i; }
        }

        return messages;
    }
    */

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Removes admin at admins array _index
    function _removeFromAdminArray(bytes32 _conversationID, uint256 _index) internal {
        uint256 length = _conversations[_conversationID].admins.length;
        if (_index > length) {
            revert InvalidLength();
        }

        for (uint i = _index; i < length - 1;) {
            _conversations[_conversationID].admins[i] = _conversations[_conversationID].admins[i + 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }

        _conversations[_conversationID].admins.pop();
    }

    /*
    // Process Message data
    function _processMessage(bytes memory _envelope) internal {
        // Unpack Message data
        Message memory envelope = abi.decode(_envelope, (Message));
        uint256 conversationID = envelope.conversationID;
        uint256 timestamp = envelope.timestamp;
        bytes32 sender = envelope.sender;

        // Require sender is a conversation participant
        if (!_conversations[conversationID].parties[sender]) {
            revert InvalidParticipant();
        }

        // Determine conversation message count
        uint256 messageCount = _conversations[conversationID].messageCount;
        
        // Add message to end of conversation if message isn't older than the last committed message
        if (_messages[conversationID][messageCount].timestamp <= timestamp) {
            // Save message data to storage
            _messages[conversationID][messageCount + 1] = envelope;
            // Increment conversation message count
            _conversations[conversationID].messageCount += 1;
        }
        // TODO: If older than the last message, reorder messages
    }
    */

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                CONVERSATION MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Initiate a conversation
    function initiateConversation(
        uint32[] memory _domainIDs,
        bytes32[] memory _parties,
        bytes memory _seed
    ) public returns (bytes32 conversationID) {
        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        //Increment conversationCount
        conversationCount += 1;

        // Calculate conversationID
        // Extremely packed to prevent any chance of MEV abuse or collision
        conversationID = bytes32(abi.encodePacked(
            msg.sender,
            address(this),
            HYPERLANE_DOMAIN_IDENTIFIER,
            HYPERLANE_OUTBOX,
            blockhash(1),
            block.number,
            block.difficulty,
            block.timestamp,
            block.chainid,
            block.coinbase,
            conversationCount,
            _seed
        ));

        // Initialize Conversation
        _conversations[conversationID].conversationID = conversationID;
        // Set initializer as conversation admin
        _conversations[conversationID].admins.push(admin);
        _conversations[conversationID].isAdmin[admin] = true;
        _conversations[conversationID].adminApprovals[admin][admin] = true;

        
        // Process Hyperlane domain IDs
        for (uint i; i < _domainIDs.length;) {
            _conversations[conversationID].domainIDs.push(_domainIDs[i]);
        }
        // Process participant addresses
        for (uint i; i < _parties.length;) {
            _conversations[conversationID].parties[_parties[i]] = true;
        }

        emit ConversationCreated(conversationID, addressToBytes32(msg.sender));

        return conversationID;
    }

    // Vote for an address to become a conversation admin
    function adminAddApproval(bytes32 _conversationID, bytes32 _address) public onlyAdmin(_conversationID) {
        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);
        
        // Set admin vote for admin rights approval
        _conversations[_conversationID].adminApprovals[admin][_address] = true;

        emit AdminApprovalAdded(_conversationID, admin, _address);
    }

    // Vote for an address to lose its conversation admin rights
    function adminRemoveApproval(bytes32 _conversationID, bytes32 _address) public onlyAdmin(_conversationID) {
        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);
        
        // Remove admin vote for admin rights approval
        _conversations[_conversationID].adminApprovals[admin][_address] = false;

        emit AdminApprovalRemoved(_conversationID, admin, _address);
    }

    // Give an approved address conversation admin rights
    function addAdmin(bytes32 _conversationID, bytes32 _address) public onlyAdmin(_conversationID) {
        // Keep count of admin count and approvals
        uint256 adminCount = _conversations[_conversationID].admins.length;

        // Keep track of approval count for following for loop
        uint256 approvals;
        // Check each admin's approval status for _address
        for (uint i; i < adminCount;) {
            // Retrieve admin address at index i
            bytes32 adminAddress = _conversations[_conversationID].admins[i];

            // Count approval (if any)
            if (_conversations[_conversationID].adminApprovals[adminAddress][_address]) {
                approvals += 1;
            }

            // Once 51% approval threshold is met, break loop to save gas
            if (approvals > adminCount / 2) {
                break;
            }

            // Loop shouldn't ever overflow
            unchecked { ++i; }
        }

        // If 51% approval threshold is met, give _address conversation admin rights
        if (approvals > adminCount / 2) {
            // Set admin data structures
            _conversations[_conversationID].admins.push(_address);
            _conversations[_conversationID].isAdmin[_address] = true;
            _conversations[_conversationID].adminApprovals[_address][_address] = true;
            adminCount += 1;

            emit AdminAdded(_conversationID, _address);
        } else {
            revert AdminApprovals();
        }
    }

    // Remove an addresss conversation admin rights
    function removeAdmin(bytes32 _conversationID, bytes32 _address) public onlyAdmin(_conversationID) {
        // Keep count of admin count and approvals
        uint256 adminCount = _conversations[_conversationID].admins.length;

        // Keep track of approval count for following for loop
        uint256 approvals;
        // Check each admin's approval status for _address
        for (uint i; i < adminCount;) {
            // Retrieve admin address at index i
            bytes32 adminAddress = _conversations[_conversationID].admins[i];

            // Count approval (if any)
            if (_conversations[_conversationID].adminApprovals[adminAddress][_address]) {
                approvals += 1;
            }

            // Loop shouldn't ever overflow
            unchecked { ++i; }
        }

        // If 51% approval threshold isn't met, remove _address' conversation admin rights
        if (approvals <= adminCount / 2) {
            // Search through admins array for _address and remove it
            for (uint j; j < adminCount;) {
                if (_conversations[_conversationID].admins[j] == _address) {
                    _removeFromAdminArray(_conversationID, j);
                    break;
                }
            }

            // Remove admin data structures
            delete _conversations[_conversationID].isAdmin[_address];
            delete _conversations[_conversationID].adminApprovals[_address][_address];
            adminCount -= 1;

            emit AdminRemoved(_conversationID, _address);
        } else {
            revert AdminApprovals();
        }
    }

    // Add an address to a conversation
    function addAddress(bytes32 _conversationID, bytes32 _address) public onlyAdmin(_conversationID) {
        _conversations[_conversationID].parties[_address] = true;
    }

    // Remove an address from a conversation
    function removeAddress(bytes32 _conversationID, bytes32 _address) public onlyAdmin(_conversationID) {
        delete _conversations[_conversationID].parties[_address];
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                SEND MESSAGE LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*
    // sendMessage overload
    function sendMessage(
        uint256 _conversationID,
        uint32 _hyperlaneDomain,
        string memory _message
    ) public requireValid(_conversationID) {
        sendMessage(_conversationID, _hyperlaneDomain, stringToBytes(_message));
    }

    // Send message via Hyperlane
    function sendMessage(
        uint256 _conversationID,
        uint32 _hyperlaneDomain,
        bytes memory _message
    ) public requireValid(_conversationID) {
        // Convert sender address to bytes32 format
        bytes32 sender = addressToBytes32(msg.sender);

        // Package Message Envelope
        Message memory envelope;
        envelope.conversationID = _conversationID;
        envelope.timestamp = block.timestamp;
        envelope.sender = sender;
        envelope.message = _message;
        bytes memory Envelope = abi.encode(envelope);

        // If recipient domain isn't current chain, send via Hyperlane
        if (_hyperlaneDomain != HYPERLANE_DOMAIN_IDENTIFIER) {
            // Send to Hyperlane Outbox
            IOutbox(HYPERLANE_OUTBOX).dispatch(
                _hyperlaneDomain,
                _hyperchatInstance[_hyperlaneDomain],
                Envelope
            );
        }

        // Commit Envelope to current Hyperchat node
        _processMessage(Envelope);

        emit MessageSent(_hyperlaneDomain, Envelope);
    }
    */

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                RECEIVE MESSAGE LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*
    // Receive logic is embedded in the below Hyperlane-compliant handle() function
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _messageBody
    ) external {
        // Require _sender is a valid Hyperchat node
        if (_sender != _hyperchatInstance[_origin]) {
            revert InvalidInstance();
        }

        // Process message
        _processMessage(_messageBody);

        emit MessageReceived(_origin, _messageBody);
    }
    */
}