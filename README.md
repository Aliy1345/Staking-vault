// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ── Import OpenZeppelin security modules ──────────────────────────────
// These are battle-tested, audited libraries used by real DeFi protocols.
// You must install them first:
//   npm install @openzeppelin/contracts
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title StakingVault — ETH Staking with Reentrancy Protection
/// @notice Users stake ETH and earn rewards based on time staked.
contract StakingVault is ReentrancyGuard, Ownable {

    // ── State variables ───────────────────────────────────────────────
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTime;

    // Reward rate: adjust this to control how fast rewards grow.
    // 1e12 = a small reward per second per wei staked (tune as needed).
    uint256 public constant REWARD_RATE = 1e12;

    // Minimum time a user must stake before withdrawing (1 hour).
    uint256 public constant MIN_STAKE_DURATION = 3600;

    // ── Events ────────────────────────────────────────────────────────
    // Events act as receipts — recorded on-chain for transparency.
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    // ── Constructor ───────────────────────────────────────────────────
    // Ownable(msg.sender) sets you as the contract owner.
    constructor() Ownable(msg.sender) {}

    // ── stake() ───────────────────────────────────────────────────────
    /// @notice Deposit ETH into the vault to start earning rewards.
    function stake() external payable nonReentrant {
        // nonReentrant ← THIS is the critical fix. It locks the function
        // during execution so no second call can sneak in.

        require(msg.value > 0, "Must send ETH");

        // If already staking, add to existing balance.
        // Update depositTime proportionally (weighted average).
        if (balances[msg.sender] > 0) {
            // Collect pending reward before adding new stake
            uint256 pending = calculateReward(msg.sender);
            // Reset deposit time weighted to new total
            depositTime[msg.sender] = block.timestamp;
            balances[msg.sender] += msg.value + pending;
        } else {
            balances[msg.sender] = msg.value;
            depositTime[msg.sender] = block.timestamp;
        }

        emit Staked(msg.sender, msg.value);
    }

    // ── withdraw() ────────────────────────────────────────────────────
    /// @notice Withdraw your staked ETH plus earned rewards.
    function withdraw() external nonReentrant {
        // ── CHECKS ────────────────────────────────────────────────────
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        require(
            block.timestamp >= depositTime[msg.sender] + MIN_STAKE_DURATION,
            "Must stake for at least 1 hour"
        );

        uint256 reward = calculateReward(msg.sender);

        // ── EFFECTS (update state FIRST) ──────────────────────────────
        // This is the CEI pattern: state changes happen BEFORE any ETH
        // is sent. Even if reentrancy somehow occurred, balance is 0.
        balances[msg.sender] = 0;
        depositTime[msg.sender] = 0;

        // ── INTERACTIONS (send ETH last) ──────────────────────────────
        // FIX: Use .call() instead of .transfer()
        // .transfer() has a 2300 gas limit which can fail with
        // smart contract wallets. .call() is the modern standard.
        (bool success, ) = payable(msg.sender).call{
            value: amount + reward
        }("");
        require(success, "ETH transfer failed");

        emit Withdrawn(msg.sender, amount, reward);
    }

    // ── emergencyWithdraw() ───────────────────────────────────────────
    /// @notice Exit immediately with no reward (for emergencies only).
    function emergencyWithdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        // CEI: clear state before sending
        balances[msg.sender] = 0;
        depositTime[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Emergency withdraw failed");

        emit EmergencyWithdraw(msg.sender, amount);
    }

    // ── calculateReward() ─────────────────────────────────────────────
    /// @notice View how much reward a user has earned so far.
    /// @param user The wallet address to check.
    function calculateReward(address user) public view returns (uint256) {
        if (balances[user] == 0) return 0;

        uint256 duration = block.timestamp - depositTime[user];

        // reward = balance × rate × duration / 1e18
        // Dividing by 1e18 prevents the number from being astronomically large.
        return (balances[user] * REWARD_RATE * duration) / 1e18;
    }

    // ── getStakeInfo() ────────────────────────────────────────────────
    /// @notice Get full staking details for any address.
    function getStakeInfo(address user)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 stakedSince,
            uint256 currentReward
        )
    {
        return (
            balances[user],
            depositTime[user],
            calculateReward(user)
        );
    }

    // ── Owner-only: recover stuck ETH ────────────────────────────────
    /// @notice Allows owner to withdraw contract's surplus ETH (for admin use).
    function recoverETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Recovery failed");
    }

    // Allow contract to receive ETH directly (for funding rewards)
    receive() external payable {}
}
