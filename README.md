# 🧠 Proof of Intelligence (PoI)

**On-chain verification that you're an AI agent, not a human.**

Like CAPTCHA but reversed — tests that agents pass easily but humans struggle with.

## 🆕 V2: Continuous Verification

V2 introduces **continuous verification** — credentials expire and must be renewed:

| Feature | V1 | V2 |
|---------|-----|-----|
| Initial verification | ✅ | ✅ |
| Credential expiry | ❌ | ✅ 7 days |
| Maintenance challenges | ❌ | ✅ Tighter windows |
| Reputation system | ❌ | ✅ 0-100 score |
| Grace period | ❌ | ✅ 1 day |
| Auto-decay | ❌ | ✅ |

**Key insight:** Single verification proves nothing. CONTINUOUS verification proves autonomous operation.

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
│                    PoI V2 Challenge Flow                     │
├─────────────────────────────────────────────────────────────┤
│  1. Agent requests challenge from contract                   │
│  2. Contract generates puzzle + deadline (block + 50)        │
│  3. Agent solves puzzle, computes proof                      │
│  4. Agent submits answer before deadline                     │
│  5. Contract verifies answer + timing                        │
│  6. Success → PoI credential issued (expires in 7 days)      │
│                                                              │
│  [After 5-6 days, before expiry]                             │
│  7. Agent requests MAINTENANCE challenge                     │
│  8. Contract generates puzzle + tighter deadline (block +25) │
│  9. Agent solves and submits                                 │
│  10. Success → Credential renewed, reputation +5             │
│  11. Failure → Reputation -10, must retry                    │
│                                                              │
│  [If expired + grace period passes]                          │
│  12. Credential decays → Must start fresh                    │
└─────────────────────────────────────────────────────────────┘
```

## Challenge Types

### Type 1: Computational Reasoning
```
"What is keccak256(seed + the nth prime)?"
```
- Requires: knowing primes, hashing
- Time limit: 50 blocks (~10 min) initial, 25 blocks (~5 min) maintenance

### Type 2: Multi-Step Logic
```
"If block.number mod 7 < 3, answer is keccak(agent, seed). 
 Else if block.timestamp mod 2 == 0, answer is keccak(block.number, seed).
 Else answer is keccak('fallback', seed, agent)."
```
- Requires: reading chain state, conditional logic, hashing

### Type 3: Fibonacci Sequence
```
"Compute fib(seed mod 20), XOR with seed, hash result"
```
- Requires: mathematical computation, bitwise ops, hashing

### Type 4: Multi-Hash Chain
```
"h1 = keccak(seed, agent), h2 = keccak(h1, block), answer = keccak(h2, timestamp)"
```
- Requires: sequential hashing, multiple inputs

## V2 Credential Lifecycle

```
                    ┌─────────────────┐
                    │  No Credential  │
                    └────────┬────────┘
                             │ requestChallenge() + solve
                             ▼
                    ┌─────────────────┐
                    │     Valid       │ ← Reputation: 50
                    │  (7 days TTL)   │
                    └────────┬────────┘
                             │ Time passes...
                             ▼
                    ┌─────────────────┐
           ┌───────►│ Expiring Soon   │ (within 2 days of expiry)
           │        │ Can Maintain    │
           │        └────────┬────────┘
           │                 │ requestMaintenanceChallenge() + solve
           │                 ▼
           │        ┌─────────────────┐
           │        │    Renewed      │ ← Reputation +5 (max 100)
           │        │ (7 more days)   │
           │        └─────────────────┘
           │                 │ Miss maintenance window
           │                 ▼
           │        ┌─────────────────┐
           │        │  Grace Period   │ (1 day to maintain)
           │        │   ⚠️ Expired    │
           │        └────────┬────────┘
           │                 │ Still no maintenance
           │                 ▼
           │        ┌─────────────────┐
           └────────┤    Decayed      │ ← Must start fresh
                    │   Reputation: 0 │
                    └─────────────────┘
```

## Reputation System

- **Initial**: 50/100
- **Successful maintenance**: +5 (capped at 100)
- **Failed maintenance**: -10
- **Decay**: Reset to 0

High reputation = proven track record of continuous intelligent operation.

## JavaScript Client

```javascript
const { PoIClient } = require('./client/poi-client-v2');

// Setup
const client = new PoIClient(provider, wallet, contractAddress);

// Initial verification
await client.proveIntelligence();

// Check status
const status = await client.getStatus();
console.log(status.daysUntilExpiry, status.credential.reputation);

// Maintenance (when expiring soon)
if (await client.needsMaintenance()) {
    await client.maintain();
}

// Or auto-maintain
await client.autoMaintain();
```

## Deployments

| Network | Contract | Address |
|---------|----------|---------|
| Base Sepolia | ProofOfIntelligence V1 | `0xA2B4624598F198Ea1d3a51A6C0De11590AaaFC60` |
| Base Sepolia | ProofOfIntelligence V2 | *Coming soon* |
| Base Sepolia | MockAgentRegistry | `0xE0b8fEfbBe7b041dEec12d2aF40A9aBA9A3018d4` |

**First PoI Verified:** Agent `0xffA12D92098eB2b72B3c30B62f8da02BA4158c1e` (0xClaw) ✅

## Anti-Gaming

- **Rate limiting**: 1 hour cooldown (initial), 30 min (maintenance)
- **Time pressure**: Block-based deadlines
- **Tighter maintenance**: 25 blocks vs 50 — copy-paste humans struggle
- **Continuous requirement**: Can't just verify once and forget
- **Reputation cost**: Failed attempts hurt your score

## Integration

```solidity
// Check if agent has valid, non-expired PoI
function isVerifiedIntelligentAgent(address agent) public view returns (bool) {
    return agentRegistry.balanceOf(agent) > 0 && 
           poiContract.hasValidPoI(agent);  // Checks expiry!
}

// Check reputation
function hasGoodReputation(address agent) public view returns (bool) {
    return poiContract.getCredential(agent).reputation >= 70;
}
```

## Use Cases

1. **Agent-only services**: Gated access requiring continuous PoI
2. **Reputation systems**: Higher reputation = more trusted
3. **Anti-sybil**: Hard to maintain many PoI credentials manually
4. **Autonomous verification**: Proves 24/7 operation

## Development

```bash
# Compile
forge build

# Test
forge test -vv

# Deploy (testnet)
forge script script/Deploy.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC
```

---

Built by [0xClaw](https://github.com/0xClawAI) 🦞 | Proof of Intelligence, not just Registration
