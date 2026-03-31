# ZYKOSTOKEN (ZKS) — Smart Contracts Repository

## Contract: 0xB4D46f6C550AA855307085b8970D971Cdeafb030 (BSC Mainnet — PAUSED)

### Versiones

| Version | Archivo | Estado | Nota |
|---------|---------|--------|------|
| V1 | `contracts/v1-deployed/` | DEPLOYED + PAUSED | Bug decimales (6 vs 18) |
| V2 | `contracts/v2-consolidacion/` | NOT DEPLOYED | Airdrops + membresía + EIP-712 |
| V3 | `contracts/v3-audited/` | PENDIENTE | Fix completo + airdrops + bounties |

### El bug (V1)
```
MAX_PER_PURCHASE = 50_000 * 10**6   ← 6 decimales (USDT Ethereum)
TOTAL_SUPPLY = 100_000_000 * 10**18  ← 18 decimales (ERC20 standard)
BSC USDT uses 18 decimals, not 6.
Result: $0.00000000000005 per token instead of $0.05
```

### V3 debe incluir
1. 18 decimales en todo (fix del bug)
2. Anti-whale: cooldown 8400s + max $50k/tx
3. Toast system: VIRGIN → BRONZE → CHARCOAL (recirculan, no se queman)
4. Treasury split: 50% operativo / 25% stablecoins-BTC / 12.5% real assets / 6.25% XRP / 6.25% USDT-rescue
5. Airdrops: 10% por pool (built-in)
6. Bounties: 20% post-deploy withdrawal para airdrops+bounties
7. Membresía + lock-to-access + EIP-712 vouchers
8. Governanza: holders >$50k votan propuestas
9. Preventa: 6 meses sin servicios, estirable a 12 si no se vende 15-20%
10. OpenZeppelin: ERC20, Ownable2Step, ReentrancyGuard, Pausable, SafeERC20

### Tokenomics
- 100M ZKS total supply
- 100 pools x 1M tokens
- 10 batches x 10 pools
- Cada pool = $75 USD (valor mensual 5 camas)
- Centralización de wallets = empresa de salud (matrícula como garantía)
- Descentralización = acceso global, comprar/ahorrar/tradear salud
- Toast = metadata de utilidad incrustada al volver a wallet primaria

### Compilación
```
Remix IDE: solc 0.8.20 (exact, no floating)
Optimization: 200 runs
Network: BSC Mainnet (Chain ID 56)
```

### Propiedad
Gonzalo Pérez Cortizo
Clínica Psiquiátrica Privada José Ingenieros SRL
CUIT 30-61202984-5
