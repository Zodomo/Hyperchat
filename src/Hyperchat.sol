// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hyperlane.sol";
import "openzeppelin-contracts/access/Ownable2Step.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract Hyperchat is IMessageRecipient, Ownable2Step {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                EVENTS/ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    event ConversationCreated(uint256 indexed conversationID, uint32[] indexed chainIDs, bytes32[] indexed parties);
    event MessageSent(uint32 indexed chainID, bytes indexed message);
    event MessageReceived(uint32 indexed chainID, bytes indexed message);

    error InvalidConversation();
    error InvalidParticipant();
    error InvalidInstance();

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
    // conversationID => messageNum => Message data struct
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
        if (_conversationID == 0) {
            revert InvalidConversation();
        }
        if (!_conversations[_conversationID].parties[addressToBytes32(msg.sender)]) {
            revert InvalidParticipant();
        }
        _;
    }

    modifier requireDeployed(uint32 _hyperlaneDomain) {
        _checkInstance(_hyperlaneDomain);
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
                SECURITY
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Confirm received message is to/from a valid Hyperchat node
    function _checkInstance(uint32 _hyperlaneDomain) internal view {
        if (_hyperchatInstance[_hyperlaneDomain] == bytes32(0)) {
            revert InvalidInstance();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

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
                INITIATE CONVERSATION LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Initiate a conversation
    function initiateConversation(uint32[] memory _chainIDs, bytes32[] memory _parties) public returns (uint256) {
        // Generate conversation ID and initiate conversation by saving it
        uint256 conversationID = conversationCount + 1;
        _conversations[conversationID].conversationID = conversationID;
        
        // Loop through all addresses in _parties and add them to conversation allowlist
        for (uint i; i < _parties.length;) {
            _conversations[conversationID].parties[_parties[i]] = true;
        }



        emit ConversationCreated(conversationID, _chainIDs, _parties);
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
    ) public requireDeployed(_hyperlaneDomain) requireValid(_conversationID) {
        sendMessage(_conversationID, _hyperlaneDomain, stringToBytes(_message));
    }

    // Send message via Hyperlane
    function sendMessage(
        uint256 _conversationID,
        uint32 _hyperlaneDomain,
        bytes memory _message
    ) public requireDeployed(_hyperlaneDomain) requireValid(_conversationID) {
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
        // Block messages from non-deployed chains
        _checkInstance(_origin);
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