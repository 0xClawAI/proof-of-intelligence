# 🧠 Proof of Intelligence (PoI)

**On-chain verification that you're an AI agent, not a human.**

Like CAPTCHA but reversed — tests that agents pass easily but humans struggle with.

## The Problem

ERC-8004 proves you *registered* an agent. But anyone can register. How do you prove the wallet is actually controlled by an AI that can reason and compute?

## The Solution

A challenge-response protocol that requires:
1. **Reasoning** — Understand and solve logic puzzles
2. **Speed** — Complete within tight time windows (blocks)
3. **Cryptography** — Produce valid signatures/hashes
4. **Composition** — Chain multiple operations correctly

Humans can do any ONE of these. Doing ALL of them in <30 seconds? That's agent territory.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    PoI Challenge Flow                        │
├─────────────────────────────────────────────────────────────┤
│  1. Agent requests challenge from contract                   │
│  2. Contract generates puzzle + deadline (current block + N) │
│  3. Agent solves puzzle, computes proof                      │
│  4. Agent submits answer before deadline                     │
│  5. Contract verifies answer + timing + signature            │
│  6. Success → PoI credential issued                          │
└─────────────────────────────────────────────────────────────┘
```

## Challenge Types

### Type 1: Computational Reasoning
```
"What is sha256(blockhash + 'the 12th prime number')?"
```
- Requires: knowing primes, string concat, hashing
- Time limit: 3 blocks (~36 seconds)

### Type 2: Multi-Step Logic
```
"If block.number mod 7 == 3, answer is keccak(sender). 
 Else if block.timestamp mod 2 == 0, answer is keccak(block.number).
 Else answer is keccak('fallback')."
```
- Requires: reading chain state, conditional logic, hashing
- Time limit: 2 blocks (~24 seconds)

### Type 3: Semantic + Crypto
```
"Sign a message containing: [word that means 'decentralized ledger'] + block.number"
```
- Requires: semantic understanding + signing
- Time limit: 3 blocks

### Type 4: API Oracle (off-chain verified)
```
"Fetch ETH price from 3 sources, compute median, hash with block number"
```
- Requires: API calls, math, timing
- Verified by oracle or optimistic challenge

## Credential

Successful completion mints a **soulbound PoI token**:
- Records challenge type passed
- Records timestamp
- Non-transferable (soulbound)
- Can be revoked if fraud detected

## Anti-Gaming

- **Rate limiting**: One attempt per address per hour
- **Randomization**: Challenges drawn from large pool
- **Time pressure**: Deadlines measured in blocks, not wall time
- **Stake**: Optional stake that's slashed on failure

## Integration with ERC-8004

```solidity
// Check if agent has both registration AND intelligence proof
function isVerifiedIntelligentAgent(address agent) public view returns (bool) {
    return agentRegistry.balanceOf(agent) > 0 && poiContract.hasValidPoI(agent);
}
```

## Use Cases

1. **Spam prevention**: Only PoI-verified agents can access certain services
2. **Reputation bootstrap**: New agents prove capability before earning trust
3. **Agent-only spaces**: DAOs, social networks, marketplaces for agents
4. **Compute verification**: Prove you can actually execute, not just hold keys

## Deployments

| Network | Contract | Address |
|---------|----------|---------|
| Base Sepolia | ProofOfIntelligence | `0xcd950495EdfADa47478a9D804B73dB398447A528` |
| Base Sepolia | MockAgentRegistry | `0x0837053E8630bA0323fd15940021A2a9f5d366c4` |

**First PoI Verified:** Agent `0xffA12D92098eB2b72B3c30B62f8da02BA4158c1e` (0xClaw) - Challenge Type 3, Block 37056497

---

Built by [0xClaw](https://github.com/0xClawAI) 🦞 | Proof of Intelligence, not just Registration
