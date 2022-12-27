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
                LOCAL INITIATE CONVERSATION TESTS
    //////////////////////////////////////////////////////////////*/

    // Test one function call to initiateConversation()
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

    // Test two function calls to initiateConversation with the same exact data
    function testLocalInitiateConversationsDuplicateData() public {
        // Initiate two conversations with the same data
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        convIDB = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message[] memory messagesB = appA.retrieveMessages(convIDB, 0, 0);
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

    /*//////////////////////////////////////////////////////////////
                LOCAL ADD ADMIN APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    // Test adding valid admin approval for a conversation participant by a conversation admin
    function testLocalAddAdminApproval() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddress, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddress, " gave admin approval for ", participantsA[0], "!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.AddAdminApproval, "Message: type incorrect");
    }

    // Test adding valid admin approval for a conversation participant by a conversation admin with a custom message
    function testLocalAddAdminApprovalWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval(convIDA, participantsA[0], bytes("test"));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddress, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("test"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.AddAdminApproval, "Message: type incorrect");
    }

    // Test duplicate add admin approval calls
    // Should fail with InvalidApprovals error
    function testLocalAddAdminApprovalDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));

        // Duplicate 0xABCD admin approval
        // Expect InvalidApprovals error as duplicate approvals are blocked
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));
    }

    // Test giving admin approval to a non-participant address
    // Should fail with InvalidParticipant error
    function testLocalAddAdminApprovalInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xDEED admin approval
        // Expect InvalidParticipant error as address isnt a participant
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.addAdminApproval(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    // Test attempting to give admin approval as a non-admin
    // Should fail with InvalidAdmin error
    function testLocalAddAdminApprovalInvalidAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        // Expect InvalidAdmin error as address isnt an admin
        hevm.startPrank(address(0xABCD));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }

    // Test attempting to give admin approval for a non-existing conversation
    // Should fail with InvalidConversation error
    function testLocalAddAdminApprovalInvalidConversation() public {
        // Expect InvalidAdmin error as bytes32("test") is not yet a valid conversation ID
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.addAdminApproval(bytes32("test"), participantsA[0], bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL REMOVE ADMIN APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    // Test removing valid admin approval for a conversation participant by a conversation admin
    function testLocalRemoveAdminApproval() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval(convIDA, participantsA[0], bytes(""));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddress, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddress, " revoked admin approval for ", participantsA[0], "!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.RemoveAdminApproval, "Message: type incorrect");
    }

    // Test removing valid admin approval for a conversation participant by a conversation admin with a custom message
    function testLocalRemoveAdminApprovalWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval(convIDA, participantsA[0], bytes("test"));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddress, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("test"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.RemoveAdminApproval, "Message: type incorrect");
    }
    
    // Test duplicate remove admin approval calls
    // Should fail with InvalidApprovals error
    function testLocalRemoveAdminApprovalDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval(convIDA, participantsA[0], bytes(""));

        // Duplicate remove 0xABCD admin approval
        // Expect InvalidApprovals error as duplicate approvals are blocked
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.removeAdminApproval(convIDA, participantsA[0], bytes(""));
    }

    // Test removing admin approval from a non-participant address
    // Should fail with InvalidParticipant error
    function testLocalRemoveAdminApprovalInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Remove 0xDEED's admin approval
        // Expect InvalidParticipant error as address isnt a participant
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.removeAdminApproval(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    // Test removing admin approval as a non-admin
    // Should fail with InvalidAdmin error
    function testLocalRemoveAdminApprovalInvalidAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        // Remove 0xABCD's admin approval
        // Expect InvalidAdmin error as address isnt an admin
        hevm.startPrank(address(0xABCD));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.removeAdminApproval(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }

    // Test attempting to remove admin approval for a non-existing conversation
    // Should fail with InvalidConversation error
    function testLocalRemoveAdminApprovalInvalidConversation() public {
        // Expect InvalidAdmin error as bytes32("test") is not yet a valid conversation ID
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.removeAdminApproval(bytes32("test"), participantsA[0], bytes(""));
    }
}