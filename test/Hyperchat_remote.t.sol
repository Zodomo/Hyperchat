// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console.sol";

import "hyperlane/mock/MockHyperlaneEnvironment.sol";
import "./HyperchatWithInternalFunctions.sol";

contract HyperchatRemoteTests is DSTestPlus {

    /*//////////////////////////////////////////////////////////////
                SETUP
    //////////////////////////////////////////////////////////////*/

    address deployerAddress = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address deployerAddress2 = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    bytes32 deployerAddressBytes = addressToBytes32(deployerAddress);
    bytes32 deployerAddress2Bytes = addressToBytes32(deployerAddress2);

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    MockHyperlaneEnvironment testEnv;

    HyperchatWithInternalFunctions appA;
    HyperchatWithInternalFunctions appB;
    uint32[] domainsA = [1,2];
    bytes32[] participantsA = [addressToBytes32(address(0xABCD)), addressToBytes32(address(0xBEEF))];
    bytes convSeedA = bytes("I <3 EVM!");
    bytes convNameA = bytes("Hello World");
    bytes32 convIDA;
    bytes32 convIDB;
    
    function setUp() public {
        // Hyperlane Setup
        testEnv = new MockHyperlaneEnvironment(1,2);
        address mailboxA = address(testEnv.mailboxes(1));
        address mailboxB = address(testEnv.mailboxes(2));
        address igpA = address(testEnv.igps(1));
        address igpB = address(testEnv.igps(2));

        // Hyperchat and Hyperlane Router Setup
        appA = new HyperchatWithInternalFunctions(1, mailboxA, igpA);
        appB = new HyperchatWithInternalFunctions(2, mailboxB, igpB);
        appA.enrollRemoteRouter(2, addressToBytes32(address(appB)));
        appB.enrollRemoteRouter(1, addressToBytes32(address(appA)));

        // Test user setup
        hevm.deal(address(0xABCD), 100 ether);
        hevm.deal(address(0xBEEF), 100 ether);
        hevm.deal(address(0xDEED), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                CROSS-DOMAIN DATA INTEGRITY/COMPARISON CHECKS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                INITIATE CONVERSATION
    //////////////////////////////////////////////////////////////*/

    function testRemoteInitiateConversation() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA, bytes32 conv_IDA, bytes memory conv_NameA) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB, bytes32 conv_IDB, bytes memory conv_NameB) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation data matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");
        require(keccak256(abi.encodePacked(conv_IDA)) == keccak256(abi.encodePacked(conv_IDB)), "Conversation: conversation ID mismatch");
        require(keccak256(abi.encodePacked(conv_NameA)) == keccak256(abi.encodePacked(conv_NameB)), "Conversation: conversation name mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.participants[1] == messageB.participants[1], "Message: participant address mismatch");
        require(messageA.participants[2] == messageB.participants[2], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(messageA.domainIDs[0] == messageB.domainIDs[0], "Message: domain ID mismatch");
        require(messageA.domainIDs[1] == messageB.domainIDs[1], "Message: domain ID mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    // Test receiving a duplicate InitiateConversation message
    function testRemoteInitiateConversationDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();

        // Prep duplicated InitiateConversation message
        Hyperchat.Message memory message;
        message.timestamp = block.timestamp;
        message.sender = addressToBytes32(address(this));
        message.conversationID = convIDA;
        message.participants = new bytes32[](3);
        message.participants[0] = addressToBytes32(address(this));
        message.participants[1] = addressToBytes32(address(0xABCD));
        message.participants[2] = addressToBytes32(address(0xBEEF));
        message.domainIDs = new uint32[](2);
        message.domainIDs[0] = 1;
        message.domainIDs[1] = 2;
        message.message = convNameA;
        message.msgType = Hyperchat.MessageType.InitiateConversation;

        // Send duplicate message
        // Expect InvalidConversation error as conversation ID is already generated
        appA.sendMessage/*{ value: 10000000 gwei }*/(convIDA, abi.encode(message));
        // Error is only triggered when received
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        testEnv.processNextPendingMessage();
    }

    /*//////////////////////////////////////////////////////////////
                ADD/REMOVE ADMIN APPROVAL
    //////////////////////////////////////////////////////////////*/

    function testRemoteAddAdminApproval() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteAddAdminApprovalNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();
        
        // Give 0xABCD admin approval from a non-origin domain
        appB.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteRemoveAdminApproval() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteRemoveAdminApprovalNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();

        // Give 0xABCD admin approval from a non-origin domain
        appB.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Remove 0xABCD admin approval from a non-origin domain
        appB.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                ADD/REMOVE ADMIN
    //////////////////////////////////////////////////////////////*/

    function testRemoteAddAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteAddAdminNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();
        
        // Give 0xABCD admin approval from a non-origin domain
        appB.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();
        
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool from a non-origin domain
        appB.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteRemoveAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove deployer's 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD's admin rights
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 4, 4);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 4, 4);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }
    
    function testRemoteRemoveAdminNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();
        
        // Give 0xABCD admin approval from a non-origin domain
        appB.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();
        
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool from a non-origin domain
        appB.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Remove deployer's 0xABCD admin approval from a non-origin domain
        appB.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Remove 0xABCD's admin rights from a non-origin domain
        appB.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 4, 4);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 4, 4);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                ADD/REMOVE PARTICIPANT
    //////////////////////////////////////////////////////////////*/

    function testRemoteAddParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteAddParticipantNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();
        
        // Add 0xDEED to the conversation from a non-origin domain
        appB.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        testEnv.processNextPendingMessageFromDestination();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteRemoveParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        // Remove 0xDEED from the conversation
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteRemoveParticipantNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();
        
        // Add 0xDEED to the conversation from a non-origin domain
        appB.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        testEnv.processNextPendingMessageFromDestination();
        
        // Remove 0xDEED from the conversation from a non-origin domain
        appB.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        testEnv.processNextPendingMessageFromDestination();
        
        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.participants[0] == messageB.participants[0], "Message: participant address mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                GENERAL MESSAGE
    //////////////////////////////////////////////////////////////*/

    function testRemoteGeneralMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Send a message
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("GeneralMessage"));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }

    function testRemoteGeneralMessageNonOrigin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();

        // Send a message from a non-origin domain
        appB.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("GeneralMessage"));
        testEnv.processNextPendingMessageFromDestination();
        
        // Retrieve appA conversation and message data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve appB conversation and message data
        (uint256 msgCountB,,) = appB.retrieveConversation(convIDA);
        Hyperchat.Message[] memory messagesB = appB.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageB = messagesB[0];

        // Check if conversation message count matches
        require(msgCountA == msgCountB, "Conversation: message count mismatch");

        // Check if message data matches
        require(messageA.timestamp == messageB.timestamp, "Message: timestamp mismatch");
        require(messageA.sender == messageB.sender, "Message: sender mismatch");
        require(messageA.conversationID == messageB.conversationID, "Message: conversation ID mismatch");
        require(messageA.participants.length == messageB.participants.length, "Message: participants array length mismatch");
        require(messageA.domainIDs.length == messageB.domainIDs.length, "Message: domainIDs array length mismatch");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: name mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type mismatch");
    }
}