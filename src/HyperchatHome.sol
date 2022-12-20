// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hyperlane.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract HyperchatHome is IOutbox, IMessageRecipient {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Mapping of Hyperlane domain identifiers to Outbox addresses
    mapping(uint32 => address) internal hyperlaneOutbox;

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
        // Hyperlane Outbox
        // Mainnet Assignments
        hyperlaneOutbox[0x617262] = 0x0761b0827849abbf7b0cC09CE14e1C93D87f5004; // Arbitrum
        hyperlaneOutbox[0x61766178] = 0x0761b0827849abbf7b0cC09CE14e1C93D87f5004; // Avalanche
        hyperlaneOutbox[0x627363] = 0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94; // BSC
        hyperlaneOutbox[0x63656c6f] = 0xe042D1fbDf59828dd16b9649Ede7abFc856F7a6c; // Celo
        hyperlaneOutbox[0x657468] = 0x2f9DB5616fa3fAd1aB06cB2C906830BA63d135e3; // Ethereum 
        hyperlaneOutbox[0x6f70] = 0x0be2Ae2f6D02a3e0e00ECB57D3E1fCbb7f8F38F4; // Optimism
        hyperlaneOutbox[0x706f6c79] = 0x8249cD1275855F2BB20eE71f0B9fA3c9155E5FaB; // Polygon
        hyperlaneOutbox[0x6d6f2d6d] = 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D; // Moonbeam

        // Testnet Assignments
        hyperlaneOutbox[1000] = 0x5C7D9B5f38022dB78416D6C0132bf8c404deDe27; // Alfajores
        hyperlaneOutbox[0x62732d74] = 0xE023239c8dfc172FF008D8087E7442d3eBEd9350; // BSC
        hyperlaneOutbox[43113] = 0xc507A7c848b59469cC44A3653F8a582aa8BeC71E; // Fuji
        hyperlaneOutbox[5] = 0xDDcFEcF17586D08A5740B7D91735fcCE3dfe3eeD; // Goerli
        hyperlaneOutbox[80001] = 0xe17c37212d785760E8331D4A4395B17b34Ba8cDF; // Mumbai
        hyperlaneOutbox[0x6d6f2d61] = 0x54148470292C24345fb828B003461a9444414517; // Moonbase Alpha
        hyperlaneOutbox[420] = 0x54148470292C24345fb828B003461a9444414517; // Optimism Goerli
        hyperlaneOutbox[421613] = 0x2b2a158B4059C840c7aC67399B153bb567D06303; // Arbitrum Goerli
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