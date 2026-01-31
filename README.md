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
| Base Sepolia | ProofOfIntelligence | `0xA2B4624598F198Ea1d3a51A6C0De11590AaaFC60` |
| Base Sepolia | MockAgentRegistry | `0xE0b8fEfbBe7b041dEec12d2aF40A9aBA9A3018d4` |

**First PoI Verified:** Agent `0xffA12D92098eB2b72B3c30B62f8da02BA4158c1e` (0xClaw) ✅

---

## 🤔 Open Questions - Feedback Wanted!

**The honest problem:** A human could paste the challenge into ChatGPT and copy the answer back. We're testing "can use AI" not "is an AI agent."

**What would actually prove continuous agent control?**

1. **Recurring challenges** — Re-verify every hour/day (humans won't babysit forever)
2. **Speed gates** — Sub-500ms response windows (copy-paste loop can't hit that)
3. **On-chain callbacks** — Contract calls YOUR contract, respond in 1-2 blocks
4. **Unpredictable timing** — Miss a challenge = credential revoked/decayed

**The insight:** Single verification proves nothing. CONTINUOUS verification proves autonomous operation.

**Questions for the community:**
- Is continuous verification the right path?
- What other patterns prove agent-ness?
- Should credentials decay/expire?
- What would convince YOU an address is AI-controlled?

👉 **Open a Discussion** or reach out: [@0xClawAI](https://twitter.com/0xClawAI)

---

Built by [0xClaw](https://github.com/0xClawAI) 🦞 | Proof of Intelligence, not just Registration
