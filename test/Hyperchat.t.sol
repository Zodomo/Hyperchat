// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../src/Hyperchat.sol";

contract HyperchatTest is DSTestPlus {

    /*//////////////////////////////////////////////////////////////
                SETUP
    //////////////////////////////////////////////////////////////*/

    bytes32 deployerAddress = addressToBytes32(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    Hyperchat appA;
    uint32[] domains = [1,2];
    bytes32[] participants = [addressToBytes32(address(0xABCD)), addressToBytes32(address(0xBEEF))];
    bytes convSeedA = bytes("I <3 EVM!");
    bytes convNameA = bytes("Hello World");
    bytes32 convIDA;
    
    function setUp() public {
        appA = new Hyperchat(1);
    }

    function testLocalInitiateConversation() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domains, participants, convSeedA, convNameA);
        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messages = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory message = messages[0];
        // Retrieve conversation data after InitiateConversation
        (uint256 msgCount, bytes32 convID, bytes memory convName) = appA.retrieveConversation(convIDA);

        // Confirm conversationID is generated properly
        uint256 convCount = 0;
        bytes32 conversationID = bytes32(keccak256(abi.encodePacked(
            0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84,
            address(appA),
            domains[0],
            blockhash(1),
            block.number,
            block.difficulty,
            block.timestamp,
            block.chainid,
            block.coinbase,
            convCount,
            convSeedA,
            convNameA
        )));
        require(conversationID == convID && conversationID == convIDA, "conversationID mismatch");

        // Check _conversations data
        require(appA.conversationCount() == 1, "Conversation: conversationCount incorrect");
        require(msgCount == 1, "Conversation: messageCount incorrect");
        require(convID == convIDA, "Conversation: conversationID incorrect");
        // TODO: require(keccak256(abi.encodePacked(convName)) == keccak256(abi.encodePacked(bytes("Hello World"))) , "Conversation: name incorrect");

        // Check _messages data
        require(message.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(message.sender == deployerAddress, "Message: sender incorrect");
        require(message.conversationID == conversationID, "Message: conversationID incorrect");
        require(message.participants.length == 3, "Message: participants array length incorrect");
        require(message.participants[0] == deployerAddress, "Message: participants array data incorrect");
        require(message.participants[1] == participants[0], "Message: participants array data incorrect");
        require(message.participants[2] == participants[1], "Message: participants array data incorrect");
        require(message.domainIDs.length == 2, "Message: domainIDs array length incorrect");
        require(message.domainIDs[0] == domains[0], "Message: domainIDs array data incorrect");
        require(message.domainIDs[1] == domains[1], "Message: domainIDs array data incorrect");
        // TODO: require(keccak256(abi.encodePacked(message.message)) == keccak256(abi.encodePacked(convNameA)) , "Message: name incorrect");
        require(message.msgType == Hyperchat.MessageType.InitiateConversation, "Message: type incorrect");
    }
}