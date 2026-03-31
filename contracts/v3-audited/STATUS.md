# ZykosTokenV3 — STATUS: READY FOR DEPLOY

## Files
- ZykosTokenV3.sol — Main contract (38KB, 1091 lines)
- ZykosTokenV3_FLAT.sol — Flattened version with OZ inlined (50KB, 1452 lines)

## Compilation
- Remix IDE: solc ^0.8.20
- Optimization: 200 runs
- Contract: ZykosTokenV3

## Audit Results (SolidityScan via Remix)
- Score: 61.50/100
- Critical: 1 (access control — needs review)
- High: 0
- Medium: 6 (precision loss, approve frontrunning, etc.)
- Low: 4
- Informational: 30+
- Gas: 20+

Full audit reports in docs/audits/

## What V3 has
- 18 decimals everywhere (FIXED from V1 bug)
- 100M supply: 85M sale + 15M bounties
- 100 pools (850K tokens each)
- Anti-whale: $50k max per purchase
- Cooldown: 36000s between purchases
- Treasury: 4-way split (50/25/12.5/12.5)
- Governance: VOTER ($20k) / PROTECTOR ($50k)
- Bounties: campaigns, batch distribution, claim
- Multi-payment: USDC, USDT
- OpenZeppelin: ERC20, Ownable2Step, ReentrancyGuard, Pausable

## What V3 is missing (can add later)
- Toast system (VIRGIN→BRONZE→CHARCOAL) — was in V1
- Exact cooldown tuning (currently 36000s, V1 had 8400s)
- Treasury 6-way split (currently 4-way, spec says 50/25/12.5/6.25/6.25)
- 20% post-deploy withdrawal for airdrops — partially covered by BOUNTIES_ALLOCATION

## Deployed contract (V1, PAUSED)
- BSC Mainnet: 0xB4D46f6C550AA855307085b8970D971Cdeafb030
