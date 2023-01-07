// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console.sol";

import "hyperlane/mock/MockHyperlaneEnvironment.sol";
import "../src/Hyperchat.sol";

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

    Hyperchat appA;
    Hyperchat appB;
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

        // Hyperchat and Hyperlane Router Setup
        appA = new Hyperchat(1, mailboxA);
        appB = new Hyperchat(2, mailboxB);
        appA.enrollRemoteRouter(2, addressToBytes32(address(appB)));
        appB.enrollRemoteRouter(1, addressToBytes32(address(appA)));
    }

    function testRemoteInitiateConversation() public {
        // Initiate a conversation
        convIDA = appA.initiateConversation(domainsA, participantsA, convSeedA, convNameA);
        testEnv.processNextPendingMessage();
    }
}