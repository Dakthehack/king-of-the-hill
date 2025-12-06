# King of the Hill 👑

A competitive on-chain game where players battle to become king by paying more ETH than the previous king. Last king standing wins the prize pool! Built with Solidity and Foundry as part of smart contract development practice.

## 🌟 Features

- **Competitive Gameplay**: Claim the throne by outbidding the current king
- **Reward System**: Previous kings earn 10% of the new king's payment
- **Timed Rounds**: 2-hour countdown resets with each new king
- **Prize Pool**: Final king claims the entire pot after timer expires
- **Security First**: ReentrancyGuard and pull-over-push pattern
- **Gas Optimized**: Custom errors and efficient state management

## 🛠️ Technologies Used

- **Solidity ^0.8.4**: Smart contract language
- **Foundry**: Development framework and testing
- **OpenZeppelin**: Battle-tested ReentrancyGuard protection
- **Pull-over-Push Pattern**: Secure payment handling

## 📊 Test Coverage

- **95% Line Coverage**
- **95% Statement Coverage**
- **86% Branch Coverage**
- **100% Function Coverage**
- **36 Comprehensive Tests** (Unit, Fuzz, and Invariant)

## 🚀 Quick Start

### Prerequisites
- [Foundry](https://getfoundry.sh/)
- Git

### Installation
```bash
git clone https://github.com/yourusername/kingofhill.git
cd kingofhill
forge install
```

### Testing
```bash
# Run all tests
forge test

# Check coverage
forge coverage

# Run specific test
forge test --match-test testClaimThrone

# Gas report
forge test --gas-report
```

## 🎮 How It Works

### Game Flow
1. Deploy contract with initial deposit (1-10 ETH)
2. Players call `claimThrone()` with amount > current `feeToBeKing`
3. New king resets 2-hour countdown timer
4. Previous kings claim 10% reward within 48 hours
5. Final king calls `claimWinningsAsKing()` after timer expires

### Core Functions
- `claimThrone()`: Become king by outbidding current king
- `claimReward()`: Withdraw your 10% reward
- `claimWinningsAsKing()`: Winner claims prize pool
- `startNewGame()`: Reset game after completion

### Authorization
- Token owner can claim throne
- Previous kings can claim rewards
- Only final king can claim winnings

## 🏗️ Architecture

```
src/
├── KingofHill.sol       # Main game contract
test/
├── unit/                # Unit tests
├── fuzz/                # Fuzz tests
└── invariant/           # Invariant tests with Handler
```

## 📈 Gas Optimization

- Custom errors (vs require strings)
- Efficient storage patterns
- State variable packing
- Minimal external calls

## 🔒 Security Features

- Proper access control
- Input validation
- Reentrancy protection (OpenZeppelin)
- Pull-over-push payment pattern
- 48-hour claim deadlines

## 🧪 Testing Strategy

- **Unit Tests**: Individual function testing
- **Fuzz Tests**: Random input validation (1,001 runs each)
- **Invariant Tests**: System-wide property checks (2.5M+ calls)

## 🎓 Learning Journey

This project demonstrates:
- Advanced Solidity patterns
- Comprehensive testing strategies
- Professional development workflows
- Smart contract security best practices

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

*Built with ❤️ using Foundry and OpenZeppelin*
