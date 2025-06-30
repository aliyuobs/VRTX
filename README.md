## VRTX 🏦

A decentralized asset management and yield optimization platform built on the Stacks blockchain. StackVault enables users to create and manage investment vaults with automated yield strategies while maintaining full custody of their assets.

## Overview

VRTX revolutionizes DeFi asset management by providing a trustless platform where users can:
- Create custom investment vaults with different strategies
- Deposit STX tokens to earn yield through automated strategies
- Benefit from professional-grade risk management
- Maintain complete transparency through on-chain operations

## Features

- **Vault Creation**: Deploy custom vaults with configurable strategies and lock periods
- **Multi-Strategy Support**: Choose from various yield optimization strategies
- **Automated Yield Generation**: Set-and-forget yield farming with compound returns
- **Risk Management**: Built-in risk levels and performance tracking
- **Flexible Withdrawals**: Withdraw funds after lock periods with fair share calculation
- **Protocol Fees**: Transparent 2.5% fee structure supporting platform development
- **Emergency Controls**: Pause mechanisms for security and maintenance

## Smart Contract Architecture

### Core Components

#### Vaults
Each vault represents an investment pool with:
- Unique strategy assignment
- Configurable lock periods
- Share-based accounting system
- Performance tracking
- Owner management controls

#### Strategies
Investment strategies define:
- Expected APY estimates
- Risk levels (1-5 scale)
- Strategy descriptions
- Active/inactive status

#### User Positions
Track individual user investments:
- Share ownership
- Deposit amounts and timing
- Rewards claimed
- Lock period compliance

## Public Functions

### Vault Management

#### `create-vault`
```clarity
(create-vault strategy lock-period)
```
Creates a new investment vault with specified strategy and lock period.

**Parameters:**
- `strategy`: Strategy name (string-ascii 20)
- `lock-period`: Minimum lock period in blocks

**Returns:** Vault ID on success

#### `deposit`
```clarity
(deposit vault-id amount)
```
Deposits STX tokens into a vault and receives proportional shares.

**Parameters:**
- `vault-id`: Target vault identifier
- `amount`: STX amount to deposit (minimum 1 STX)

**Returns:** Number of shares minted

#### `withdraw`
```clarity
(withdraw vault-id shares)
```
Withdraws funds by burning shares after lock period.

**Parameters:**
- `vault-id`: Source vault identifier
- `shares`: Number of shares to redeem

**Returns:** STX amount withdrawn (after fees)

### Strategy Management

#### `add-strategy`
```clarity
(add-strategy name apy-estimate risk-level description)
```
Adds a new investment strategy (admin only).

**Parameters:**
- `name`: Strategy identifier
- `apy-estimate`: Expected APY in basis points
- `risk-level`: Risk rating (1-5)
- `description`: Strategy description

#### `harvest-vault`
```clarity
(harvest-vault vault-id yield-amount)
```
Executes yield harvesting for a vault (owner/admin only).

**Parameters:**
- `vault-id`: Target vault
- `yield-amount`: Yield generated

### Administrative Functions

#### `toggle-vault-pause`
Pauses/unpauses a specific vault (owner/admin only).

#### `toggle-protocol-pause`
Pauses/unpauses the entire protocol (admin only).

#### `update-treasury`
Updates the protocol treasury address (admin only).

## Read-Only Functions

### Information Queries

#### `get-vault-info`
Returns complete vault information including strategy, deposits, and status.

#### `get-user-position`
Returns user's position in a specific vault.

#### `get-strategy-info`
Returns strategy details including APY and risk level.

#### `get-position-value`
Calculates current value of user's vault position.

#### `get-protocol-stats`
Returns protocol-wide statistics including total TVL.

#### `can-withdraw`
Checks if user can withdraw from vault (lock period validation).

## Yield Calculation

StackVault uses a share-based system for fair yield distribution:

### Share Minting
```
New Shares = (Deposit Amount × Total Shares) ÷ Total Deposited
```
First depositor receives 1:1 shares to deposit ratio.

### Withdrawal Calculation
```
Withdrawal Amount = (User Shares × Total Deposited) ÷ Total Shares
```

### Fee Structure
- **Protocol Fee**: 2.5% on withdrawals
- **No Deposit Fees**: Maximize capital efficiency
- **Performance-Based**: Fees only on successful yield generation

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v1.5.0+
- [Stacks CLI](https://docs.stacks.co/build/cli) v2.0+
- Node.js 16+ (for frontend integration)
- STX testnet tokens for testing

### Local Development

1. **Clone and Setup**
```bash
git clone https://github.com/aliyuobs/stackvault.git
cd stackvault
clarinet new stackvault-protocol
```

2. **Install Contract**
```bash
# Copy contract to contracts/stackvault.clar
cp stackvault.clar contracts/
```

3. **Configure Clarinet**
```toml
# Clarinet.toml
[contracts.stackvault]
path = "contracts/stackvault.clar"
```

4. **Run Tests**
```bash
clarinet test
```

5. **Start Local Network**
```bash
clarinet integrate
```

### Deployment

#### Testnet Deployment
```bash
stx deploy_contract stackvault contracts/stackvault.clar \
  --testnet \
  --broadcast
```

#### Mainnet Deployment
```bash
stx deploy_contract stackvault contracts/stackvault.clar \
  --mainnet \
  --broadcast
```

## Usage Examples

### JavaScript Integration

#### Create a Vault
```javascript
import { contractCall, uintCV, stringAsciiCV } from '@stacks/transactions';

const createVaultTx = await contractCall({
  contractAddress: 'SP1...',
  contractName: 'stackvault',
  functionName: 'create-vault',
  functionArgs: [
    stringAsciiCV('conservative'),  // strategy
    uintCV(144)                     // ~24 hour lock period
  ],
  senderKey: privateKey,
  network: stacksNetwork
});
```

#### Deposit to Vault
```javascript
const depositTx = await contractCall({
  contractAddress: 'SP1...',
  contractName: 'stackvault',
  functionName: 'deposit',
  functionArgs: [
    uintCV(1),           // vault-id
    uintCV(5000000)      // 5 STX in microSTX
  ],
  postConditions: [
    makeStandardSTXPostCondition(
      senderAddress,
      FungibleConditionCode.Equal,
      5000000
    )
  ],
  senderKey: privateKey
});
```

#### Check Position Value
```javascript
const positionValue = await callReadOnlyFunction({
  contractAddress: 'SP1...',
  contractName: 'stackvault',
  functionName: 'get-position-value',
  functionArgs: [
    principalCV(userAddress),
    uintCV(1)
  ],
  senderAddress: userAddress
});
```

### Strategy Examples

#### Conservative Strategy
- **APY Estimate**: 8-12%
- **Risk Level**: 2/5
- **Focus**: Stable yield through liquid staking

#### Aggressive Strategy
- **APY Estimate**: 15-25%
- **Risk Level**: 4/5
- **Focus**: DeFi yield farming with higher volatility

#### Balanced Strategy
- **APY Estimate**: 10-18%
- **Risk Level**: 3/5
- **Focus**: Diversified approach balancing risk and reward

## Security Features

### Smart Contract Security
- **Reentrancy Protection**: State updates before external calls
- **Input Validation**: Comprehensive parameter checking
- **Access Controls**: Role-based function restrictions
- **Emergency Pausing**: Circuit breakers for security incidents

### Economic Security
- **Minimum Deposits**: Prevents dust attacks
- **Lock Periods**: Reduces flash loan risks
- **Fee Mechanisms**: Sustainable tokenomics
- **Slippage Protection**: Fair share calculations

## Integration Opportunities

### DeFi Protocols
- **Lending Platforms**: Collateral management
- **DEX Integration**: Automated market making
- **Liquid Staking**: STX staking optimization
- **Cross-Chain**: Bridge asset management

### Applications
- **Portfolio Trackers**: Vault performance monitoring
- **Mobile Apps**: User-friendly vault management
- **Dashboard**: Protocol analytics and insights
- **Robo-Advisors**: Automated strategy recommendations

## Roadmap

### Phase 1: Core Platform ✅
- [x] Basic vault creation and management
- [x] Share-based accounting system
- [x] Multiple strategy support
- [x] Emergency controls

### Phase 2: Advanced Features 🚧
- [ ] Automated strategy execution
- [ ] Cross-vault yield optimization
- [ ] Advanced risk metrics
- [ ] Governance token integration

### Phase 3: Ecosystem Growth 📋
- [ ] Third-party strategy marketplace
- [ ] Multi-asset support beyond STX
- [ ] Cross-chain vault management
- [ ] Institutional features

## Contributing

We welcome contributions! Please follow these steps:

1. **Fork the Repository**
```bash
git fork https://github.com/stackvault/protocol.git
```

2. **Create Feature Branch**
```bash
git checkout -b feature/awesome-feature
```

3. **Make Changes**
- Write comprehensive tests
- Update documentation
- Follow Clarity best practices

4. **Submit Pull Request**
- Include detailed description
- Reference related issues
- Ensure CI passes

### Development Guidelines

- **Code Style**: Follow Clarity conventions
- **Testing**: Minimum 90% test coverage
- **Documentation**: Update README for new features
- **Security**: Consider economic implications


## Disclaimer

StackVault is experimental DeFi software. Users should understand the risks:
- Smart contract risks
- Market volatility
- Liquidation risks
- Regulatory uncertainties

Please conduct thorough research and consider consulting financial advisors before investing.
