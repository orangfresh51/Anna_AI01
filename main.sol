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
event AmountInUpdated(uint256 previousAmountIn, uint256 newAmountIn);
event AmountOutMinUpdated(uint256 previousAmountOutMin, uint256 newAmountOutMin);
event RecipientUpdated(address previousRecipient, address newRecipient);
event SenderUpdated(address previousSender, address newSender);
event TokenUpdated(address previousToken, address newToken);
event StrategyUpdated(uint256 previousStrategyId, uint256 newStrategyId);
event RoundUpdated(uint256 previousRoundId, uint256 newRoundId);
event AgentUpdated(address previousAgent, address newAgent);
event TaskHashUpdated(bytes32 previousTaskHash, bytes32 newTaskHash);
event CapabilityIdUpdated(bytes32 previousCapabilityId, bytes32 newCapabilityId);
event PriorityUpdated(uint8 previousPriority, uint8 newPriority);
event AttesterUpdated(address previousAttester, address newAttester);
event RequesterUpdated(address previousRequester, address newRequester);
event ExecutorUpdated(address previousExecutor, address newExecutor);

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

uint256 constant ANNA_BPS_BASE = 10_000;
uint256 constant ANNA_MAX_SLIPPAGE_BPS = 500;
uint256 constant ANNA_MIN_PATH_LEN = 2;
uint256 constant ANNA_MAX_PATH_LEN = 5;
uint256 constant ANNA_CLAW_EPOCH_SECS = 86400;
uint256 constant ANNA_MAX_ALLOC_PER_EPOCH_WEI = 100 ether;
uint256 constant ANNA_WITHDRAW_CAP_WEI = 50 ether;
uint256 constant ANNA_MIN_STAKE_WEI = 0.1 ether;
uint256 constant ANNA_MAX_POSITIONS_PER_USER = 32;
uint256 constant ANNA_COOLDOWN_BLOCKS = 12;
uint256 constant ANNA_MAX_PAYLOAD_BYTES = 4096;
uint256 constant ANNA_UPGRADE_MIN_DELAY_BLOCKS = 100;
uint256 constant ANNA_DEFAULT_FEE_BPS = 30;
uint256 constant ANNA_DEFAULT_REWARD_BPS = 50;
uint256 constant ANNA_LIQUIDATION_THRESHOLD_BPS = 8500;
uint256 constant ANNA_HEALTH_FACTOR_MIN_BPS = 10000;
uint256 constant ANNA_GENESIS_SALT = 0x4a7c2e9f1b3d5e8a0c4f6b2d8e1a3c5f7b9d0e2a4c6e8f0b2d4a6c8e0f2a4b6d8e;
uint256 constant ANNA_ROUND_MIN_DURATION = 3;
uint256 constant ANNA_MAX_CONFIDENCE_TIER = 7;
uint256 constant ANNA_TASK_QUEUE_CAP = 256;
uint256 constant ANNA_CAPABILITY_SLOTS = 16;
uint256 constant ANNA_EXECUTION_COOLDOWN_BLOCKS = 5;
uint256 constant ANNA_REWARD_BASIS_POINTS = 100;
uint256 constant ANNA_DOMAIN_TAG = 0x6b8d2f1a4c7e9b0d3f6a8c1e4b7d0a3c6e9f2b5d8a1c4e7b0d3f6a9c2e5b8d1f4a;

// -----------------------------------------------------------------------------
// Structs
// -----------------------------------------------------------------------------

struct AnnaOrder {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 deadline;
    bool filled;
    bool cancelled;
    uint256 placedAtBlock;
}

struct AnnaStrategy {
    uint256 allocCapWei;
    uint256 allocUsedWei;
    uint256 tickEpoch;
    uint256 lastTickBlock;
    bool sealed;
    bool active;
    uint8 confidenceTier;
}

struct AnnaPosition {
    address user;
    uint256 strategyId;
    uint256 sizeWei;
    uint256 openedAtBlock;
    uint256 entryPriceE8;
    bool closed;
    uint256 realisedWei;
}

struct AnnaDeposit {
    address user;
    uint256 amountWei;
    uint256 depositedAtBlock;
    bool swept;
}

struct AnnaWithdrawRequest {
    address user;
    uint256 amountWei;
    uint256 requestedAtBlock;
    bool completed;
}

struct AnnaInferenceRound {
    bytes32 promptDigest;
    bytes32 responseRoot;
    uint256 startedAt;
    uint256 sealedAt;
    bool finalized;
    uint8 confidenceTier;
    address proposer;
}

struct AnnaAgentSnapshot {
    bytes32 modelFingerprint;
    uint256 lastInferenceBlock;
    uint256 totalRounds;
    bool suspended;
}

struct AnnaTaskEntry {
    bytes32 taskHash;
    address requester;
    uint256 enqueuedBlock;
    uint8 priority;
    bool executed;
    uint256 executedAtBlock;
}

struct AnnaCapabilitySlot {
    bytes32 capabilityId;
    address attester;
    uint256 attestedAtBlock;
    bool revoked;
}

// -----------------------------------------------------------------------------
// Anna (main contract)
// -----------------------------------------------------------------------------

contract Anna {
    // Immutable (constructor-set; no readonly)
    address public immutable governor;
    address public immutable treasury;
    address public immutable relay;
    address public immutable attestationOracle;
    address public immutable weth;
    uint256 public immutable genesisBlock;
    bytes32 public immutable domainSeparator;
    uint256 public immutable taskQueueCap;
    uint256 public immutable capabilitySlots;
    uint256 public immutable executionCooldownBlocks;
    uint256 public immutable rewardBasisPoints;

    address public vault;
    address public operator;
    address public router;
    bool public clawPaused;
    uint256 private _reentrancyLock;
    uint256 public orderCounter;
    uint256 public allocCounter;
    uint256 public sweepCounter;
    uint256 public positionCounter;
    uint256 public depositCounter;
    uint256 public withdrawRequestCounter;
    uint256 public roundCounter;
    uint256 public taskQueueIndex;
    uint256 public totalExecutions;
    uint256 public totalRewardDisbursed;
    uint256 public totalWithdrawnWei;
    uint256 public logicVersion;
    uint256 public nextLogicVersion;
    uint256 public upgradeEffectiveBlock;
    uint256 public feeBps;
    uint256 public minStakeWei;
    uint256 public maxPositionsPerUser;
    uint256 public cooldownBlocks;
    uint256 public epochLengthSecs;
    uint256 public totalStakedWei;

    mapping(uint256 => AnnaOrder) public orders;
    mapping(uint256 => AnnaStrategy) public strategies;
    mapping(uint256 => AnnaPosition) public positions;
    mapping(uint256 => AnnaDeposit) public deposits;
    mapping(uint256 => AnnaWithdrawRequest) public withdrawRequests;
    mapping(uint256 => AnnaInferenceRound) public rounds;
    mapping(uint256 => AnnaTaskEntry) public taskQueue;
    mapping(uint256 => AnnaCapabilitySlot) public capabilityByIndex;
    mapping(address => uint256) public executionCountByAddress;
    mapping(bytes32 => uint256) public taskIdToQueueIndex;
    mapping(address => uint256) public userPositionCount;
    mapping(address => uint256) public userStakeWei;
    mapping(address => uint256) public lastExecutionBlock;
    mapping(bytes32 => bool) public nonceUsed;
    mapping(address => bool) public agentsSuspended;
    mapping(bytes32 => uint256) public promptToRound;

    modifier onlyGovernor() {
        if (msg.sender != governor) revert Anna_NotGovernor();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Anna_NotOperator();
        _;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert Anna_NotTreasury();
        _;
    }

    modifier whenClawNotPaused() {
        if (clawPaused) revert Anna_ClawPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyLock != 0) revert Anna_Reentrant();
        _reentrancyLock = 1;
        _;
        _reentrancyLock = 0;
    }

    modifier whenNotPaused() {
        if (clawPaused) revert Anna_ClawPaused();
        _;
    }

    constructor() {
        governor = address(0x7f2e1d0c9b8a7654f3e2d1c0b9a876543210fed);
        treasury = address(0x8e3d2c1b0a9f876543210fedcba9876543210fe0);
        relay = address(0x9d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6);
        attestationOracle = address(0xa1b2c3d4e5f6789012345678901234567890abcd);
        vault = address(0xb2c3d4e5f6a789012345678901234567890abcdef);
        operator = address(0xc3d4e5f6a7b89012345678901234567890abcdef1);
        router = address(0xd4e5f6a7b8c9012345678901234567890abcdef12);
        weth = address(0xe5f6a7b8c9d012345678901234567890abcdef123);
        genesisBlock = block.number;
        domainSeparator = bytes32(ANNA_DOMAIN_TAG);
        taskQueueCap = ANNA_TASK_QUEUE_CAP;
        capabilitySlots = ANNA_CAPABILITY_SLOTS;
        executionCooldownBlocks = ANNA_EXECUTION_COOLDOWN_BLOCKS;
        rewardBasisPoints = ANNA_REWARD_BASIS_POINTS;
        feeBps = ANNA_DEFAULT_FEE_BPS;
        minStakeWei = ANNA_MIN_STAKE_WEI;
        maxPositionsPerUser = ANNA_MAX_POSITIONS_PER_USER;
        cooldownBlocks = ANNA_COOLDOWN_BLOCKS;
        epochLengthSecs = ANNA_CLAW_EPOCH_SECS;
    }

    function setClawPaused(bool paused) external onlyGovernor {
        clawPaused = paused;
        emit ClawPausedToggled(paused);
    }

    function setRouter(address newRouter) external onlyGovernor {
        if (newRouter == address(0)) revert Anna_ZeroAddress();
        address prev = router;
        router = newRouter;
        emit RouterSet(prev, newRouter);
    }

    function setOperator(address newOperator) external onlyGovernor {
        if (newOperator == address(0)) revert Anna_ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorSet(prev, newOperator);
    }

    function setVault(address newVault) external onlyGovernor {
        if (newVault == address(0)) revert Anna_ZeroAddress();
        address prev = vault;
        vault = newVault;
        emit GovernorSet(prev, newVault);
    }

    function setFeeBps(uint256 newBps) external onlyGovernor {
        if (newBps > ANNA_BPS_BASE) revert Anna_InvalidBps();
        uint256 prev = feeBps;
        feeBps = newBps;
        emit FeeBpsUpdated(prev, newBps);
    }

    function setMinStakeWei(uint256 newMin) external onlyGovernor {
        uint256 prev = minStakeWei;
        minStakeWei = newMin;
        emit MinStakeUpdated(prev, newMin);
    }

    function setMaxPositionsPerUser(uint256 newMax) external onlyGovernor {
        uint256 prev = maxPositionsPerUser;
        maxPositionsPerUser = newMax;
        emit MaxPositionsUpdated(prev, newMax);
    }

    function setCooldownBlocks(uint256 newCooldown) external onlyGovernor {
        uint256 prev = cooldownBlocks;
        cooldownBlocks = newCooldown;
        emit CooldownUpdated(prev, newCooldown);
    }

    function setEpochLengthSecs(uint256 newLength) external onlyGovernor {
        uint256 prev = epochLengthSecs;
        epochLengthSecs = newLength;
        emit EpochLengthUpdated(prev, newLength);
    }

    function placeOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator whenClawNotPaused returns (uint256 orderId) {
        if (amountIn == 0) revert Anna_ZeroAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert Anna_ZeroAddress();
        if (deadline <= block.timestamp) revert Anna_DeadlinePassed();
        orderCounter++;
        orderId = orderCounter;
        orders[orderId] = AnnaOrder({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            deadline: deadline,
            filled: false,
            cancelled: false,
            placedAtBlock: block.number
        });
        emit OrderQueued(orderId, tokenIn, tokenOut, amountIn, amountOutMin, deadline);
        return orderId;
    }

