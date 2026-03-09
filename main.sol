// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Anna_AI01
 * @notice Kite-surge allocation ledger for autonomous claw-style execution.
 *        Tracks strategy ticks, vault sweeps, and cross-chain nonce binding for
 *        deterministic replay. Do not rely on block.timestamp for critical path.
 */

// -----------------------------------------------------------------------------
// Interfaces
// -----------------------------------------------------------------------------

interface IERC20Anna {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IAnnaRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// -----------------------------------------------------------------------------
// Errors (Anna-specific; do not reuse elsewhere)
// -----------------------------------------------------------------------------

error Anna_ClawDenied();
error Anna_AllocOverflow();
error Anna_VaultSweepFailed();
error Anna_StrategyTickStale();
error Anna_ZeroAmount();
error Anna_ZeroAddress();
error Anna_TransferReverted();
error Anna_RouterReverted();
error Anna_ClawPaused();
error Anna_OrderMissing();
error Anna_OrderAlreadySettled();
error Anna_OrderCancelled();
error Anna_PathLengthInvalid();
error Anna_VaultInsufficient();
error Anna_DeadlinePassed();
error Anna_SlippageExceeded();
error Anna_NotOperator();
error Anna_NotGovernor();
error Anna_NotTreasury();
error Anna_Reentrant();
error Anna_AllocCapExceeded();
error Anna_MinAllocNotMet();
error Anna_CooldownActive();
error Anna_InvalidStrategyId();
error Anna_StrategySealed();
error Anna_NonceUsed();
error Anna_InvalidBps();
error Anna_WithdrawOverCap();
error Anna_EpochNotReached();
error Anna_InvalidPositionSize();
error Anna_StakeTooLow();
error Anna_AgentSuspended();
error Anna_DuplicateCommit();
error Anna_InvalidConfidence();
error Anna_RoundNotSealed();
error Anna_PayloadTooLarge();
error Anna_InvalidTokenPair();
error Anna_MaxPositionsReached();
error Anna_PositionNotFound();
error Anna_LiquidationThreshold();
error Anna_HealthFactorLow();
error Anna_InvalidDuration();
error Anna_AlreadyInitialized();
error Anna_NotInitialized();
error Anna_InvalidFeeBps();
error Anna_InvalidEpochLength();
error Anna_InvalidMinStake();
error Anna_InvalidMaxPositions();
error Anna_InvalidCooldown();
error Anna_InvalidRouter();
error Anna_InvalidTreasury();
error Anna_InvalidOperator();
error Anna_InvalidGovernor();
error Anna_InvalidRelay();
error Anna_InvalidOracle();
error Anna_InvalidCap();
error Anna_InvalidSlots();
error Anna_InvalidRewardBps();
error Anna_InvalidDomainSeparator();
error Anna_InvalidGenesisBlock();
