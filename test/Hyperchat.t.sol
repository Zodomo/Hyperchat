// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../src/Hyperchat.sol";

contract HyperchatTest is DSTestPlus {

    /*//////////////////////////////////////////////////////////////
                SETUP
    //////////////////////////////////////////////////////////////*/

    Hyperchat appA;
    uint32[] domains = [1,2];
    bytes32[] participants = [addressToBytes32(address(0xABCD)), addressToBytes32(address(0xBEEF))];
    bytes convSeedA = bytes("I <3 EVM!");
    bytes convNameA = bytes("Hello World");
    bytes32 convIDA;

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }
    
    function setUp() public {
        appA = new Hyperchat(1);
    }

    function testInitiateConversation() public {
        convIDA = appA.initiateConversation(domains, participants, convSeedA, convNameA);
    }
}