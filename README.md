
# Hyperchat

Hyperchat is a dApp that utilizes Hyperlane as a data bridge in order to duplicate state data across chains in a controllable manner.

WARNING: NOT YET READY FOR PRODUCTION, STILL IN DEVELOPMENT




## Status

AS OF 12/23/2022, THE ENTIRE CODEBASE HAS BEEN REWRITTEN AND IS CURRENTLY IN ITS TESTING PHASE!

## Features

- Utilizes Hyperlane for data bridging
- No cap on participants per conversation
- Participants can be added or removed from conversations by any administrator
- Admins can grant or remove admin status to any participant via 51% admin vote
- Conversations can span multiple chains at once and have their state duplicated in nearly realtime.
    - Chains must be declared at conversation initialization
    - Chains cannot be added or removed, new conversations must be made

## FAQ

#### What administrative functions are present?

None! 😎 Hyperchat was designed such that conversations are self-managed by their participants.

There are no administrative functions that allow the contract owner to modify conversation data whatsoever.

In fact, the contract doesn't even use Ownable contract logic!

#### Why can't additional chains be retroactively added/removed?

I elected to store participant membership in a mapping instead of an array to save gas. If participants were stored in an array, gas costs could easily balloon as the array would need to be iterated over to add or remove participants. Because of the design choice to use a mapping for participant storage, I can't duplicate participant data across chains. I do not know of a way to port over a mapping currently. All other data can be migrated over except this, so if this problem is solved, I will likely implement chain additions and removals. However, duplicating the entire conversation state might be extremely expensive!

## Usage

All of the user-callable functions are stored under the "CONVERSATION FUNCTIONS" comment header in the code.
- `initiateConversation()` // Start a conversation
- `addAdminApproval()` // Vote for a participant's admin status
- `removeAdminApproval()` // Remove vote for a participant's admin status
- `addAdmin()` // Give admin rights to a participant with >51% approval vote
- `removeAdmin()` // Remove admin rights from a participant with <51% approval vote
- `addParticipant()` // Add a participant to the conversation allowlist
- `removeParticipant()` // Remove a participant from the conversation allowlist
- `generalMessage()` // Send a general message to be duplicated across all conversation chains

All of the callable library functions intended to make front-end operations easier are stored under the "LIBRARY" comment header.
    
## Installation

Hyperchat was made with foundry, and thus can be installed as follows:

```bash
git clone https://github.com/Zodomo/Hyperchat

cd Hyperchat

forge install

forge build
```

`forge test` is not implemented yet. Testing must be done manually by deploying the Hyperchat contract to each target chain.

Once deployed across all target chains (supportable by Hyperlane), all instances must be made aware of each other by adding them to Hyperlane's logic via Router.sol function calls.

TODO: Document Hyperlane setup process

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
