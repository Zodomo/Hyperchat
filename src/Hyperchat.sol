// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hyperlane.sol";
import "openzeppelin-contracts/access/Ownable2Step.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract Hyperchat is IMessageRecipient, Ownable2Step {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                EVENTS/ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    event Sent(uint32 indexed chainID, bytes32 indexed recipient, bytes indexed message);
    event Received(uint32 indexed chainID, bytes32 indexed sender, bytes indexed message);

    error InvalidConversation();
    error InvalidParticipant();
    error InvalidDestination();

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Hyperlane data structures
    uint32 private immutable HYPERLANE_DOMAIN_IDENTIFIER;
    address private immutable HYPERLANE_OUTBOX;
    mapping(uint32 => bytes32) private _hyperchatInstance;

    struct Message {
        uint256 conversationID;
        uint256 timestamp;
        bytes32 sender;
        bytes message;
    }
    // conversationID => messageCount => Message data struct
    mapping(uint256 => mapping(uint256 => Message)) private _messages;

    struct Conversation {
        uint256 conversationID;
        uint256 messageCount;
        mapping(bytes32 => bool) parties;
    }
    // conversationID => Conversation data struct
    mapping(uint256 => Conversation) private _conversations;
    uint256 private conversationCount;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    modifier requireValid(uint256 _conversationID) {
        if (_conversations[_conversationID].conversationID == 0) {
            revert InvalidConversation();
        }
        if (!_conversations[_conversationID].parties[addressToBytes32(msg.sender)]) {
            revert InvalidParticipant();
        }
        _;
    }

    modifier requireDeployed(uint32 _hyperlaneDomain) {
        if (_hyperchatInstance[_hyperlaneDomain] == bytes32(0)) {
            revert InvalidDestination();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    constructor(uint32 _hyperlaneDomainID, address _hyperlaneOutbox) payable {
        // Set to Hyperlane Domain Identifier of Station chain
        HYPERLANE_DOMAIN_IDENTIFIER = _hyperlaneDomainID;
        // Set to Hyperlane Outbox on Station chain
        HYPERLANE_OUTBOX = _hyperlaneOutbox;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                MANAGEMENT
    //////////////////////////////////////////////////////////////////////////////////////////////////*/
    
    // Function overload
    function addInstance_(uint32 _domain, address _instance) public onlyOwner {
        addInstance_(_domain, addressToBytes32(_instance));
    }

    // Inform contract of other Hyperchat instances on other chains
    function addInstance_(uint32 _domain, bytes32 _instance) public onlyOwner {
        _hyperchatInstance[_domain] = _instance;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                LIBRARY
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Converts string to bytes
    function stringToBytes(string calldata _string) public pure returns (bytes calldata) {
        return bytes(_string);
    }

    // Converts bytes to string
    function bytesToString(bytes calldata _message) public pure returns (string calldata) {
        return string(_message);
    }

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                SEND MESSAGE LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // sendMessage overload
    function sendMessage(
        uint256 _conversationID,
        uint32 _hyperlaneDomain,
        string calldata _message
    ) public requireDeployed(_hyperlaneDomain) requireValid(_conversationID) {
        sendMessage(_conversationID, _hyperlaneDomain, stringToBytes(_message));
    }

    // Send message via Hyperlane
    function sendMessage(
        uint256 _conversationID,
        uint32 _hyperlaneDomain,
        bytes calldata _message
    ) public requireDeployed(_hyperlaneDomain) requireValid(_conversationID) {
        // Convert sender address to bytes32 format
        bytes32 sender = addressToBytes32(msg.sender);

        // Package Message Envelope
        Message memory envelope;
        envelope.conversationID = _conversationID;
        envelope.timestamp = block.timestamp;
        envelope.sender = sender;
        envelope.message = _message;

        // If recipient domain is current chain, process logic here
        if (_hyperlaneDomain == HYPERLANE_DOMAIN_IDENTIFIER) {
            _processMessage(abi.encode(envelope));
        }
        // Otherwise, use Hyperlane to send envelope to destination
        else {
            IOutbox(HYPERLANE_OUTBOX).dispatch(
                _hyperlaneDomain,
                _hyperchatInstance[_hyperlaneDomain],
                abi.encode(envelope)
            );

            emit Sent(_hyperlaneDomain, _hyperchatInstance[_hyperlaneDomain], abi.encode(envelope));
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                RECEIVE MESSAGE LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/


}