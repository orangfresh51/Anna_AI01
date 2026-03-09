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
error Anna_InvalidNonce();
error Anna_InvalidSignature();
error Anna_ExpiredDeadline();
error Anna_InvalidPath();
error Anna_InvalidAmountIn();
error Anna_InvalidAmountOutMin();
error Anna_InvalidRecipient();
error Anna_InvalidSender();
error Anna_InvalidToken();
error Anna_InvalidStrategy();
error Anna_InvalidRound();
error Anna_InvalidRoundId();
error Anna_InvalidAgent();
error Anna_InvalidTaskHash();
error Anna_InvalidCapabilityId();
error Anna_InvalidPriority();
error Anna_InvalidAttester();
error Anna_InvalidRequester();
error Anna_InvalidExecutor();
error Anna_InvalidGovernorAddress();
error Anna_InvalidTreasuryAddress();
error Anna_InvalidOperatorAddress();
error Anna_InvalidRelayAddress();
error Anna_InvalidOracleAddress();
error Anna_InvalidTaskQueueCap();
error Anna_InvalidCapabilitySlots();
error Anna_InvalidExecutionCooldown();
error Anna_InvalidRewardBasisPoints();
error Anna_InvalidGenesisBlockNumber();
error Anna_InvalidDomainSeparatorValue();
error Anna_InvalidNonceValue();
error Anna_InvalidSignatureValue();
error Anna_InvalidExpiredDeadline();
error Anna_InvalidPathLength();
error Anna_InvalidAmountInValue();
error Anna_InvalidAmountOutMinValue();
error Anna_InvalidRecipientAddress();
error Anna_InvalidSenderAddress();
error Anna_InvalidTokenAddress();
error Anna_InvalidStrategyIdValue();
error Anna_InvalidRoundIdValue();
error Anna_InvalidAgentAddress();
error Anna_InvalidTaskHashValue();
error Anna_InvalidCapabilityIdValue();
error Anna_InvalidPriorityValue();
error Anna_InvalidAttesterAddress();
error Anna_InvalidRequesterAddress();
error Anna_InvalidExecutorAddress();

// -----------------------------------------------------------------------------
// Events (Anna-specific)
// -----------------------------------------------------------------------------

event ClawAllocation(uint256 indexed allocId, address indexed beneficiary, uint256 amountWei, uint256 strategyId, uint40 atBlock);
event VaultSweep(address indexed from, uint256 amountWei, uint256 sweepId, uint40 atBlock);
event StrategyTick(uint256 indexed strategyId, uint256 tickEpoch, uint256 allocSumWei, uint40 atBlock);
event OrderQueued(uint256 indexed orderId, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint256 deadline);
event OrderFilled(uint256 indexed orderId, uint256 amountOut, uint256 filledAtBlock);
event OrderCancelled(uint256 indexed orderId, uint256 atBlock);
event TreasuryTopped(address indexed from, uint256 amountWei);
event TreasuryWithdrawn(address indexed to, uint256 amountWei);
event RouterSet(address indexed previousRouter, address indexed newRouter);
event OperatorSet(address indexed previousOperator, address indexed newOperator);
event GovernorSet(address indexed previousGovernor, address indexed newGovernor);
event ClawPausedToggled(bool paused);
event PositionOpened(address indexed user, uint256 indexed positionId, uint256 sizeWei, uint256 strategyId);
event PositionClosed(address indexed user, uint256 indexed positionId, uint256 realisedWei);
event DepositSwept(address indexed user, uint256 amountWei, uint256 depositId);
event WithdrawRequested(address indexed user, uint256 amountWei, uint256 requestId);
event WithdrawCompleted(address indexed user, uint256 amountWei, uint256 requestId);
event RoundOpened(uint256 indexed roundId, bytes32 promptDigest, address proposer);
event RoundSealed(uint256 indexed roundId, bytes32 responseRoot, uint8 confidenceTier);
event RoundFinalized(uint256 indexed roundId);
event AgentRegistered(address indexed agent, bytes32 modelFingerprint);
event StakeDeposited(address indexed from, uint256 amount);
event RewardDisbursed(address indexed to, uint256 amountWei);
event FeeCollected(address indexed token, uint256 amount, address to);
event LiquidationExecuted(address indexed user, uint256 positionId, uint256 liquidatedWei);
event HealthFactorUpdated(address indexed user, uint256 healthFactorBps);
event EpochAdvanced(uint256 indexed epochId, uint256 atBlock);
event NonceConsumed(bytes32 indexed nonce, address consumer);
event CapabilityAttested(uint256 indexed slotIndex, bytes32 capabilityId, address attester);
event CapabilityRevoked(uint256 indexed slotIndex, uint256 atBlock);
event TaskEnqueued(uint256 indexed taskIndex, bytes32 taskHash, address requester, uint8 priority);
event TaskExecuted(uint256 indexed taskIndex, uint256 atBlock);
event UpgradeScheduled(uint256 nextVersion, uint256 effectiveBlock);
event UpgradeApplied(uint256 version, uint256 atBlock);
event CircuitBreakerToggled(bool paused);
event MinStakeUpdated(uint256 previousMin, uint256 newMin);
event MaxPositionsUpdated(uint256 previousMax, uint256 newMax);
event CooldownUpdated(uint256 previousCooldown, uint256 newCooldown);
event FeeBpsUpdated(uint256 previousBps, uint256 newBps);
event EpochLengthUpdated(uint256 previousLength, uint256 newLength);
event RouterUpdated(address previousRouter, address newRouter);
event TreasuryUpdated(address previousTreasury, address newTreasury);
event OperatorUpdated(address previousOperator, address newOperator);
event GovernorUpdated(address previousGovernor, address newGovernor);
event RelayUpdated(address previousRelay, address newRelay);
event OracleUpdated(address previousOracle, address newOracle);
event CapUpdated(uint256 previousCap, uint256 newCap);
event SlotsUpdated(uint256 previousSlots, uint256 newSlots);
event RewardBpsUpdated(uint256 previousBps, uint256 newBps);
event DomainSeparatorUpdated(bytes32 previousSeparator, bytes32 newSeparator);
event GenesisBlockUpdated(uint256 previousBlock, uint256 newBlock);
event NonceUpdated(bytes32 previousNonce, bytes32 newNonce);
event SignatureUpdated(bytes previousSignature, bytes newSignature);
event DeadlineUpdated(uint256 previousDeadline, uint256 newDeadline);
event PathUpdated(address[] previousPath, address[] newPath);
