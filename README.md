
# Hyperchat

A simple application using Hyperlane to allow users to send each other messages across chains.

WARNING: NOT YET READY FOR PRODUCTION, STILL IN DEVELOPMENT




## Features

- Utilizes Hyperlane for data bridging
- No cap on participants per conversation
- Participants can only be added to conversations when they're created
- Conversations are unique between chain pairs
    - A conversation between two senders between Arbitrum <-> Optimism will be a different conversation than between Arbitrum <-> Ethereum and even between Arbitrum <-> Arbitrum
- Message validity is confirmed and is not spoofable
    - tx.origin is not used anywhere

## FAQ

#### What administrative functions are present?

The admin can perform the following actions:

```solidity
    function addInstance_(uint32 _domain, bytes32 _instance) public onlyOwner {
        _hyperchatInstance[_domain] = _instance;
    }
```

#### What is the reasoning behind these administrative functions?

`addInstance_(uint32 _domain, bytes32 _instance)`
- This allows the contract owner to add support for additional chains.
- This is done by altering `_hyperchatInstance`, which acts as a chain allowlist.
    - Hyperlane Chain Domain ID (`_domain`) => Hyperchat Instance Address (`_instance`)

## Usage

```solidity
function sendMessage(
    uint256 _conversationID,
    uint32 _hyperlaneDomain,
    bytes memory _message
) public requireDeployed(_hyperlaneDomain) requireValid(_conversationID) { ... }
```

- Send Message
    - `_conversationID` corresponds to the conversation the message is intended for
        - NOTE: This will fail if you're not part of the conversation!
    - `_hyperlaneDomain` corresponds to the Hyperlane chain domain ID
        - This is ideally abstracted away by the frontend
    - `_message` is the message being sent
        - An overload of this function is available that accepts string input for the message instead of bytes
    - `requireDeployed(_hyperlaneDomain)` validates that Hyperchat has been deployed on the target chain
    - `requireValid(_conversationID)` validates that the conversation exists and that the sender is a participant
    
## Installation

Hyperchat was made with foundry, and thus can be installed as follows:

```bash
git clone https://github.com/Zodomo/Hyperchat

cd Hyperchat

forge install

forge build
```

`forge test` is not implemented yet. Testing must be done manually by deploying the Hyperchat contract to each target chain and then each instance allowlisted by calling `addInstance_()` with the details of every other chain on each instance.

## Authors

- Zodomo
    - [Twitter (@0xZodomo)](https://www.github.com/0xZodomo)
    - Ethereum (Zodomo.eth)

## Acknowledgements

 - Hyperlane
    - [Twitter (@Hyperlane_xyz)](https://twitter.com/Hyperlane_xyz)
    - [Github](https://github.com/hyperlane-xyz)
    - [Official Website](https://www.hyperlane.xyz/)
    - [Discord](https://discord.gg/hyperlane)
