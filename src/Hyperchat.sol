// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//import "hyperlane/Router.sol";

// Hyperchat is a contract that leverages the Hyperlane Messaging API to relay chat messages to users of any chain
contract Hyperchat /*is Router*/ {

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
    event GeneralMessage(bytes32 indexed conversationID, bytes32 indexed sender, bytes indexed message);
    event MessageSent(bytes32 indexed conversationID, bytes32 indexed sender, bytes indexed message);
    event MessageReceived(bytes32 indexed conversationID, bytes32 indexed sender, bytes indexed message);

    error InvalidConversation();
    error InvalidParticipant();
    error InvalidApprovals();
    error InvalidMessage();
    error InvalidLength();
    error InvalidAdmin();
    error InvalidType();

    /*//////////////////////////////////////////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Hyperlane data structures
    uint32 private immutable HYPERLANE_DOMAIN_IDENTIFIER;

    // Message Types
    enum MessageType {
        InitiateConversation,
        AddAdminApproval,
        RemoveAdminApproval,
        AddAdmin,
        RemoveAdmin,
        AddParticipant,
        RemoveParticipant,
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
        mapping(bytes32 => bool) allowlist;
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
        if (!_conversations[_conversationID].allowlist[addressToBytes32(msg.sender)]) {
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

    constructor(uint32 _hyperlaneDomainID) payable {        
        // Set to Hyperlane Domain Identifier of Station chain
        HYPERLANE_DOMAIN_IDENTIFIER = _hyperlaneDomainID;
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
        for (uint256 i = initialMessage; i <= finalMessage;) {
            messages[i - initialMessage] = _messages[_conversationID][i];
            // Cant overflow as we confirm range bounds before loop
            unchecked { ++i; }
        }

        return messages;
    }

    // Retrieves conversation data
    function retrieveConversation(bytes32 _conversationID) public view returns (uint256, bytes32, bytes memory) {
        uint256 messageCount = _conversations[_conversationID].messageCount;
        bytes32 conversationID = _conversations[_conversationID].conversationID;
        bytes memory name = _conversations[_conversationID].name;
        
        return (messageCount, conversationID, name);
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

    // Process a received message
    function _processMessage(Message memory _message) internal {
        // Retrieve conversationID
        bytes32 conversationID = _message.conversationID;
        // Retrieve sender
        bytes32 sender = _message.sender;
        // Retrieve admin candidate address
        bytes32 candidate = _message.participants[0];
        // Retrieve MessageType
        MessageType msgType = _message.msgType;

        // Process message logic based off MessageType
        if (msgType == MessageType.InitiateConversation) {
            // Process internal InitiateConversation logic (too much to implement here)
            _processInitiateConversation(_message);
        }
        else if (msgType == MessageType.AddAdminApproval) {
            // Set admin approval
            _conversations[conversationID].adminApprovals[sender][candidate] = true;

            emit AdminApprovalAdded(conversationID, sender, candidate);
        }
        else if (msgType == MessageType.RemoveAdminApproval) {
            // Remove admin approval
            delete _conversations[conversationID].adminApprovals[sender][candidate];

            emit AdminApprovalRemoved(conversationID, sender, candidate);
        }
        else if (msgType == MessageType.AddAdmin) {
            // Populate all admin-related fields and give self-approval
            _conversations[conversationID].admins.push(candidate);
            _conversations[conversationID].isAdmin[candidate] = true;
            _conversations[conversationID].adminApprovals[candidate][candidate] = true;

            emit AdminAdded(conversationID, sender, candidate);
        }
        else if (msgType == MessageType.RemoveAdmin) {
            // Retrieve admin count
            uint256 adminCount = _conversations[conversationID].admins.length;
            // Search through admins array for address and remove it
            for (uint i; i < adminCount;) {
                if (_conversations[conversationID].admins[i] == candidate) {
                    // Internal admin array removal logic
                    _removeFromAdminArray(conversationID, i);
                    break;
                }
            }

            // Remove admin data structures
            delete _conversations[conversationID].isAdmin[candidate];
            delete _conversations[conversationID].adminApprovals[candidate][candidate];

            emit AdminRemoved(conversationID, sender, candidate);
        }
        else if (msgType == MessageType.AddParticipant) {
            // Add to conversation allowed allowlist
            _conversations[conversationID].allowlist[candidate] = true;

            emit ParticipantAdded(conversationID, sender, candidate);
        }
        else if (msgType == MessageType.RemoveParticipant) {
            // Remove from conversation allowed allowlist
            delete _conversations[conversationID].allowlist[candidate];

            emit ParticipantRemoved(conversationID, sender, candidate);
        }
        else if (msgType == MessageType.GeneralMessage) {
            // No logic for general messages beyond being stored in _handle()'s logic
            emit GeneralMessage(conversationID, sender, abi.encode(_message));
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
        bytes32[] memory _participants,
        bytes memory _seed,
        bytes memory _name
    ) public returns (bytes32 conversationID) {
        // Calculate conversationID
        // Extremely packed to prevent any chance of MEV abuse or collision
        conversationID = bytes32(keccak256(abi.encodePacked(
            msg.sender,
            address(this),
            HYPERLANE_DOMAIN_IDENTIFIER,
            blockhash(1),
            block.number,
            block.difficulty,
            block.timestamp,
            block.chainid,
            block.coinbase,
            conversationCount,
            _seed,
            _name
        )));

        if (_conversations[conversationID].conversationID == conversationID) {
            revert InvalidConversation();
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        // Count all participants that aren't the sender
        uint participantCount;
        for (uint i; i < _participants.length;) {
            if (_participants[i] != admin) {
                participantCount += 1;
            }
            // Shouldn't overflow
            unchecked { ++i; }
        }
        // Increment once for admin
        participantCount += 1;

        // Count all domainIDs that aren't the current one
        uint domainCount;
        for (uint i; i < _domainIDs.length;) {
            if (_domainIDs[i] != HYPERLANE_DOMAIN_IDENTIFIER) {
                domainCount += 1;
            }
            // Shouldn't overflow
            unchecked { ++i; }
        }
        // Increment once for current domainID
        domainCount += 1;

        // Prep InitiateConversation Message to duplicate action on other instances
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.participants = new bytes32[](participantCount);
        message.domainIDs = new uint32[](domainCount);
        
        
        // Initialize Conversation
        _conversations[conversationID].conversationID = message.conversationID = conversationID;
        conversationCount += 1;
        
        // Set initializer as conversation admin
        _conversations[conversationID].admins.push(admin); // Add to conversation admin array
        _conversations[conversationID].isAdmin[admin] = true; // Set admin status mapping
        _conversations[conversationID].adminApprovals[admin][admin] = true; // Set self-approval for admin status
        
        // Process current Hyperlane domainID
        _conversations[conversationID].domainIDs.push(HYPERLANE_DOMAIN_IDENTIFIER);
        message.domainIDs[0] = HYPERLANE_DOMAIN_IDENTIFIER;

        // Process user-supplied Hyperlane domainIDs
        uint offset;
        for (uint i = 1; i <= _domainIDs.length;) {
            // Skip the domainID for this chain if supplied as that was already added
            if (_domainIDs[i - 1] == HYPERLANE_DOMAIN_IDENTIFIER) {
                // Shouldn't overflow
                unchecked { ++i; ++offset; }
                continue;
            }
            // Save the domain data
            _conversations[conversationID].domainIDs.push(_domainIDs[i - 1]);
            message.domainIDs[i - offset] = _domainIDs[i - 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }

        // Process initializer address
        _conversations[conversationID].allowlist[admin] = true;
        message.participants[0] = admin;
        
        // Process participant addresses
        offset = 0;
        for (uint i = 1; i <= _participants.length;) {
            // Skip sender's address as that was already added
            if (_participants[i - 1] == admin) {
                unchecked { ++i; ++offset; }
                continue;
            }
            _conversations[conversationID].allowlist[_participants[i - 1]] = true;
            message.participants[i - offset] = _participants[i - 1];
            // Shouldn't overflow
            unchecked { ++i; }
        }
        
        // Set conversation name
        if (_name.length > 0) {
            _conversations[conversationID].name = message.message = bytes.concat("Hyperlane: ", admin, " initiated ", _name, "!");
        } else {
            _conversations[conversationID].name = message.message = bytes.concat("Hyperlane: ", admin, " initiated ", conversationID, "!");
        }

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
            _conversations[conversationID].allowlist[_message.participants[i]] = true;
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
        if (!_conversations[_conversationID].allowlist[_address]) {
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
        message.participants = new bytes32[](1);
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
        if (!_conversations[_conversationID].allowlist[_address]) {
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
        message.participants = new bytes32[](1);
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
        if (!_conversations[_conversationID].allowlist[_address]) {
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
        message.participants = new bytes32[](1);
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
        if (!_conversations[_conversationID].allowlist[_address]) {
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
            for (uint i; i < adminCount;) {
                if (_conversations[_conversationID].admins[i] == _address) {
                    _removeFromAdminArray(_conversationID, i);
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
        message.participants = new bytes32[](1);
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
        if (!_conversations[_conversationID].allowlist[_address]) {
            _conversations[_conversationID].allowlist[_address] = true;
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
        message.participants = new bytes32[](1);
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
        // Remove if present and non-admin, else revert
        if (!_conversations[_conversationID].allowlist[_address]) {
            revert InvalidParticipant();
        }
        else if (_conversations[_conversationID].isAdmin[_address]) {
            revert InvalidAdmin();
        }
        else {
            delete _conversations[_conversationID].allowlist[_address];
        }

        // Convert msg.sender address
        bytes32 admin = addressToBytes32(msg.sender);

        // Prepare RemoveParticipant Message
        Message memory message;
        message.timestamp = block.timestamp;
        message.sender = admin;
        message.conversationID = _conversationID;
        message.participants = new bytes32[](1);
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
        message.conversationID = _conversationID;
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
    function sendMessage(bytes32 _conversationID, bytes memory _message) internal onlyMember(_conversationID) {
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
            
            // Shouldn't overflow
            unchecked { ++i; }
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