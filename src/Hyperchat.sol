// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hyperlane.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract Hyperchat is IOutbox, IMessageRecipient {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Hyperlane data structures
    uint32 private immutable HYPERLANE_DOMAIN_IDENTIFIER;
    address private immutable HYPERLANE_OUTBOX;
    mapping(uint32 => address) private _hyperlaneInbox;

    struct Message {
        uint256 conversationID;
        uint256 messageNum;
        bytes32 sender;
        bytes message;
    }
    struct Conversation {
        uint256 conversationID;
        uint256 messageCounter;
        bytes32[] parties;
    }
    // conversationID => messageNum => message
    mapping(uint256 => mapping(uint256 => bytes)) public chatData;

    struct Transaction {
        uint256 sourceChainID;
        uint256 destinationChainID;
        uint256 conversationID;
        uint256 messageNum;
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

    // Setup Hyperlane Inbox addresses in a batched fashion
    function manageHyperlaneInboxes(uint32[] calldata _hlDomainID, address[] calldata _hlInbox) public {
        // Require parameter array lengths match
        require(_hlDomainID.length == _hlInbox.length, "Hyperchat::manageHyperlaneInboxes::PARAMETER_LENGTH");
        for (uint i; i < _hlDomainID.length;) {
            _hyperlaneInbox[_hlDomainID[i]] = _hlInbox[i];
            // Shouldn't overflow because it is a management function
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                LIBRARY
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Converts string to bytes
    function stringToBytes(string memory _string) internal pure returns (bytes memory) {
        return bytes(_string);
    }

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                HYPERLANE OUTBOX (SEND) LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Send message via Hyperlane
    function sendMessage(uint32 _hyperlaneDomain, address _recipient, string memory _message) public {
        sendMessage(_hyperlaneDomain, _recipient, stringToBytes(_message));
    }

    // Send message via Hyperlane
    function sendMessage(uint32 _hyperlaneDomain, address _recipient, bytes memory _message) public {
        if (_hyperlaneDomain == HYPERLANE_DOMAIN_IDENTIFIER) {

        } else {
            IOutbox(HYPERLANE_OUTBOX).dispatch(
                _hyperlaneDomain,
                addressToBytes32(_recipient),
                _message
            );
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                HYPERLANE INBOX (RECEIVE) LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/
}