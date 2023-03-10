// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console.sol";

import "hyperlane/mock/MockHyperlaneEnvironment.sol";
import "./HyperchatWithInternalFunctions.sol";

contract HyperchatLocalTests is DSTestPlus {

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
    uint32[] domainLocal = [1];
    bytes32[] participantsA = [addressToBytes32(address(0xABCD)), addressToBytes32(address(0xBEEF))];
    bytes32[] participantsExtended = [addressToBytes32(address(0xABCD)), addressToBytes32(address(this)), addressToBytes32(address(0xBEEF))];
    bytes convSeedA = bytes("I <3 EVM!");
    bytes convNameA = bytes("Hello World");
    bytes32 convIDA;
    bytes32 convIDB;
    
    function setUp() public {
        // Required/Minimal Hyperlane Setup
        // Remember, only local tests are being executed
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
                LOCAL DATA STRUCTURES AND FUNCTION DOMAIN LOGIC TESTING
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                LOCAL INITIATE CONVERSATION TESTS
    //////////////////////////////////////////////////////////////*/

    // Test initiating a valid conversation with all data fields populated
    function testLocalInitiateConversation() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];
        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA, bytes32 conv_IDA, bytes memory conv_NameA) = appA.retrieveConversation(convIDA);

        bytes32 conversationIDA;

        // Confirm conversationID is generated properly
        uint256 convCount = 0;
        if (address(this) == deployerAddress) {
            conversationIDA = bytes32(keccak256(abi.encodePacked(
                deployerAddress,
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
        }
        else if (address(this) == deployerAddress2) {
            conversationIDA = bytes32(keccak256(abi.encodePacked(
                deployerAddress2,
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
        }

        // Check _conversations data
        require(conversationIDA == convIDA && conversationIDA == conv_IDA, "conversationID mismatch");
        require(appA.conversationCount() == 1, "Conversation: conversationCount incorrect");
        require(msgCountA == 1, "Conversation: messageCount incorrect");
        require(keccak256(abi.encodePacked(conv_NameA)) == keccak256(abi.encodePacked(bytes("Hello World"))) , "Conversation: name incorrect");

        // Check _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == conversationIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 3, "Message: participantsA array length incorrect");
        require(messageA.participants[0] == deployerAddressBytes || messageA.participants[0] == deployerAddress2Bytes, "Message: participantsA array data incorrect");
        require(messageA.participants[1] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.participants[2] == participantsA[1], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 2, "Message: domainIDs array length incorrect");
        require(messageA.domainIDs[0] == domainsA[0], "Message: domainIDs array data incorrect");
        require(messageA.domainIDs[1] == domainsA[1], "Message: domainIDs array data incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(convNameA)) , "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.InitiateConversation, "Message: type incorrect");
    }

    // Test initiating two conversations with the same exact set of data
    function testLocalInitiateConversationsDuplicateData() public {
        // Initiate two conversations with the same data
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        convIDB = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message[] memory messagesB = appA.retrieveMessages(convIDB, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];
        Hyperchat.Message memory messageB = messagesB[0];
        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA, bytes32 conv_IDA, bytes memory conv_NameA) = appA.retrieveConversation(convIDA);
        (uint256 msgCountB, bytes32 conv_IDB, bytes memory conv_NameB) = appA.retrieveConversation(convIDB);

        bytes32 conversationIDA;
        bytes32 conversationIDB;

        // Confirm conversationID is generated properly
        uint256 convCount = 0;
        if (address(this) == deployerAddress) {
            conversationIDA = bytes32(keccak256(abi.encodePacked(
                deployerAddress,
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
            conversationIDB = bytes32(keccak256(abi.encodePacked(
                deployerAddress,
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
        }
        else if (address(this) == deployerAddress2) {
            conversationIDA = bytes32(keccak256(abi.encodePacked(
                deployerAddress2,
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
            conversationIDB = bytes32(keccak256(abi.encodePacked(
                deployerAddress2,
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
        }
        else { revert(); }

        // Check _conversations data
        require(conversationIDA == convIDA, "conversationID mismatch");
        require(conversationIDB == convIDB, "conversationID mismatch");
        require(conversationIDA != conversationIDB && convIDA != convIDB && conv_IDA != conv_IDB, "conversationID collision");
        require(appA.conversationCount() == 2, "Conversation: conversationCount incorrect");
        require(msgCountA == msgCountB, "Conversation: messageCount incorrect");
        require(keccak256(abi.encodePacked(conv_NameA)) == keccak256(abi.encodePacked(bytes("Hello World"))) , "Conversation: name incorrect");
        require(keccak256(abi.encodePacked(conv_NameB)) == keccak256(abi.encodePacked(bytes("Hello World"))) , "Conversation: name incorrect");
        require(keccak256(abi.encodePacked(conv_NameA)) == keccak256(abi.encodePacked(conv_NameB)), "Conversation: name mismatch");

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
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(conv_NameA)) , "Message: name incorrect");
        require(keccak256(abi.encodePacked(messageB.message)) == keccak256(abi.encodePacked(conv_NameB)) , "Message: name incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == keccak256(abi.encodePacked(messageB.message)), "Message: message mismatch");
        require(messageA.msgType == messageB.msgType, "Message: type incorrect");
    }

    // Test initiating a conversation without the name field populated
    function testInitiateConversationWithoutName() public {
        // Initiate conversation without name
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, bytes(""));

        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data for default message
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperlane: ", addressToBytes32(address(this)), " initiated ", convIDA, "!"))));
    }

    // Test initiating a conversation with the initiator address in the participant array
    function testInitiateConversationInitiatorAddressInParticipantArray() public {
        // Initiate conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsExtended, convSeedA, convNameA);

        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.participants.length == participantsExtended.length, "Message: participants array length incorrect");
        require(messageA.participants[0] == addressToBytes32(address(this)), "Message: participants array data incorrect");
        require(messageA.participants[1] == addressToBytes32(address(0xABCD)), "Message: participants array data incorrect");
        require(messageA.participants[2] == addressToBytes32(address(0xBEEF)), "Message: participants array data incorrect");
    }

    // Test initializing a conversation with a forced duplicate conversation ID
    // Should fail with InvalidConversation error
    function testInitiateConversationForceDuplicateConversationID() public {
        // Initiate conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsExtended, convSeedA, convNameA);

        // Spoof conversationCount as it is used in conversation ID generation
        appA.decrementConversationCount(1);

        // Attempt to initiate a conversation with a conversation ID that already exists
        // Expect InvalidConversation error due to ID conflict
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        convIDB = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsExtended, convSeedA, convNameA);
    }

    // Test initializing a conversation with a single domain scope
    function testInitializeConversationSingleDomain() public {
        // Initiate conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainLocal, participantsExtended, convSeedA, convNameA);

        // Retrieve InitiateConversation message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 0, 0);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.domainIDs.length == 1, "Message: domainID array length incorrect");
        require(messageA.domainIDs[0] == domainLocal[0], "Message: domainID mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL ADD ADMIN APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    // Test adding valid admin approval for a conversation participant by a conversation admin
    function testLocalAddAdminApproval() public {
        console.log(address(this));
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddressBytes, " gave admin approval for ", participantsA[0], "!"))) || 
            keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddress2Bytes, " gave admin approval for ", participantsA[0], "!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.AddAdminApproval, "Message: type incorrect");
    }

    // Test adding valid admin approval for a conversation participant by a conversation admin with a custom message
    function testLocalAddAdminApprovalWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes("test"));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
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
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Duplicate 0xABCD admin approval
        // Expect InvalidApprovals error as duplicate approvals are blocked
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test giving admin approval to a non-participant address
    // Should fail with InvalidParticipant error
    function testLocalAddAdminApprovalInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xDEED admin approval
        // Expect InvalidParticipant error as address isnt a participant
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    // Test attempting to give admin approval as a non-admin
    // Should fail with InvalidAdmin error
    function testLocalAddAdminApprovalInvalidAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        // Expect InvalidAdmin error as address isnt an admin
        hevm.startPrank(address(0xABCD));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }

    // Test attempting to give admin approval for a non-existing conversation
    // Should fail with InvalidConversation error
    function testLocalAddAdminApprovalInvalidConversation() public {
        // Expect InvalidAdmin error as bytes32("test") is not yet a valid conversation ID
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(bytes32("test"), participantsA[0], bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL REMOVE ADMIN APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    // Test removing valid admin approval for a conversation participant by a conversation admin
    function testLocalRemoveAdminApproval() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddressBytes, " revoked admin approval for ", participantsA[0], "!"))) ||
            keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddress2Bytes, " revoked admin approval for ", participantsA[0], "!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.RemoveAdminApproval, "Message: type incorrect");
    }

    // Test removing valid admin approval for a conversation participant by a conversation admin with a custom message
    function testLocalRemoveAdminApprovalWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes("test"));
        
        // Retrieve new _conversations data
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve new _messages data
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check new _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
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
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Duplicate remove 0xABCD admin approval
        // Expect InvalidApprovals error as duplicate approvals are blocked
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test removing admin approval from a non-participant address
    // Should fail with InvalidParticipant error
    function testLocalRemoveAdminApprovalInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Remove 0xDEED's admin approval
        // Expect InvalidParticipant error as address isnt a participant
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    // Test removing admin approval as a non-admin
    // Should fail with InvalidAdmin error
    function testLocalRemoveAdminApprovalInvalidAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Remove 0xABCD's admin approval
        // Expect InvalidAdmin error as address isnt an admin
        hevm.startPrank(address(0xABCD));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }

    // Test attempting to remove admin approval for a non-existing conversation
    // Should fail with InvalidConversation error
    function testLocalRemoveAdminApprovalInvalidConversation() public {
        // Expect InvalidAdmin error as bytes32("test") is not yet a valid conversation ID
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(bytes32("test"), participantsA[0], bytes(""));
    }

    // Test removing self admin approval as valid conversation admin
    function testLocalRemoveAdminApprovalSelf() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Revoke admin approval for 0xABCD as 0xABCD
        hevm.prank(address(0xABCD));
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL ADD ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    // Test giving admin rights to a valid participant with enough admin approval votes
    function testLocalAddAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Retrieve conversation message count and check it
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve AddAdmin message
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddressBytes, " added ", participantsA[0], " to conversation as admin!"))) ||
            keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddress2Bytes, " added ", participantsA[0], " to conversation as admin!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.AddAdmin, "Message: type incorrect");
    }

    // Test giving admin rights to a valid participant with enough admin approval votes with a custom message
    function testLocalAddAdminWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes("you're an admin now 0xABCD!"));

        // Retrieve conversation message count and check it
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve AddAdmin message
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("you're an admin now 0xABCD!"))) ||
            keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("you're an admin now 0xABCD!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.AddAdmin, "Message: type incorrect");
    }

    // Test duplicate add admin calls
    // Should fail with InvalidAdmin error
    function testLocalAddAdminDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Duplicate call to add 0xABCD as admin
        // Expect InvalidAdmin as 0xABCD is already admin
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test adding a valid participant as admin without enough votes
    // Should fail with InvalidApprovals error
    function testLocalAddAdminWithoutAdequateApprovals() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        // We need two admins in order for a failed 1/2 vote to occur
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Cast admin approval vote for 0xBEEF next
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[1], bytes(""));

        // Attempt to make 0xBEEF with only 50% of vote
        // Expect InvalidApprovals revert
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[1], bytes(""));
    }

    // Test trying to promote a valid participant to admin as admin without any admin approvals
    // Should fail with InvalidApprovals error
    function testLocalAddAdminWithoutAnyApprovals() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Attempt to promote 0xABCD to admin without any votes
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test trying to promote a valid participant to admin as a participant
    // Should fail with InvalidAdmin error
    function testLocalAddAdminAsNonAdminWithoutAnyApprovals() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Attempt to promote 0xABCD as 0xBEEF to admin without any votes
        hevm.startPrank(address(0xBEEF));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }

    // Test trying to promote a valid participant to admin as a participant but with enough approvals
    // Should fail with InvalidAdmin error
    function testLocalAddAdminAsNonAdminWithSufficientApprovals() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], "testing");
        // Attempt to promote 0xABCD as 0xBEEF to admin with sufficient votes
        hevm.startPrank(address(0xBEEF));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }
    
    // Test trying to promote a valid participant to admin as a non-participant
    // Should fail with InvalidAdmin error
    function testLocalAddAdminAsNonParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);

        // Attempt to promote 0xABCD to admin as 0xDEED
        hevm.startPrank(address(0xDEED));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes("lol"));
        hevm.stopPrank();
    }

    // Test promoting an address to admin for an invalid conversation
    // Should fail with InvalidConversation error
    function testLocalAddAdminInvalidConversation() public {
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(bytes32("2"), addressToBytes32(address(0xDEED)), bytes("I think I'm lost..."));
    }

    // Test promoting an invalid participant address to admin in a valid conversation as admin
    // Should fail with InvalidParticipant error
    function testLocalAddAdminInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);

        // Attempt to add a non-participant address to the conversation as admin
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL REMOVE ADMIN TESTS
    //////////////////////////////////////////////////////////////*/

    // Test demoting an address from admin for a valid conversation as a conversation admin
    function testLocalRemoveAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove deployer's 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD's admin rights
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Retrieve conversation message count and check it
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 5, "Conversation: messageCount incorrect");

        // Retrieve RemoveAdmin message
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 4, 4);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddressBytes, " removed ", participantsA[0], " from conversation as admin!"))) ||
            keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: ", deployerAddress2Bytes, " removed ", participantsA[0], " from conversation as admin!"))),
            "Message: message incorrect");
        require(messageA.msgType == Hyperchat.MessageType.RemoveAdmin, "Message: type incorrect");
    }

    // Test demoting an address from admin for a valid conversation as a conversation admin with custom message
    function testLocalRemoveAdminWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove deployer's 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD's admin rights
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes("get rekt"));

        // Retrieve conversation message count and check it
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 5, "Conversation: messageCount incorrect");

        // Retrieve RemoveAdmin message
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 4, 4);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == participantsA[0], "Message: participantsA array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("get rekt"))) ||
            keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("get rekt"))),
            "Message: message incorrect");
        require(messageA.msgType == Hyperchat.MessageType.RemoveAdmin, "Message: type incorrect");
    }

    // Test duplicate remove admin calls
    // Should fail with InvalidAdmin error
    function testLocalRemoveAdminDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove deployer's 0xABCD admin approval
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD's admin rights
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Duplicate call to remove 0xABCD as admin
        // Expect InvalidAdmin as 0xABCD is no longer an admin
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test removing a valid admin without removing any approvals
    // Should fail with InvalidApprovals error
    function testLocalRemoveAdminWithSufficientApprovals() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Attempt to remove 0xABCD's admin rights
        // Expect InvalidApprovals error as no approvals were removed so they have full support
        hevm.expectRevert(Hyperchat.InvalidApprovals.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test removing an admin without support but as a valid non-admin participant
    // Should fail with InvalidAdmin error
    function testLocalRemoveAdminAsNonAdminParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Revoke admin approval for 0xABCD
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Attempt to remove 0xABCD's admin rights as 0xBEEF
        // Expect InvalidAdmin error as 0xBEEF is not an admin
        hevm.startPrank(address(0xBEEF));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        hevm.stopPrank();
    }

    // Test removing an admin with zero approvals as valid admin
    function testLocalRemoveAdminWithZeroApprovals() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Revoke admin approval for 0xABCD
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Self revoke admin approval as 0xABCD
        hevm.prank(address(0xABCD));
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Finally remove admin
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
    }

    // Test removing an admin as a non-valid participant
    // Should fail with InvalidParticipant error
    function testLocalRemoveAdminAsInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Give admin approval vote to 0xABCD
        appA.addAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));
        // Revoke admin approval for 0xABCD
        appA.removeAdminApproval/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes(""));

        // Attempt to remove admin as non-participant 0xDEED
        // Expect Invalid as 0xDEED is not a valid conversation admin
        hevm.startPrank(address(0xDEED));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, participantsA[0], bytes("lol"));
        hevm.stopPrank();
    }

    // Test removing an admin from an invalid conversation
    // Should fail with InvalidConversation error
    function testLocalRemoveAdminInvalidConversation() public {
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(bytes32("2"), participantsA[0], bytes("man I hate that dude"));
    }

    // Test removing an invalid participant address as admin from a valid conversation as a valid admin
    // Should fail with InvalidParticipant error
    function testLocalRemoveAdminInvalidParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        
        // Attempt to remove an invalid participant address as admin
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes("i just hate this dude"));
    }

    // Test removing self as final admin in a valid conversation
    // Should fail with InvalidAdmin error
    function testLocalRemoveAdminSelfAsLastAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        
        // Attempt to remove self from conversation as the last admin
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.removeAdmin/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(this)), bytes("how do I exit vim"));
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL ADD PARTICIPANT TESTS
    //////////////////////////////////////////////////////////////*/

    // Test valid admin adding a participant address to an existing conversation
    function testLocalAddParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));

        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);

        // Retrieve AddParticipant message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check _conversations data
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Check _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == addressToBytes32(address(0xDEED)), "Message: participants array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: Welcome ", addressToBytes32(address(0xDEED)), "!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.AddParticipant, "Message: type incorrect");
    }

    // Test valid admin adding a participant address to an existing conversation with a custom message
    function testLocalAddParticipantWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes("test"));

        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);

        // Retrieve AddParticipant message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check _conversations data
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Check _messages data
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("test"))),
            "Message: name incorrect");
    }

    // Test duplicate participant additions
    // Should fail with InvalidParticipant error
    function testLocalAddParticipantDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));

        // Duplicate add 0xDEED as participant transaction
        // Expect InvalidParticipant error as duplicate additions are not allowed
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    // Test self-adding as participant to an already joined conversation
    // Should fail with InvalidParticipant error
    function testLocalAddParticipantSelf() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        // Expect InvalidParticipant error as address is already a participant
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(this)), bytes(""));
    }

    // Test adding a participant as a non-admin, but valid participant
    // Should fail with InvalidAdmin error
    function testLocalAddParticipantAsNonAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation as non-admin address 0xABCD
        // Expect InvalidAdmin error as 0xABCD is not an admin
        hevm.startPrank(address(0xABCD));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        hevm.stopPrank();
    }

    // Test adding a participant to a conversation as a non-participant
    // Should fail with InvalidAdmin error
    function testLocalAddParticipantAsNonParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation as non-participant 0xDEED
        // Expect InvalidAdmin error as 0xDEED is not a conversation participant so they cant be admin
        hevm.startPrank(address(0xDEED));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        hevm.stopPrank();
    }

    // Test sending a general message as a newly added participant to a valid conversation
    function testLocalGeneralMessageAsNewParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes("hi 0xDEED"));
        // Send message to the conversation as 0xDEED
        hevm.startPrank(address(0xDEED));
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("whats up deployer!"));
        hevm.stopPrank();

        // Retrieve conversation message count and confirm for accuracy
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Retrieve GeneralMessage message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check message data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == addressToBytes32(address(0xDEED)), "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 0, "Message: participants array length incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("whats up deployer!"))),
            "Message: message incorrect");
        require(messageA.msgType == Hyperchat.MessageType.GeneralMessage, "Message: type incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL REMOVE PARTICIPANT TESTS
    //////////////////////////////////////////////////////////////*/

    // Test valid admin removing a participant address from an existing conversation
    function testLocalRemoveParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        // Remove 0xDEED from the conversation
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));

        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);

        // Retrieve AddParticipant message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check _conversations data
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Check _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 1, "Message: participants array length incorrect");
        require(messageA.participants[0] == addressToBytes32(address(0xDEED)), "Message: participants array data incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes.concat("Hyperchat: Goodbye ", addressToBytes32(address(0xDEED)), "!"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.RemoveParticipant, "Message: type incorrect");
    }

    // Test valid admin removing a participant address from an existing conversation with a custom message
    function testLocalRemoveParticipantWithCustomMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        // Remove 0xDEED from the conversation
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes("test"));

        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);

        // Retrieve AddParticipant message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 2, 2);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check _conversations data
        require(msgCountA == 3, "Conversation: messageCount incorrect");

        // Check _messages data
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("test"))),
            "Message: name incorrect");
    }

    // Test duplicate participant removals
    // Should fail with InvalidParticipant error
    function testLocalRemoveParticipantDuplicate() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Add 0xDEED to the conversation
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
        // Remove 0xDEED from the conversation
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));

        // Duplicate remove 0xDEED as participant transaction
        // Expect InvalidParticipant error as address is no longer a participant
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xDEED)), bytes(""));
    }

    // Test self-removing as participant to an already joined conversation
    // Should fail with InvalidAdmin error
    function testLocalRemoveParticipantSelfAsNonAdmin() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        
        // Prank as non-admin address 0xABCD
        hevm.startPrank(address(0xABCD));
        // Expect self-removal to fail as 0xABCD is not an admin
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        // Remove 0xDEED from the conversation
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xABCD)), bytes(""));
        hevm.stopPrank();
    }

    // Test self-removing as a conversation admin
    // Should fail with InvalidAdmin error
    function testLocalRemoveParticipantSelfAsAdmin() public {
        // Initiate a conversation (initiator is automatically admin)
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Remove admin self from the conversation
        // Expect InvalidAdmin error as active admins cannot remove themselves
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        if (address(this) == deployerAddress) {
            appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, deployerAddressBytes, bytes(""));
        }
        else if (address(this) == deployerAddress2) {
            appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, deployerAddress2Bytes, bytes(""));
        }
        else { revert(); }
    }

    // Test removing a valid address from a valid conversation as a non-participant address
    // Should fail with InvalidAdmin error
    function testLocalRemoveParticipantAsNonParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Remove 0xABCD from the conversation as non-participant 0xDEED
        // Expect InvalidAdmin error as 0xDEED is not a conversation admin/participant
        hevm.startPrank(address(0xDEED));
        hevm.expectRevert(Hyperchat.InvalidAdmin.selector);
        appA.addParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xABCD)), bytes(""));
        hevm.stopPrank();
    }

    // Test sending a general message after being removed from a valid conversation
    // Should fail with InvalidParticipant error
    function testLocalGeneralMessageAfterRemovalFromConversation() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Remove 0xABCD from the conversation
        appA.removeParticipant/*{ value: 10000000 gwei }*/(convIDA, addressToBytes32(address(0xABCD)), bytes("cya later"));
        // Attempt to send a general message as 0xABCD to convIDA
        // Expect InvalidParticipant error
        hevm.startPrank(address(0xABCD));
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("screw you!"));
        hevm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                LOCAL GENERAL MESSAGE TESTS
    //////////////////////////////////////////////////////////////*/

    // Test sending a general message as a valid participant and admin to a valid conversation
    function testLocalGeneralMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Send a message
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("GeneralMessage"));

        // Retrieve conversation data after InitiateConversation
        (uint256 msgCountA,,) = appA.retrieveConversation(convIDA);

        // Retrieve GeneralMessage message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check _conversations data
        require(msgCountA == 2, "Conversation: messageCount incorrect");

        // Check _messages data
        require(messageA.timestamp == block.timestamp, "Message: timestamp incorrect");
        require(messageA.sender == deployerAddressBytes || messageA.sender == deployerAddress2Bytes, "Message: sender incorrect");
        require(messageA.conversationID == convIDA, "Message: conversationID incorrect");
        require(messageA.participants.length == 0, "Message: participants array length incorrect");
        require(messageA.domainIDs.length == 0, "Message: domainIDs array length incorrect");
        require(keccak256(abi.encodePacked(messageA.message)) == 
            keccak256(abi.encodePacked(bytes("GeneralMessage"))),
            "Message: name incorrect");
        require(messageA.msgType == Hyperchat.MessageType.GeneralMessage, "Message: type incorrect");
    }

    // Test sending a general message as a normal valid conversation participant
    function testLocalGeneralMessageAsParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Send a message as 0xABCD
        hevm.startPrank(address(0xABCD));
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("GeneralMessage"));
        hevm.stopPrank();

        // Retrieve GeneralMessage message with retrieveMessages() function
        Hyperchat.Message[] memory messagesA = appA.retrieveMessages(convIDA, 1, 1);
        Hyperchat.Message memory messageA = messagesA[0];

        // Check _messages data
        require(messageA.sender == addressToBytes32(address(0xABCD)), "Message: sender incorrect");
    }

    // Test sending a message to a conversation as a non-participant
    // Should fail with InvalidParticipant
    function testLocalGeneralMessageAsNonParticipant() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Send a message to convIDA as 0xDEED
        hevm.startPrank(address(0xDEED));
        hevm.expectRevert(Hyperchat.InvalidParticipant.selector);
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes("whoops"));
        hevm.stopPrank();
    }

    // Test sending an empty general message as a valid participant
    // Should fail with InvalidMessage error
    function testLocalGeneralMessageNoMessage() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation/*{ value: 10000000 gwei }*/(domainsA, participantsA, convSeedA, convNameA);
        // Send an empty message
        hevm.expectRevert(Hyperchat.InvalidMessage.selector);
        appA.generalMessage/*{ value: 10000000 gwei }*/(convIDA, bytes(""));
    }

    // Test sending a general message to a conversation that doesn't exist
    // Should fail with InvalidConversation error
    function testLocalGeneralMessageInvalidConversation() public {
        // Send an empty message to a conversationID that doesn't exist
        hevm.expectRevert(Hyperchat.InvalidConversation.selector);
        appA.generalMessage/*{ value: 10000000 gwei }*/(bytes32("2"), bytes("knock knock"));
    }
}