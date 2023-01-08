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
    uint32[] domainsB = [2,1];
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

    /*//////////////////////////////////////////////////////////////
                LIBRARY FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testStringToBytes() public view {
        bytes memory test = appA.stringToBytes("test");
        require(keccak256(abi.encodePacked(test)) == keccak256(abi.encodePacked(bytes("test"))), "stringToBytes error");
    }

    function testBytesToString() public view {
        string memory test = appA.bytesToString(bytes("test"));
        require(keccak256(abi.encodePacked(test)) == keccak256(abi.encodePacked("test")), "bytesToString error");
    }

    function testAddressToBytes32() public view {
        bytes32 test = appA.addressToBytes32(address(0xABCD));
        require(test == bytes32(uint256(uint160(address(0xABCD)))), "addressToBytes32 error");
    }

    function testRetrieveMessages() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));
        // Remove deployer's 0xABCD admin approval
        appA.removeAdminApproval{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));
        // Remove 0xABCD's admin rights
        appA.removeAdmin{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));

        // Emulate Hyperlane data bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessage();

        // Test appA conversation index 0
        Hyperchat.Message[] memory messagesA0 = appA.retrieveMessages(convIDA, 0, 0);
        // Test appA conversation index range 0-2
        Hyperchat.Message[] memory messagesA0_2 = appA.retrieveMessages(convIDA, 0, 2);
        // Test appA conversation index range 2-4
        Hyperchat.Message[] memory messagesA2_4 = appA.retrieveMessages(convIDA, 2, 4);
        // Test appA conversation index range 0-4
        Hyperchat.Message[] memory messagesA0_4 = appA.retrieveMessages(convIDA, 0, 4);
        // Test appA conversation index 4
        Hyperchat.Message[] memory messagesA4 = appA.retrieveMessages(convIDA, 4, 4);

        // Test appB conversation index 0
        Hyperchat.Message[] memory messagesB0 = appB.retrieveMessages(convIDA, 0, 0);
        // Test appB conversation index range 0-2
        Hyperchat.Message[] memory messagesB0_2 = appB.retrieveMessages(convIDA, 0, 2);
        // Test appB conversation index range 2-4
        Hyperchat.Message[] memory messagesB2_4 = appB.retrieveMessages(convIDA, 2, 4);
        // Test appA conversation index range 0-4
        Hyperchat.Message[] memory messagesB0_4 = appB.retrieveMessages(convIDA, 0, 4);
        // Test appB conversation index 4
        Hyperchat.Message[] memory messagesB4 = appB.retrieveMessages(convIDA, 4, 4);

        // Out of bounds tests
        hevm.expectRevert("Hyperchat::retrieveMessages::OUT_OF_BOUNDS");
        appA.retrieveMessages(convIDA, 5, 5);
        hevm.expectRevert("Hyperchat::retrieveMessages::OUT_OF_BOUNDS");
        appA.retrieveMessages(convIDA, 4, 5);
        hevm.expectRevert("Hyperchat::retrieveMessages::OUT_OF_BOUNDS");
        appA.retrieveMessages(convIDA, 0, 5);
        hevm.expectRevert("Hyperchat::retrieveMessages::OUT_OF_BOUNDS");
        appA.retrieveMessages(convIDA, 5, 6);

        // Invalid range tests
        hevm.expectRevert("Hyperchat::retrieveMessages::INVALID_RANGE");
        appA.retrieveMessages(convIDA, 1, 0);
        hevm.expectRevert("Hyperchat::retrieveMessages::INVALID_RANGE");
        appA.retrieveMessages(convIDA, 3, 1);
        hevm.expectRevert("Hyperchat::retrieveMessages::INVALID_RANGE");
        appA.retrieveMessages(convIDA, 5, 4);

        // appA == appB comparisons
        require(messagesA0[0].msgType == messagesB0[0].msgType, "retrieveMessages error");
        require(messagesA0_2[0].msgType == messagesB0_2[0].msgType, "retrieveMessages error");
        require(messagesA0_2[1].msgType == messagesB0_2[1].msgType, "retrieveMessages error");
        require(messagesA0_2[2].msgType == messagesB0_2[2].msgType, "retrieveMessages error");
        require(messagesA2_4[0].msgType == messagesB2_4[0].msgType, "retrieveMessages error");
        require(messagesA2_4[1].msgType == messagesB2_4[1].msgType, "retrieveMessages error");
        require(messagesA2_4[2].msgType == messagesB2_4[2].msgType, "retrieveMessages error");
        require(messagesA0_4[0].msgType == messagesB0_4[0].msgType, "retrieveMessages error");
        require(messagesA0_4[1].msgType == messagesB0_4[1].msgType, "retrieveMessages error");
        require(messagesA0_4[2].msgType == messagesB0_4[2].msgType, "retrieveMessages error");
        require(messagesA0_4[3].msgType == messagesB0_4[3].msgType, "retrieveMessages error");
        require(messagesA0_4[4].msgType == messagesB0_4[4].msgType, "retrieveMessages error");
        require(messagesA4[0].msgType == messagesB4[0].msgType, "retrieveMessages error");
    }

    function testRetrieveConversation() public {
        // Initiate two conversations, one from each domain
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);
        convIDB = appB.initiateConversation{ value: 100000 gwei }(domainsB, participantsA, convSeedA, convNameA);

        // Process Hyperlane bridging
        testEnv.processNextPendingMessage();
        testEnv.processNextPendingMessageFromDestination();

        // Retrieve conversation data from all perspectives
        (uint256 msgCountA_A, bytes32 convIDA_A, bytes memory nameA_A) = appA.retrieveConversation(convIDA);
        (uint256 msgCountA_B, bytes32 convIDA_B, bytes memory nameA_B) = appA.retrieveConversation(convIDB);
        (uint256 msgCountB_A, bytes32 convIDB_A, bytes memory nameB_A) = appB.retrieveConversation(convIDA);
        (uint256 msgCountB_B, bytes32 convIDB_B, bytes memory nameB_B) = appB.retrieveConversation(convIDB);

        // Compare all conversation data
        require(msgCountA_A == msgCountB_A, "msgCount mismatch");
        require(msgCountA_B == msgCountB_B, "msgCount mismatch");
        require(keccak256(abi.encodePacked(convIDA_A)) == keccak256(abi.encodePacked(convIDB_A)), "convID mismatch");
        require(keccak256(abi.encodePacked(convIDA_B)) == keccak256(abi.encodePacked(convIDB_B)), "convID mismatch");
        require(keccak256(abi.encodePacked(nameA_A)) == keccak256(abi.encodePacked(nameB_A)), "name mismatch");
        require(keccak256(abi.encodePacked(nameA_B)) == keccak256(abi.encodePacked(nameB_B)), "name mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    // Test removing the first admin address in a valid conversation's admin array
    function testInternalRemoveFromAdminArrayFirst() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));

        // Remove first admin address
        appA.removeFromAdminArray(convIDA, 0);
    }

    // Test removing the last admin address in a valid conversation's admin array
    function testInternalRemoveFromAdminArrayLast() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);
        // Give 0xABCD admin approval
        appA.addAdminApproval{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));
        // Make 0xABCD an admin as deployer of a new conversation is the entire voting/admin pool
        appA.addAdmin{ value: 100000 gwei }(convIDA, participantsA[0], bytes(""));

        // Remove first admin address
        appA.removeFromAdminArray(convIDA, 1);
    }

    // Test removing the only admin address in a valid conversation's admin array
    function testInternalRemoveFromAdminArrayOnly() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);

        // Remove first admin address
        appA.removeFromAdminArray(convIDA, 0);
    }

    // Test trying to remove an admin address at an out of bounds index value
    // Should fail with InvalidIndex
    function testInternalRemoveFromAdminArrayOOB() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);

        // Attempt to remove second admin address from admin array
        // Expect InvalidIndex error as index is out of bounds
        hevm.expectRevert(Hyperchat.InvalidIndex.selector);
        appA.removeFromAdminArray(convIDA, 1);
    }

    // Test trying to force initiate a conversation with an already existing conversation ID
    // Should fail with InvalidConversation
    function testInitiateConversationForceDuplicateConversationID() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation{ value: 100000 gwei }(domainsA, participantsA, convSeedA, convNameA);
    }
}