
# Hyperchat

Hyperchat is a dApp that utilizes Hyperlane as a data bridge in order to duplicate state data across chains in a controllable/permissable manner.

WARNING: NOT YET READY FOR PRODUCTION, STILL IN DEVELOPMENT




## Status

AS OF 2022-12-23, THE ENTIRE CODEBASE HAS BEEN REWRITTEN AND IS CURRENTLY IN ITS TESTING PHASE!

AS OF 2023-01-07, HYPERLANE MOCKS HAVE BEEN IMPLEMENTED AND CROSS-CHAIN MESSAGING APPEARS TO WORK AS INTENDED, MORE TESTS ARE STILL REQUIRED, BUT THE PROJECT APPEARS TO BE USABLE

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

2023-01-07 NOTE: This could potentially be solved by an enumerable mapping, I might get around to it at some point. I don't like the idea of modifying the domainIDs array as all message data can't be duplicated without excessive gas fees, but the functionality could theoretically be implemented if someone really wants it.

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

forge test
```

`forge test` is now implemented! MockHyperlaneEnvironment allows for Hyperlane simulation

Once deployed across all target chains (supportable by Hyperlane), instances must be managed and made aware of each other via Hyperlane's Router.sol `enrollRemoteRouter()` function.

## Authors

- Zodomo
    - [Twitter (@0xZodomo)](https://www.github.com/0xZodomo)
    - [Email (zodomo@proton.me)](mailto:zodomo@proton.me)
    - Ethereum (Zodomo.eth)

## Acknowledgements

 - Hyperlane
    - [Twitter (@Hyperlane_xyz)](https://twitter.com/Hyperlane_xyz)
    - [Github](https://github.com/hyperlane-xyz)
    - [Official Website](https://www.hyperlane.xyz/)
    - [Discord](https://discord.gg/hyperlane)
