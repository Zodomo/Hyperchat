// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../src/Hyperchat.sol";

contract HyperchatWithInternalFunctions is Hyperchat {

    constructor(
        uint32 _hyperlaneDomainID,
        address _mailbox,
        address _hyperlaneIGP
    ) Hyperchat (
        _hyperlaneDomainID,
        _mailbox,
        _hyperlaneIGP
    ) payable {   }

    function removeFromAdminArray(bytes32 _conversationID, uint256 _index) public {
        _removeFromAdminArray(_conversationID, _index);
    }

    function sendMessage(bytes32 _conversationID, bytes memory _message) public payable {
        // Require msg.value == 100000 gwei for current InterchainGasPaymaster integration until on-chain gas estimation is implemented
        require(msg.value >= 100000 gwei, "Not enough gas for Hyperlane InterchainGasPaymaster");
        
        _sendMessage(_conversationID, _message);
    }

    // Used to spoof conversationCount in order to generate a duplicate conversationID
    function decrementConversationCount(uint256 _amount) public {
        conversationCount -= _amount;
    }
}