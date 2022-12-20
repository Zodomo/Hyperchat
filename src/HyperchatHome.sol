// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hyperlane.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract HyperchatHome is IOutbox, IMessageRecipient {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Hyperlane data structures
    uint32 public immutable HYPERLANE_DOMAIN_IDENTIFIER;
    address public immutable HYPERLANE_OUTBOX;

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

    constructor() payable {
        // Set to Hyperlane Domain Identifier of Station chain
        HYPERLANE_DOMAIN_IDENTIFIER = 0x617262;
        // Set to Hyperlane Outbox on Station chain
        HYPERLANE_OUTBOX = 0x0761b0827849abbf7b0cC09CE14e1C93D87f5004;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                LIBRARY
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                HYPERLANE OUTBOX LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                HYPERLANE INBOX LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/
}