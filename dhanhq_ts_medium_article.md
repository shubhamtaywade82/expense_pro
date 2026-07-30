# Introducing DhanHQ TS: A Production-Grade TypeScript SDK for DhanHQ API v2

**A batteries-included TypeScript trading SDK with binary WebSocket market data, option analytics, technical indicators, a pre-trade risk pipeline, and an MCP server for AI trading agents.**

---

If you trade on NSE or BSE through [Dhan](https://dhan.co) and you build your systems in TypeScript or Node.js, your options have historically been limited. 

Dhan publishes an excellent official Python SDK (`dhanhq`) and a lightweight JavaScript client (`dhanhq-ts`), but neither gives you what a production trading system *actually* needs out of the box:

- **End-to-end type safety** from API request to WebSocket tick
- **A binary WebSocket parser** that doesn’t make you reverse-engineer byte offsets
- **Option Greeks**, implied volatility, and max pain computed locally
- **Technical indicators** that don’t require a separate `ta-lib` dependency
- **Pre-trade risk checks** that encode actual NSE/BSE rules
- A way to expose your trading infrastructure to an **LLM agent safely**

Without these, you end up stitching together five different libraries, writing your own WebSocket parser, and hoping your risk checks don't have a gap at 3:29 PM on expiry day.

[**DhanHQ TS**](https://github.com/shubhamtaywade82/dhanhq-ts) is my attempt to close that gap. It's a single, strictly-typed, production-grade SDK that covers the full algorithmic trading lifecycle: authentication, order placement, real-time data, analytics, risk management, and AI agent integration.

```bash
npm install @shubhamtaywade82/dhanhq-ts
```

---

## 📦 What’s Inside?

The SDK is organized around a single `DhanClient` instance that exposes strongly-typed resource clients. Every method returns typed responses generated directly from DhanHQ's OpenAPI specification. 

No `any`. No guessing field names. Your IDE autocompletes the entire API surface.

```typescript
import { DhanClient } from "@shubhamtaywade82/dhanhq-ts";

const client = new DhanClient({
  token: process.env.DHAN_TOKEN!,
  clientId: process.env.DHAN_CLIENT_ID!,
});
```

From that one object, you get access to everything you need:
- `client.orders` — Place, modify, cancel, and track orders
- `client.portfolio` — Holdings, positions, DP holdings
- `client.funds` — Margin, limits, charges
- `client.marketData` — LTP, quotes, OHLC, option chain
- `client.charts` — Intraday and historical candles
- `client.ws` — WebSocket market feed + order updates
- `client.ws.depth` — 20-level market depth
- `client.globalStocks` — US equities (fractional shares, USD)
- `client.traderControls` — Kill switch, P&L auto-exit

---

## 🔐 Authentication: Five Methods, One Interface

Trading systems have different secret-management requirements. A weekend backtester wants a static token in `.env`. A production bot wants vault-backed rotation. An autonomous agent wants auto-generated tokens from a TOTP secret.

The SDK supports all these workflows natively:

```typescript
// 1. Static token
const client = new DhanClient({ token, clientId });

// 2. Provider callback (HashiCorp Vault, AWS Secrets Manager, etc.)
const client = new DhanClient({
  clientId,
  tokenProvider: () => vault.read("dhan/token"),
});

// 3. Auto token management (generates from PIN + TOTP)
const client = new DhanClient({ clientId });
client.auth.enableAutoTokenManagement({
  clientId,
  pin: "1234",
  totpSecret: "JBSWY3DPEHPK3PXP",
});
```

Two implementation details that matter in production:
1. **Concurrent callers share one login:** Parallel token generation can invalidate the previous session. The SDK serializes this internally.
2. **Offset-less expiry timestamps are read as IST:** Dhan returns expiry times without timezone offsets. On a UTC server, naive parsing introduces a 5.5-hour drift that can cause premature token refresh or expired-token errors mid-trade. The SDK handles this timezone math for you.

---

## ⚡ WebSocket: Binary Protocol, Parsed for You

This is where the SDK earns its "production-grade" label.

DhanHQ’s market feed uses a compact binary WebSocket protocol. While official clients give you raw buffers, DhanHQ TS gives you typed tick objects. The binary parser handles all the byte-level work: field extraction, endianness, and variable-length encoding. You never touch a `Buffer` directly.

```typescript
await client.ws.connect();

client.ws.market.subscribe([
  { exchangeSegment: "NSE_FNO", securityId: "44321" },
  { exchangeSegment: "NSE_EQ", securityId: "1333" },
]);

client.ws.market.on("tick", (tick) => {
  console.log(tick.ltp);               // Last traded price
  console.log(tick.volumeTradedToday); // Cumulative volume
  console.log(tick.openInterest);      // OI for F&O
});
```

The design principle is simple: **the WebSocket is the real-time truth source.** Use it for LTP, exit logic, and execution-time state. Use REST for placement, reconciliation, and history. The SDK makes both paths equally ergonomic.

---

## 📈 Technical Analysis: Zero External Dependencies

The SDK includes a pure-function technical analysis module. No `ta-lib` bindings. No Python subprocesses. No WASM compilation errors. Just TypeScript functions over number arrays.

```typescript
import { rsi, macd, bollingerBands, latest } from "@shubhamtaywade82/dhanhq-ts";

const closes = [/* your OHLC close array */];

const rsiValues = rsi(closes, 14);
const currentRsi = latest(rsiValues); // Returns the last non-null value

const { upper, middle, lower } = bollingerBands(closes, 20, 2);
```

### Multi-Timeframe Bias Engine
This is the feature I use most in my own systems. It computes indicators across multiple intervals and produces a blended directional bias. Higher timeframes are weighted more heavily—a 60-minute bullish signal outweighs a 5-minute bearish one.

```typescript
import { TechnicalAnalysis, analyzeMultiTimeframe } from "@shubhamtaywade82/dhanhq-ts";

const ta = new TechnicalAnalysis(client.charts);

const result = await ta.compute({
  securityId: "13",
  exchangeSegment: "IDX_I",
  instrument: "INDEX",
  intervals: [5, 15, 60], // 5m, 15m, 1h
});

console.log(analyzeMultiTimeframe(result).summary);
// { bias: "bullish", setup: "buy_on_dip", confidence: 0.81, ... }
```

---

## 🧮 Option Analytics: Greeks, IV, Max Pain

For options traders, the SDK computes everything locally from the option chain data. You can build an options dashboard, a volatility scanner, or a max-pain-based expiry strategy without leaving the TypeScript runtime.

```typescript
import { blackScholes, greeks, impliedVolatility } from "@shubhamtaywade82/dhanhq-ts";

// Get all Greeks
const g = greeks({
  spot: 24_000,
  strike: 24_200,
  timeToExpiry: 10 / 365,
  riskFreeRate: 0.065,
  volatility: 0.15,
  optionType: "call",
});
// Access g.delta, g.gamma, g.theta, g.vega, g.rho

// Back out IV from market price
const iv = impliedVolatility({
  marketPrice: 185.50,
  spot: 24_000,
  strike: 24_200,
  // ...
});
```

---

## 🛡️ Risk Pipeline: Pre-Trade Safety Rails

This is the part most SDKs skip entirely. DhanHQ TS includes a configurable pre-trade risk pipeline that runs *before* every order hits the exchange, encoding actual exchange rules (Market hours, ASM/GSM surveillance, Concentration, Daily Loss limits).

```typescript
import { Pipeline, riskProviderFor } from "@shubhamtaywade82/dhanhq-ts";

const pipeline = new Pipeline({
  provider: riskProviderFor(client),
  limits: {
    maxQuantity: 50,
    dailyMaxLoss: 25_000,
    maxConcentrationPct: 30,
  },
});

// Throws RiskViolationError on first failure
await pipeline.run({ args: order, instrument });
```

---

## 🤖 MCP Server: Your Trading SDK as AI Agent Tools

This is the feature that makes DhanHQ TS different from every other broker SDK available today.

The package ships a **[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** server that exposes the entire SDK as tools consumable by Claude, GPT, or any MCP-compatible LLM client.

```bash
DHAN_CLIENT_ID=... DHAN_ACCESS_TOKEN=... npx dhanhq-mcp
```

The security model has two independent gates:
1. **Scope gate** — The policy must hold the required scope (e.g., `orders:write`).
2. **Environment gate** — Both `DHANHQ_MCP_ENABLE_WRITES=true` AND `LIVE_TRADING=true` must be explicitly set.

An agent with `orders:write` scope still cannot place a trade unless you've explicitly opted into live trading. This means you can say to Claude:

> *"Check my NIFTY positions, compute the current P&L, and if I'm down more than ₹5,000, show me the order I'd need to place to flatten."*

The agent uses the SDK tools, hits the risk pipeline, and shows you the preview—but cannot execute without your explicit environment configuration.

---

## 🏗️ Getting Started

The SDK is dual ESM/CJS output (works with `import` and `require`), has rate limiting built-in via `bottleneck`, and relies on zero unnecessary runtime dependencies. 

```bash
npm install @shubhamtaywade82/dhanhq-ts
```

Check out the full documentation with guides for every module here: **[shubhamtaywade82.github.io/dhanhq-ts](https://shubhamtaywade82.github.io/dhanhq-ts/)**

### Links & Resources
- **GitHub:** [github.com/shubhamtaywade82/dhanhq-ts](https://github.com/shubhamtaywade82/dhanhq-ts)
- **npm:** [npmjs.com/package/@shubhamtaywade82/dhanhq-ts](https://www.npmjs.com/package/@shubhamtaywade82/dhanhq-ts)

If you build algo trading systems in TypeScript and use Dhan as your broker, I'd genuinely appreciate a star on the GitHub repo, an install from npm, or a question in the issues. The SDK improves fastest when real trading systems stress-test its edges!

---

*Shubham Taywade builds trading infrastructure in TypeScript and Ruby. He maintains the [DhanHQ TypeScript SDK](https://github.com/shubhamtaywade82/dhanhq-ts) and the [DhanHQ Ruby SDK](https://github.com/shubhamtaywade82/dhanhq-client).*
