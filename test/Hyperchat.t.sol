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
    uint32[] domainsA = [1,2];
    uint32[] domainsB = [2,1];
    bytes32[] participantsA = [addressToBytes32(address(0xABCD)), addressToBytes32(address(0xBEEF))];
    bytes32[] participantsB = [addressToBytes32(address(0xBEEF)), addressToBytes32(address(0xABCD))];
    bytes convSeedA = bytes("I <3 EVM!");
    bytes convNameA = bytes("Hello World");
    bytes32 convIDA;
    bytes32 convIDB;
    
    function setUp() public {
        appA = new Hyperchat(1);
    }

    /*//////////////////////////////////////////////////////////////
                INITIATE CONVERSATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testLocalInitiateConversation() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA, bytes32 conv_IDA, bytes memory conv_NameA) = appA.retrieveConversation(convIDA);

        // Confirm conversationID is generated properly
        uint256 convCount = 0;
        bytes32 conversationIDA = bytes32(keccak256(abi.encodePacked(
            0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84,
            address(appA),
            domainsA[0],
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

        // Check _conversations data
        require(conversationIDA == convIDA && conversationIDA == conv_IDA, "conversationID mismatch");
        require(appA.conversationCount() == 1, "Conversation: conversationCount incorrect");
        require(msgCountA == 1, "Conversation: messageCount incorrect");
        // TODO: require(keccak256(abi.encodePacked(conv_NameA)) == keccak256(abi.encodePacked(bytes("Hello World"))) , "Conversation: name incorrect");

        // Check _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddress, "Message: sender incorrect");
        require(messageA.conversationID == conversationIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 3, "Message: participantsA array length incorrect");
        require(messageA.participants[0] == deployerAddress, "Message: participantsA array data incorrect");
        require(messageA.participants[1] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.participants[2] == participantsA[1], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 2, "Message: domainIDs array length incorrect");
        require(messageA.domainIDs[0] == domainsA[0], "Message: domainIDs array data incorrect");
        require(messageA.domainIDs[1] == domainsA[1], "Message: domainIDs array data incorrect");
        // TODO: require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(convNameA)) , "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.InitiateConversation, "Message: type incorrect");
    }

    function testLocalInitiateConversationsDuplicateData() public {
        // Initiate two conversations with the same data
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        convIDB = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message[] memory messagesB = appA.retrieveMessages(convIDB, 0, 0);
        Hyperchat.Message[] memory messages = appA.retrieveMessages(convIDB, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];
        Hyperchat.Message memory messageB = messagesB[0];
        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA, bytes32 conv_IDA, bytes memory conv_NameA) = appA.retrieveConversation(convIDA);
        (uint256 msgCountB, bytes32 conv_IDB, bytes memory conv_NameB) = appA.retrieveConversation(convIDB);

        // Confirm conversationID is generated properly
        uint256 convCount = 0;
        bytes32 conversationIDA = bytes32(keccak256(abi.encodePacked(
            0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84,
            address(appA),
            domainsA[0],
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
        convCount += 1;
        bytes32 conversationIDB = bytes32(keccak256(abi.encodePacked(
            0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84,
            address(appA),
            domainsA[0],
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

        // Check _conversations data
        require(conversationIDA == convIDA && conversationIDA == conv_IDA, "conversationID mismatch");
        require(conversationIDB == convIDB && conversationIDB == conv_IDB, "conversationID mismatch");
        require(conversationIDA != conversationIDB && convIDA != convIDB && conv_IDA != conv_IDB, "conversationID collision");
        require(appA.conversationCount() == 2, "Conversation: conversationCount incorrect");
        require(msgCountA == msgCountB, "Conversation: messageCount incorrect");
        // TODO: require(keccak256(abi.encodePacked(conv_NameA)) == keccak256(abi.encodePacked(bytes("Hello World"))) , "Conversation: name incorrect");
        // TODO: duplicate name check

        // Check _messages data
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == messageB.sender, "Message: sender incorrect");
        require(messageA.conversationID != messageB.conversationID, "Message: conversationID incorrect");
        require(messageA.participants.length == messageB.participants.length, "Message: participantsA array length incorrect");
        require(messageA.participants[0] == messageB.participants[0], "Message: participantsA array data incorrect");
        require(messageA.participants[1] == messageB.participants[1], "Message: participantsA array data incorrect");
        require(messageA.participants[2] == messageA.participants[2], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == messageA.domainIDs.length, "Message: domainIDs array length incorrect");
        require(messageA.domainIDs[0] == messageB.domainIDs[0], "Message: domainIDs array data incorrect");
        require(messageA.domainIDs[1] == messageB.domainIDs[1], "Message: domainIDs array data incorrect");
        // TODO: require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(convNameA)) , "Message: name incorrect");
        // TODO: duplicate message check
        require(messageA.msgType == messageB.msgType, "Message: type incorrect");
    }


}