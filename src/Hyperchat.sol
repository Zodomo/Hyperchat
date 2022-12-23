// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//import "hyperlane/Router.sol";
import "openzeppelin-contracts/access/Ownable2Step.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
abstract contract Hyperchat is /*Router,*/ Ownable2Step {

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                EVENTS/ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    event ConversationCreated(bytes32 indexed conversationID, bytes32 indexed initiator, bytes indexed name);
    event AdminApprovalAdded(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed candidate);
    event AdminApprovalRemoved(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed candidate);
    event AdminAdded(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed candidate);
    event AdminRemoved(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed candidate);
    event ParticipantAdded(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed participant);
    event ParticipantRemoved(bytes32 indexed conversationID, bytes32 indexed admin, bytes32 indexed participant);
    event ChainAdded(bytes32 indexed conversationID, bytes32 indexed admin, uint32 indexed domainID);
    event ChainRemoved(bytes32 indexed conversationID, bytes32 indexed admin, uint32 indexed domainID);
    event GeneralMessage(bytes32 indexed conversationID, bytes32 indexed sender, bytes indexed message);
    event MessageSent(bytes32 indexed conversationID, bytes32 indexed sender, bytes indexed message);
    event MessageReceived(bytes32 indexed conversationID, bytes32 indexed sender, bytes indexed message);

    error InvalidConversation();
    error InvalidParticipant();
    error InvalidApprovals();
    error InvalidInstance();
    error InvalidDomainID();
    error InvalidMessage();
    error InvalidLength();
    error InvalidAdmin();
    error InvalidType();

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Hyperlane data structures
    uint32 private immutable HYPERLANE_DOMAIN_IDENTIFIER;
    address private immutable HYPERLANE_OUTBOX;

    // Message Types
    enum MessageType {
        InitiateConversation,
        AddAdminApproval,
        RemoveAdminApproval,
        AddAdmin,
        RemoveAdmin,
        AddParticipant,
        RemoveParticipant,
        AddHyperlaneDomain,
        RemoveHyperlaneDomain,
        GeneralMessage
    }

    // Message data struct
    struct Message {
        uint256 timestamp;
        bytes32 sender;
        bytes32 conversationID;
        bytes32[] participants; // Participant addresses to be utilized in management functions
        uint32[] domainIDs; // Hyperlane domainIDs to add/remove
        bytes message; // Chat message
        MessageType msgType;
    }
    // conversationID => messageNum => Message data struct
    mapping(bytes32 => mapping(uint256 => Message)) private _messages;

    struct Conversation {
        uint256 messageCount;
        bytes32 conversationID;
        uint32[] domainIDs;
        bytes32[] admins;
        bytes name;
        mapping(bytes32 => bool) isAdmin;
        mapping(bytes32 => mapping(bytes32 => bool)) adminApprovals;
        mapping(bytes32 => bool) parties;
    }
    // conversationID => Conversation data struct
    mapping(bytes32 => Conversation) private _conversations;
    uint256 public conversationCount;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    modifier onlyMember(bytes32 _conversationID) {
        if (_conversations[_conversationID].conversationID == 0) {
            revert InvalidConversation();
        }
        if (!_conversations[_conversationID].parties[addressToBytes32(msg.sender)]) {
            revert InvalidParticipant();
        }
        _;
    }

    modifier onlyAdmin(bytes32 _conversationID) {
        if (_conversations[_conversationID].conversationID == 0) {
            revert InvalidConversation();
        }
        if (!_conversations[_conversationID].isAdmin[addressToBytes32(msg.sender)]) {
            revert InvalidAdmin();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    constructor(uint32 _hyperlaneDomainID, address _hyperlaneOutbox) payable {
        // Transfer ownership of the contract to deployer
        _transferOwnership(msg.sender);
        
        // Set to Hyperlane Domain Identifier of Station chain
        HYPERLANE_DOMAIN_IDENTIFIER = _hyperlaneDomainID;
        // Set to Hyperlane Outbox on Station chain
        HYPERLANE_OUTBOX = _hyperlaneOutbox;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                LIBRARY
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Converts string to bytes
    function stringToBytes(string memory _string) public pure returns (bytes memory) {
        return bytes(_string);
    }

    // Converts bytes to string
    function bytesToString(bytes memory _message) public pure returns (string memory) {
        return string(_message);
    }

    // Converts address to bytes32 for Hyperlane
    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    // Retrieves messages in hopefully a more RPC-efficient manner
    function retrieveMessages(
        bytes32 _conversationID,
        uint256 initialMessage,
        uint256 finalMessage
    ) public view returns (Message[] memory) {
        // Ensure finalMessage index isn't below initialMessage index
        require(initialMessage <= finalMessage, "Hyperchat::retrieveMessages::INVALID_RANGE");

        // Determine messages array size
        uint256 range = finalMessage - initialMessage + 1;

        // Create messages bytes[] array to store retrieved messages
        Message[] memory messages = new Message[](range);
        
        // Iterate across range and retrieve each message
        for (uint256 i; i + initialMessage <= finalMessage;) {
            messages[i] = _messages[_conversationID][i];
            // Cant overflow as we confirm range bounds before loop
            unchecked { ++i; }
        }

        return messages;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Removes admin at admins array _index
    function _removeFromAdminArray(bytes32 _conversationID, uint256 _index) internal {
        // Revert if index out of bounds
        uint256 length = _conversations[_conversationID].admins.length;
        if (_index >= length) {
            revert InvalidLength();
        }

        for (uint i = _index; i < length - 1;) {
            _conversations[_conversationID].admins[i] = _conversations[_conversationID].admins[i + 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }

        _conversations[_conversationID].admins.pop();
    }

    // Removes domainID at domainIDs array _index
    function _removeFromDomainIDArray(bytes32 _conversationID, uint256 _index) internal {
        // Revert if index out of bounds
        uint256 length = _conversations[_conversationID].domainIDs.length;
        if (_index >= length) {
            revert InvalidLength();
        }

        for (uint i = _index; i < length - 1;) {
            _conversations[_conversationID].domainIDs[i] = _conversations[_conversationID].domainIDs[i + 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }

        _conversations[_conversationID].domainIDs.pop();
    }

    // Process a received message
    function _processMessage(Message memory _message) internal {
        // Retrieve conversationID
        bytes32 conversationID = _message.conversationID;
        // Retrieve sender
        bytes32 sender = _message.sender;
        // Retrieve MessageType
        MessageType msgType = _message.msgType;

        if (msgType == MessageType.InitiateConversation) {
            _processInitiateConversation(_message);
        }
        else if (msgType == MessageType.AddAdminApproval || msgType == MessageType.RemoveAdminApproval) {
            _processAdminApprovalMessage(_message);
        }
        else if (msgType == MessageType.AddAdmin || msgType == MessageType.RemoveAdmin) {
            
        }
        else if (msgType == MessageType.AddParticipant || msgType == MessageType.RemoveParticipant) {
            _processParticipantMessage(_message);
        }
        else if (msgType == MessageType.AddHyperlaneDomain || msgType == MessageType.RemoveHyperlaneDomain) {
            
        }
        else if (msgType == MessageType.GeneralMessage) {
            
        }
        else {
            revert InvalidType();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                CONVERSATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////////
                INITIATE CONVERSATION
    //////////////////////////////////////////////////////////////////////////////*/

    // Initiate a conversation
    function initiateConversation(
        uint32[] memory _domainIDs,
        bytes32[] memory _parties,
        bytes memory _seed,
        bytes memory _name
    ) public returns (bytes32 conversationID) {
        // Calculate conversationID
        // Extremely packed to prevent any chance of MEV abuse or collision
        conversationID = bytes32(abi.encodePacked(
            msg.sender,
            address(this),
            HYPERLANE_DOMAIN_IDENTIFIER,
            HYPERLANE_OUTBOX,
            blockhash(1),
            block.number,
            block.difficulty,
            block.timestamp,
            block.chainid,
            block.coinbase,
            conversationCount,
            _seed,
            _name
        ));

        if (_conversations[conversationID].conversationID == conversationID) {
            revert InvalidConversation();
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        // Prep InitiateConversation Message to duplicate action on other instances
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;

        // Initialize Conversation
        _conversations[conversationID].conversationID = message.conversationID = conversationID;
        conversationCount += 1;

        // Set initializer as conversation admin
        _conversations[conversationID].admins.push(admin); // Add to conversation admin array
        _conversations[conversationID].isAdmin[admin] = true; // Set admin status mapping
        _conversations[conversationID].adminApprovals[admin][admin] = true; // Set self-approval for admin status

        // Process current Hyperlane domainID
        _conversations[conversationID].domainIDs[0] = message.domainIDs[0] = HYPERLANE_DOMAIN_IDENTIFIER;
        // Process user-supplied Hyperlane domainIDs
        uint offset;
        for (uint i = 1; i <= _domainIDs.length;) {
            // Skip the domainID for this chain if supplied as that was already added
            if (_domainIDs[i - 1] == HYPERLANE_DOMAIN_IDENTIFIER) {
                // Shouldn't overflow
                unchecked { ++i; ++offset; }
                continue;
            }
            _conversations[conversationID].domainIDs[i] = message.domainIDs[i - offset] = _domainIDs[i - 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }

        // Process participant addresses
        offset = 0;
        _conversations[conversationID].parties[admin] = true;
        message.participants[0] = admin;
        for (uint i = 1; i <= _parties.length;) {
            // Skip sender's address as that was already added
            if (_parties[i - 1] == admin) {
                unchecked { ++i; ++offset; }
                continue;
            }
            _conversations[conversationID].parties[_parties[i - 1]] = true;
            message.participants[i - offset] = _parties[i - 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }
        message.participants = _parties;

        // Set conversation name
        _conversations[conversationID].name = message.message = bytes.concat("Hyperlane: Initiated ", _name, "!");

        // Set message type
        message.msgType = MessageType.InitiateConversation;

        emit ConversationCreated(conversationID, admin, _name);

        sendMessage(conversationID, abi.encode(message));

        return conversationID;
    }

    // Internal InitiateConversation Message type processing logic
    function _processInitiateConversation(Message memory _message) internal {
        // Retrieve conversationID
        bytes32 conversationID = _message.conversationID;
        // Retrieve sender address
        bytes32 sender = _message.sender;
        
        // Revert if conversation already exists
        if (_conversations[conversationID].conversationID != bytes32(0)) {
            revert InvalidConversation();
        }

        // Initialize conversation with conversationID
        _conversations[conversationID].conversationID = conversationID;
        conversationCount += 1;

        // Set initializer as conversation admin
        _conversations[conversationID].admins.push(sender); // Add to conversation admin array
        _conversations[conversationID].isAdmin[sender] = true; // Set admin status mapping
        _conversations[conversationID].adminApprovals[sender][sender] = true; // Set self-approval for admin status

        // Process Hyperlane domainIDs
        for (uint i; i < _message.domainIDs.length;) {
            _conversations[conversationID].domainIDs.push(_message.domainIDs[i]);
            // Shouldn't overflow
            unchecked { ++i; }
        }

        // Process participant addresses
        for (uint i; i < _message.participants.length;) {
            _conversations[conversationID].parties[_message.participants[i]] = true;
            // Shouldn't overflow
            unchecked { ++i; }
        }

        // Set conversation name
        _conversations[conversationID].name = _message.message;

        emit ConversationCreated(conversationID, sender, _message.message);
    }

    /*//////////////////////////////////////////////////////////////////////////////
                ADMIN APPROVALS
    //////////////////////////////////////////////////////////////////////////////*/

    // Vote for an address to become a conversation admin
    // A message can be included with the vote
    function addAdminApproval(
        bytes32 _conversationID,
        bytes32 _address,
        bytes memory _message
    ) public onlyAdmin(_conversationID) {
        // Revert if _address isnt a member
        if (!_conversations[_conversationID].parties[_address]) {
            revert InvalidParticipant();
        }
        
        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        // Add admin vote for admin rights approval, revert if approval is already true
        if (!_conversations[_conversationID].adminApprovals[admin][_address]) {
            _conversations[_conversationID].adminApprovals[admin][_address] = true;
        } else {
            revert InvalidApprovals();
        }

        // Prepare AddAdminApproval Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants[0] = _address;
        if (_message.length > 0) {
            message.message = _message;
        }
        else {
            message.message = bytes.concat("Hyperchat: ", admin, " gave admin approval for ", _address, "!");
        }
        message.msgType = MessageType.AddAdminApproval;

        sendMessage(_conversationID, abi.encode(message));

        emit AdminApprovalAdded(_conversationID, admin, _address);
    }

    // Vote for an address to lose its conversation admin rights
    // A message can be included with the vote
    function removeAdminApproval(
        bytes32 _conversationID,
        bytes32 _address,
        bytes memory _message
    ) public onlyAdmin(_conversationID) {
        // Revert if _address isnt a member
        if (!_conversations[_conversationID].parties[_address]) {
            revert InvalidParticipant();
        }
        
        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);
        
        // Remove admin vote for admin rights approval, revert if approval is already false
        if (_conversations[_conversationID].adminApprovals[admin][_address]) {
            _conversations[_conversationID].adminApprovals[admin][_address] = false;
        } else {
            revert InvalidApprovals();
        }

        // Prepare RemoveAdminApproval Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants[0] = _address;
        if (_message.length > 0) {
            message.message = _message;
        }
        else {
            message.message = bytes.concat("Hyperchat: ", admin, " revoked admin approval for ", _address, "!");
        }
        message.msgType = MessageType.RemoveAdminApproval;

        sendMessage(_conversationID, abi.encode(message));

        emit AdminApprovalRemoved(_conversationID, admin, _address);
    }

    // Internal Add/RemoveAdminApproval Message type processing logic
    function _processAdminApprovalMessage(Message memory _message) internal {
        // Retrieve conversationID
        bytes32 conversationID = _message.conversationID;
        // Retrieve sender address
        bytes32 admin = _message.sender;
        // Retrieve admin candidate address
        bytes32 candidate = _message.participants[0];

        // Process Add or RemoveAdminApproval request, revert if neither type
        if (_message.msgType == MessageType.AddAdminApproval) {
            _conversations[conversationID].adminApprovals[admin][candidate] = true;

            emit AdminApprovalAdded(conversationID, admin, candidate);
        } 
        else if (_message.msgType == MessageType.RemoveAdminApproval) {
            delete _conversations[conversationID].adminApprovals[admin][candidate];

            emit AdminApprovalRemoved(conversationID, admin, candidate);
        }
        else {
            revert InvalidType();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////
                ADMIN ADDITIONS/REMOVALS
    //////////////////////////////////////////////////////////////////////////////*/

    // Give an approved address conversation admin rights
    function addAdmin(
        bytes32 _conversationID,
        bytes32 _address,
        bytes memory _message
    ) public onlyAdmin(_conversationID) {
        // Revert if _address isnt a member
        if (!_conversations[_conversationID].parties[_address]) {
            revert InvalidParticipant();
        }
        // Revert if _address is already an admin
        if (_conversations[_conversationID].isAdmin[_address]) {
            revert InvalidAdmin();
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);
        
        // Retrieve admin count
        uint256 adminCount = _conversations[_conversationID].admins.length;
        // Keep track of approval count for following for loop
        uint256 approvals;
        // Check each admin's approval status for _address
        for (uint i; i < adminCount;) {
            // Retrieve admin address at index i
            bytes32 adminAddress = _conversations[_conversationID].admins[i];

            // Count approval (if any)
            if (_conversations[_conversationID].adminApprovals[adminAddress][_address]) {
                approvals += 1;
            }

            // Once 51% approval threshold is met, break loop to save gas
            if (approvals > adminCount / 2) {
                break;
            }

            // Loop shouldn't ever overflow
            unchecked { ++i; }
        }

        // If 51% approval threshold is met, give _address conversation admin rights
        if (approvals > adminCount / 2) {
            // Set admin data structures
            _conversations[_conversationID].admins.push(_address);
            _conversations[_conversationID].isAdmin[_address] = true;
            _conversations[_conversationID].adminApprovals[_address][_address] = true;

            emit AdminAdded(_conversationID, admin, _address);
        } else {
            revert InvalidApprovals();
        }

        // Prepare AddAdminApproval Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants[0] = _address;
        if (_message.length > 0) {
            message.message = _message;
        }
        else {
            message.message = bytes.concat("Hyperchat: ", admin, " added ", _address, "to conversation as admin!");
        }
        message.msgType = MessageType.AddAdmin;

        sendMessage(_conversationID, abi.encode(message));
    }

    // Remove an addresss conversation admin rights
    function removeAdmin(
        bytes32 _conversationID,
        bytes32 _address,
        bytes memory _message
    ) public onlyAdmin(_conversationID) {
        // Revert if _address isnt a member
        if (!_conversations[_conversationID].parties[_address]) {
            revert InvalidParticipant();
        }
        // Revert if _address isn't already an admin
        if (!_conversations[_conversationID].isAdmin[_address]) {
            revert InvalidAdmin();
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);
        
        // Retrieve admin count
        uint256 adminCount = _conversations[_conversationID].admins.length;
        // Keep track of approval count for following for loop
        uint256 approvals;
        // Check each admin's approval status for _address
        for (uint i; i < adminCount;) {
            // Retrieve admin address at index i
            bytes32 adminAddress = _conversations[_conversationID].admins[i];

            // Count approval (if any)
            if (_conversations[_conversationID].adminApprovals[adminAddress][_address]) {
                approvals += 1;
            }

            // If above 51% approval threshold, break loop to save gas
            if (approvals > adminCount / 2) {
                break;
            }

            // Loop shouldn't ever overflow
            unchecked { ++i; }
        }

        // If 51% approval threshold isn't met, remove _address' conversation admin rights
        if (approvals <= adminCount / 2) {
            // Search through admins array for _address and remove it
            for (uint j; j < adminCount;) {
                if (_conversations[_conversationID].admins[j] == _address) {
                    _removeFromAdminArray(_conversationID, j);
                    break;
                }
            }

            // Remove admin data structures
            delete _conversations[_conversationID].isAdmin[_address];
            delete _conversations[_conversationID].adminApprovals[_address][_address];

            emit AdminRemoved(_conversationID, addressToBytes32(msg.sender), _address);
        } else {
            revert InvalidApprovals();
        }

        // Prepare AddAdminApproval Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants[0] = _address;
        if (_message.length > 0) {
            message.message = _message;
        }
        else {
            message.message = bytes.concat("Hyperchat: ", admin, " removed ", _address, "from conversation as admin!");
        }
        message.msgType = MessageType.RemoveAdmin;

        sendMessage(_conversationID, abi.encode(message));
    }

    // Internal Add/RemoveAdmin Message type processing logic
    function _processAdminMessage(Message memory _message) internal {
        // Retrieve conversationID
        bytes32 conversationID = _message.conversationID;
        // Retrieve sender address
        bytes32 admin = _message.participants[0];

        // Process Add or RemoveAdmin request, revert if neither type
        if (_message.msgType == MessageType.AddAdmin) {
            _conversations[conversationID].admins.push(admin);
            _conversations[conversationID].isAdmin[admin] = true;
            _conversations[conversationID].adminApprovals[admin][admin] = true;
        } 
        else if (_message.msgType == MessageType.RemoveAdmin) {
            // Retrieve admin count
            uint256 adminCount = _conversations[conversationID].admins.length;
            // Search through admins array for address and remove it
            for (uint i; i < adminCount;) {
                if (_conversations[conversationID].admins[i] == admin) {
                    _removeFromAdminArray(conversationID, i);
                    break;
                }
            }

            // Remove admin data structures
            delete _conversations[conversationID].isAdmin[admin];
            delete _conversations[conversationID].adminApprovals[admin][admin];
        }
        else {
            revert InvalidType();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////
                PARTICIPANT ADDITIONS/REMOVALS
    //////////////////////////////////////////////////////////////////////////////*/

    // Add an address to a conversation
    function addParticipant(
        bytes32 _conversationID,
        bytes32 _address,
        bytes memory _message
    ) public onlyAdmin(_conversationID) {
        // Add if not present, else revert
        if (!_conversations[_conversationID].parties[_address]) {
            _conversations[_conversationID].parties[_address] = true;
        } else {
            revert InvalidParticipant();
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        // Prepare AddParticipant Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants[0] = _address;
        if (_message.length > 0) {
            message.message = _message;
        }
        else {
            message.message = bytes.concat("Hyperchat: Welcome ", _address, "!");
        }
        message.msgType = MessageType.AddParticipant;

        sendMessage(_conversationID, abi.encode(message));

        emit ParticipantAdded(_conversationID, admin, _address);
    }

    // Remove an address from a conversation
    function removeParticipant(
        bytes32 _conversationID,
        bytes32 _address,
        bytes memory _message
    ) public onlyAdmin(_conversationID) {
        // Remove if present, else revert
        if (_conversations[_conversationID].parties[_address]) {
            delete _conversations[_conversationID].parties[_address];
        } else {
            revert InvalidParticipant();
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        // Prepare RemoveParticipant Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants[0] = _address;
        if (_message.length > 0) {
            message.message = _message;
        }
        else {
            message.message = bytes.concat("Hyperchat: Goodbye ", _address, "!");
        }
        message.msgType = MessageType.RemoveParticipant;

        sendMessage(_conversationID, abi.encode(message));

        emit ParticipantRemoved(_conversationID, admin, _address);
    }

    // Internal Add/RemoveParticipant Message type processing logic
    function _processParticipantMessage(Message memory _message) internal {
        // Retrieve conversationID
        bytes32 conversationID = _message.conversationID;
        // Retrieve sender address
        bytes32 admin = _message.sender;
        // Retrieve admin candidate address
        bytes32 candidate = _message.participants[0];

        // Process Add/RemoveParticipant request, revert if neither type
        if (_message.msgType == MessageType.AddParticipant) {
            _conversations[conversationID].parties[candidate] = true;

            emit ParticipantAdded(conversationID, admin, candidate);
        } 
        else if (_message.msgType == MessageType.RemoveAdminApproval) {
            delete _conversations[conversationID].parties[candidate];

            emit ParticipantRemoved(conversationID, admin, candidate);
        }
        else {
            revert InvalidType();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////////
                HYPERLANE DOMAIN ADDITIONS/REMOVALS
    //////////////////////////////////////////////////////////////////////////////*/

    // Add a domainID to a conversation
    function addHyperlaneDomain(bytes32 _conversationID, uint32 _domainID) public onlyAdmin(_conversationID) {
        // Check to make sure domain hasn't already been added
        for (uint i; i < _conversations[_conversationID].domainIDs.length;) {
            // If found, revert
            if (_conversations[_conversationID].domainIDs[i] == _domainID) {
                revert InvalidDomainID();
            }
        }

        // Add _domainID if no revert occurred
        _conversations[_conversationID].domainIDs.push(_domainID);

        emit ChainAdded(_conversationID, addressToBytes32(msg.sender), _domainID);
    }

    // Remove a domainID from a conversation
    function removeHyperlaneDomain(bytes32 _conversationID, uint32 _domainID) public onlyAdmin(_conversationID) {
        // Look through array for _domainID
        bool found;
        for (uint i; i < _conversations[_conversationID].domainIDs.length;) {
            // If found, process removal and end loop
            if (_conversations[_conversationID].domainIDs[i] == _domainID) {
                _removeFromDomainIDArray(_conversationID, i);
                found = true;

                break;
            }
        }

        // Revert if not found
        if (!found) {
            revert InvalidDomainID();
        }

        emit ChainRemoved(_conversationID, addressToBytes32(msg.sender), _domainID);
    }

    /*//////////////////////////////////////////////////////////////////////////////
                GENERAL MESSAGES
    //////////////////////////////////////////////////////////////////////////////*/

    // Send general message
    function generalMessage(bytes32 _conversationID, bytes memory _message) public onlyMember(_conversationID) {
        // Revert if _message is zero bytes
        if (_message.length == 0) {
            revert InvalidMessage();
        }
        
        // Convert msg.sender address
        bytes32 sender = addressToBytes32(msg.sender);
        
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = sender;
        message.conversationID;
        message.message = _message;
        message.msgType = MessageType.GeneralMessage;
        // Convert Memory object to bytes for function call and event emission
        bytes memory envelope = abi.encode(message);

        sendMessage(_conversationID, envelope);

        emit GeneralMessage(_conversationID, sender, envelope);
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                SEND/RECEIVE MESSAGE LOGIC
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Send message of any type to conversation
    // Message will be broadcast to all domainIDs in conversation metadata
    function sendMessage(bytes32 _conversationID, bytes memory _message) public onlyMember(_conversationID) {
        // Iterate sending via hyperlane to each domainID
        for (uint i; i < _conversations[_conversationID].domainIDs.length;) {
            // Retrieve domainID at index i
            uint32 domainID = _conversations[_conversationID].domainIDs[i];

            // Skip sending to the domainID for this chain as its logic was already processed locally
            if (domainID == HYPERLANE_DOMAIN_IDENTIFIER) {
                // Still append to _messages mapping though
                _messages[_conversationID][_conversations[_conversationID].messageCount] = abi.decode(_message, (Message));
                // Shouldn't overflow
                unchecked { ++i; }
                continue;
            }

            // TODO: Dispatch message via Hyperlane to Hyperchat instance on domainID
            //_dispatch(domainID, _message);
        }

        // Increment conversation message count
        _conversations[_conversationID].messageCount += 1;

        emit MessageSent(_conversationID, addressToBytes32(msg.sender), _message);
    }
    
    // TODO: Uncomment function once Router.sol is inherited properly
    /*
    // Overriding the Hyperlane Router.sol's _handle() function is how receive logic is implemented
    function _handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) internal override {
        // Decode message back into Message type
        Message memory message = abi.decode(_message, (Message));
        // Retrieve conversationID
        bytes32 conversationID = message.conversationID;
        // Retrieve sender
        bytes32 sender = message.sender;
        // Retrieve MessageType
        MessageType msgType = message.msgType;

        emit MessageReceived(conversationID, sender, _message)

        // Process Message data
        _processMessage(message);

        // Save message in _messages storage
        _messages[conversationID][_conversations[conversationID].messageCount] = _message;

        // Increment conversation message count
        _conversations[conversationID].messageCount += 1;
    }
    */
}