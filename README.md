
# Hyperchat

Hyperchat is a dApp that utilizes Hyperlane as a data bridge in order to duplicate state data across chains in a controllable/permissable manner.

WARNING: NOT YET READY FOR PRODUCTION, STILL IN DEVELOPMENT




## Changelog

2023-01-09 v0.1 [IT WORKS!](https://explorer-v2.hyperlane.xyz/message/a1f97fd3352fdd3f8fe020073e82c9f6deb9ce95b8a4ae4b43f65355a60c2416)

Test coverage is really good too! Hyperlane gas payments are not currently enabled as I couldn't get them to work. All of the code is still in place, and is simply commented out. Feel free to test and use it!

## Features

- Utilizes Hyperlane for data bridging
- No cap on participants per conversation
- Participants can be added or removed from conversations by any administrator
- Admins can add or remove admin status to/from any participant via 50% admin approval vote
    - If an admin loses 50% approval quorum, any admin can remove their admin privileges
- Conversations can span multiple chains at once and have their state duplicated within minutes.
    - Chains must be declared at conversation initialization
    - Chains cannot be added or removed, new conversations must be made

## FAQ

#### What administrative functions are present?

Hyperchat itself doesn't have any administrative functions! The contract deployer/owner cannot do anything to modify any conversation data at all. Only conversation admins have control over conversations themselves.

The only "administrative"-leaning functions are the Hyperlane management functions `enrollRemoteRouter()`, `enrollRemoteRouters()`, `setInterchainGasPaymaster()`, `setInterchainSecurityModule()`, and `setMailbox()`. These are necessary to connect Hyperchat instances together, and to adjust the addresses used with the Hyperlane infrastructure.

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

Once deployed across all target chains (supportable by Hyperlane), instances must be managed and made aware of each other via either of Hyperlane's Router.sol `enrollRemoteRouter()` or `enrollRemoteRouters()` functions.

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
