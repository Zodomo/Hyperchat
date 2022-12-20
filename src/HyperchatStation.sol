// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hyperlane.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract HyperchatStation is IOutbox, IMessageRecipient {

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
        HYPERLANE_DOMAIN_IDENTIFIER = 0x6f70; // Optimism Mainnet
        // Set to Hyperlane Outbox on Station chain
        HYPERLANE_OUTBOX = 0x0be2Ae2f6D02a3e0e00ECB57D3E1fCbb7f8F38F4; // Optimism Mainnet
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