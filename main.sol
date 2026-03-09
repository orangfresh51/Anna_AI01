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

    function executeOrder(uint256 orderId) external onlyOperator nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        AnnaOrder storage o = orders[orderId];
        if (o.placedAtBlock == 0) revert Anna_OrderMissing();
        if (o.filled) revert Anna_OrderAlreadySettled();
        if (o.cancelled) revert Anna_OrderCancelled();
        if (block.timestamp > o.deadline) revert Anna_OrderCancelled();
        address[] memory path = new address[](2);
        path[0] = o.tokenIn;
        path[1] = o.tokenOut;
        IERC20Anna(o.tokenIn).transferFrom(vault, address(this), o.amountIn);
        IERC20Anna(o.tokenIn).approve(router, o.amountIn);
        uint256 balanceBefore = IERC20Anna(o.tokenOut).balanceOf(vault);
        try IAnnaRouter(router).swapExactTokensForTokens(
            o.amountIn,
            o.amountOutMin,
            path,
            vault,
            o.deadline
        ) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            IERC20Anna(o.tokenIn).approve(router, 0);
            bool refund = IERC20Anna(o.tokenIn).transfer(vault, o.amountIn);
            if (!refund) revert Anna_TransferReverted();
            revert Anna_RouterReverted();
        }
        IERC20Anna(o.tokenIn).approve(router, 0);
        uint256 balanceAfter = IERC20Anna(o.tokenOut).balanceOf(vault);
        if (balanceAfter <= balanceBefore) revert Anna_TransferReverted();
        amountOut = balanceAfter - balanceBefore;
        o.filled = true;
        emit OrderFilled(orderId, amountOut, block.number);
        return amountOut;
    }

    function cancelOrder(uint256 orderId) external onlyOperator {
        AnnaOrder storage o = orders[orderId];
        if (o.placedAtBlock == 0) revert Anna_OrderMissing();
        if (o.filled) revert Anna_OrderAlreadySettled();
        o.cancelled = true;
        emit OrderCancelled(orderId, block.number);
    }

    function executeSwapDirect(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert Anna_ZeroAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert Anna_ZeroAddress();
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        if (IERC20Anna(tokenIn).balanceOf(vault) < amountIn) revert Anna_VaultInsufficient();
        IERC20Anna(tokenIn).transferFrom(vault, address(this), amountIn);
        IERC20Anna(tokenIn).approve(router, amountIn);
        uint256 balanceBefore = IERC20Anna(tokenOut).balanceOf(vault);
        try IAnnaRouter(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            vault,
            deadline
        ) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            IERC20Anna(tokenIn).approve(router, 0);
            bool refund = IERC20Anna(tokenIn).transfer(vault, amountIn);
            if (!refund) revert Anna_TransferReverted();
            revert Anna_RouterReverted();
        }
        IERC20Anna(tokenIn).approve(router, 0);
        uint256 balanceAfter = IERC20Anna(tokenOut).balanceOf(vault);
        if (balanceAfter <= balanceBefore) revert Anna_TransferReverted();
        amountOut = balanceAfter - balanceBefore;
        return amountOut;
    }

    function topTreasury() external payable {
        if (msg.value == 0) revert Anna_ZeroAmount();
        (bool sent,) = treasury.call{value: msg.value}("");
        if (!sent) revert Anna_TransferReverted();
        emit TreasuryTopped(msg.sender, msg.value);
    }

    function withdrawTreasury(uint256 amountWei, address to) external onlyTreasury nonReentrant {
        if (to == address(0)) revert Anna_ZeroAddress();
        if (totalWithdrawnWei + amountWei > ANNA_WITHDRAW_CAP_WEI) revert Anna_WithdrawOverCap();
        totalWithdrawnWei += amountWei;
        (bool sent,) = to.call{value: amountWei}("");
        if (!sent) revert Anna_TransferReverted();
        emit TreasuryWithdrawn(to, amountWei);
    }

    function allocateClaw(uint256 strategyId, address beneficiary, uint256 amountWei) external onlyOperator whenClawNotPaused nonReentrant {
        if (beneficiary == address(0)) revert Anna_ZeroAddress();
        if (amountWei == 0) revert Anna_ZeroAmount();
        AnnaStrategy storage s = strategies[strategyId];
        if (!s.active) revert Anna_InvalidStrategyId();
        if (s.sealed) revert Anna_StrategySealed();
        if (s.allocUsedWei + amountWei > s.allocCapWei) revert Anna_AllocCapExceeded();
        if (amountWei > ANNA_MAX_ALLOC_PER_EPOCH_WEI) revert Anna_AllocOverflow();
        s.allocUsedWei += amountWei;
        allocCounter++;
        (bool sent,) = beneficiary.call{value: amountWei}("");
        if (!sent) revert Anna_VaultSweepFailed();
        emit ClawAllocation(allocCounter, beneficiary, amountWei, strategyId, uint40(block.number));
    }

    function registerStrategy(uint256 strategyId, uint256 allocCapWei) external onlyGovernor {
        if (strategies[strategyId].lastTickBlock != 0) revert Anna_InvalidStrategyId();
        strategies[strategyId] = AnnaStrategy({
            allocCapWei: allocCapWei,
            allocUsedWei: 0,
            tickEpoch: 0,
            lastTickBlock: block.number,
            sealed: false,
            active: true,
            confidenceTier: 0
        });
    }

    function sealStrategy(uint256 strategyId) external onlyGovernor {
        AnnaStrategy storage s = strategies[strategyId];
        if (s.lastTickBlock == 0) revert Anna_InvalidStrategyId();
        s.sealed = true;
        emit StrategyTick(strategyId, s.tickEpoch, s.allocUsedWei, uint40(block.number));
    }

    function tickStrategy(uint256 strategyId) external onlyOperator {
        AnnaStrategy storage s = strategies[strategyId];
        if (s.lastTickBlock == 0) revert Anna_InvalidStrategyId();
        if (s.sealed) revert Anna_StrategySealed();
        s.tickEpoch++;
        s.lastTickBlock = block.number;
        emit StrategyTick(strategyId, s.tickEpoch, s.allocUsedWei, uint40(block.number));
    }

    function sweepVault(uint256 amountWei) external onlyOperator nonReentrant whenClawNotPaused {
        if (amountWei == 0) revert Anna_ZeroAmount();
        if (address(this).balance < amountWei) revert Anna_VaultInsufficient();
        sweepCounter++;
        (bool sent,) = vault.call{value: amountWei}("");
        if (!sent) revert Anna_VaultSweepFailed();
        emit VaultSweep(msg.sender, amountWei, sweepCounter, uint40(block.number));
    }

    function openPosition(uint256 strategyId, uint256 sizeWei) external whenClawNotPaused nonReentrant returns (uint256 positionId) {
        if (userStakeWei[msg.sender] < minStakeWei) revert Anna_StakeTooLow();
        if (agentsSuspended[msg.sender]) revert Anna_AgentSuspended();
        if (userPositionCount[msg.sender] >= maxPositionsPerUser) revert Anna_MaxPositionsReached();
        AnnaStrategy storage s = strategies[strategyId];
        if (!s.active || s.lastTickBlock == 0) revert Anna_InvalidStrategyId();
        if (sizeWei == 0) revert Anna_InvalidPositionSize();
        positionCounter++;
        positionId = positionCounter;
        positions[positionId] = AnnaPosition({
            user: msg.sender,
            strategyId: strategyId,
            sizeWei: sizeWei,
            openedAtBlock: block.number,
            entryPriceE8: 0,
            closed: false,
            realisedWei: 0
        });
        userPositionCount[msg.sender]++;
        emit PositionOpened(msg.sender, positionId, sizeWei, strategyId);
        return positionId;
    }

    function closePosition(uint256 positionId, uint256 realisedWei) external nonReentrant {
        AnnaPosition storage p = positions[positionId];
        if (p.openedAtBlock == 0) revert Anna_PositionNotFound();
        if (p.user != msg.sender && msg.sender != operator) revert Anna_ClawDenied();
        if (p.closed) revert Anna_OrderAlreadySettled();
        p.closed = true;
        p.realisedWei = realisedWei;
        userPositionCount[p.user]--;
        emit PositionClosed(p.user, positionId, realisedWei);
    }

    function depositStake() external payable {
        if (msg.value == 0) revert Anna_ZeroAmount();
        userStakeWei[msg.sender] += msg.value;
        totalStakedWei += msg.value;
        emit StakeDeposited(msg.sender, msg.value);
    }

    function requestWithdrawStake(uint256 amountWei) external {
        if (amountWei == 0) revert Anna_ZeroAmount();
        if (userStakeWei[msg.sender] < amountWei) revert Anna_VaultInsufficient();
        if (block.number < lastExecutionBlock[msg.sender] + cooldownBlocks) revert Anna_CooldownActive();
        withdrawRequestCounter++;
        withdrawRequests[withdrawRequestCounter] = AnnaWithdrawRequest({
            user: msg.sender,
            amountWei: amountWei,
            requestedAtBlock: block.number,
            completed: false
        });
        emit WithdrawRequested(msg.sender, amountWei, withdrawRequestCounter);
    }

    function completeWithdrawRequest(uint256 requestId) external onlyOperator nonReentrant {
        AnnaWithdrawRequest storage r = withdrawRequests[requestId];
        if (r.requestedAtBlock == 0) revert Anna_OrderMissing();
        if (r.completed) revert Anna_OrderAlreadySettled();
        if (userStakeWei[r.user] < r.amountWei) revert Anna_VaultInsufficient();
        r.completed = true;
        userStakeWei[r.user] -= r.amountWei;
        totalStakedWei -= r.amountWei;
        (bool sent,) = r.user.call{value: r.amountWei}("");
        if (!sent) revert Anna_TransferReverted();
        emit WithdrawCompleted(r.user, r.amountWei, requestId);
    }

    function recordDeposit() external payable returns (uint256 depositId) {
        if (msg.value == 0) revert Anna_ZeroAmount();
        depositCounter++;
        depositId = depositCounter;
        deposits[depositId] = AnnaDeposit({
            user: msg.sender,
            amountWei: msg.value,
            depositedAtBlock: block.number,
            swept: false
        });
        emit DepositSwept(msg.sender, msg.value, depositId);
        return depositId;
    }

    function getOrder(uint256 orderId) external view returns (
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        bool filled,
        bool cancelled,
        uint256 placedAtBlock
    ) {
        AnnaOrder storage o = orders[orderId];
        if (o.placedAtBlock == 0) revert Anna_OrderMissing();
        return (
            o.tokenIn,
            o.tokenOut,
            o.amountIn,
            o.amountOutMin,
            o.deadline,
            o.filled,
            o.cancelled,
            o.placedAtBlock
        );
    }

    function getStrategy(uint256 strategyId) external view returns (
        uint256 allocCapWei,
        uint256 allocUsedWei,
        uint256 tickEpoch,
        uint256 lastTickBlock,
        bool sealed,
        bool active,
        uint8 confidenceTier
    ) {
        AnnaStrategy storage s = strategies[strategyId];
        if (s.lastTickBlock == 0) revert Anna_InvalidStrategyId();
        return (
            s.allocCapWei,
            s.allocUsedWei,
            s.tickEpoch,
            s.lastTickBlock,
            s.sealed,
            s.active,
            s.confidenceTier
        );
    }

    function getPosition(uint256 positionId) external view returns (
        address user,
        uint256 strategyId,
        uint256 sizeWei,
        uint256 openedAtBlock,
        uint256 entryPriceE8,
        bool closed,
        uint256 realisedWei
    ) {
        AnnaPosition storage p = positions[positionId];
        if (p.openedAtBlock == 0) revert Anna_PositionNotFound();
        return (
            p.user,
            p.strategyId,
            p.sizeWei,
            p.openedAtBlock,
            p.entryPriceE8,
            p.closed,
            p.realisedWei
        );
    }

    function getOrderCount() external view returns (uint256) {
        return orderCounter;
    }

    function getTotalWithdrawnWei() external view returns (uint256) {
        return totalWithdrawnWei;
    }

    function getTotalStakedWei() external view returns (uint256) {
        return totalStakedWei;
    }

    function withdrawStuckToken(address token, address to, uint256 amount) external onlyGovernor {
        if (to == address(0)) revert Anna_ZeroAddress();
        bool ok = IERC20Anna(token).transfer(to, amount);
        if (!ok) revert Anna_TransferReverted();
    }

    function openRound(bytes32 promptDigest) external whenClawNotPaused returns (uint256 roundId) {
        if (promptToRound[promptDigest] != 0) revert Anna_DuplicateCommit();
        roundCounter++;
        roundId = roundCounter;
        rounds[roundId] = AnnaInferenceRound({
            promptDigest: promptDigest,
            responseRoot: bytes32(0),
            startedAt: block.timestamp,
            sealedAt: 0,
            finalized: false,
            confidenceTier: 0,
            proposer: msg.sender
        });
        promptToRound[promptDigest] = roundId;
        emit RoundOpened(roundId, promptDigest, msg.sender);
        return roundId;
    }

    function sealRound(uint256 roundId, bytes32 responseRoot, uint8 confidenceTier) external onlyOperator {
        AnnaInferenceRound storage r = rounds[roundId];
        if (r.startedAt == 0) revert Anna_InvalidRoundId();
        if (r.finalized) revert Anna_RoundNotSealed();
        if (confidenceTier > ANNA_MAX_CONFIDENCE_TIER) revert Anna_InvalidConfidence();
        r.responseRoot = responseRoot;
        r.sealedAt = block.timestamp;
        r.confidenceTier = confidenceTier;
        emit RoundSealed(roundId, responseRoot, confidenceTier);
    }

    function finalizeRound(uint256 roundId) external onlyOperator {
        AnnaInferenceRound storage r = rounds[roundId];
        if (r.startedAt == 0) revert Anna_InvalidRoundId();
        if (r.sealedAt == 0) revert Anna_RoundNotSealed();
        r.finalized = true;
        emit RoundFinalized(roundId);
    }

    function registerAgent(bytes32 modelFingerprint) external {
        emit AgentRegistered(msg.sender, modelFingerprint);
    }

    function suspendAgent(address agent, bool suspended) external onlyGovernor {
        agentsSuspended[agent] = suspended;
    }

    function consumeNonce(bytes32 nonce) external onlyOperator {
        if (nonceUsed[nonce]) revert Anna_NonceUsed();
        nonceUsed[nonce] = true;
        emit NonceConsumed(nonce, msg.sender);
    }

    function scheduleUpgrade(uint256 nextVersion) external onlyGovernor {
        nextLogicVersion = nextVersion;
        upgradeEffectiveBlock = block.number + ANNA_UPGRADE_MIN_DELAY_BLOCKS;
        emit UpgradeScheduled(nextVersion, upgradeEffectiveBlock);
    }

    function applyUpgrade() external onlyGovernor {
        if (block.number < upgradeEffectiveBlock) revert Anna_EpochNotReached();
        logicVersion = nextLogicVersion;
        emit UpgradeApplied(logicVersion, block.number);
    }

    function enqueueTask(bytes32 taskHash, uint8 priority) external whenClawNotPaused returns (uint256 taskIndex) {
        if (taskQueueIndex >= taskQueueCap) revert Anna_AllocOverflow();
        taskQueue[taskQueueIndex] = AnnaTaskEntry({
            taskHash: taskHash,
            requester: msg.sender,
            enqueuedBlock: block.number,
            priority: priority,
            executed: false,
            executedAtBlock: 0
        });
        taskIndex = taskQueueIndex;
        taskQueueIndex++;
        taskIdToQueueIndex[taskHash] = taskIndex;
        emit TaskEnqueued(taskIndex, taskHash, msg.sender, priority);
        return taskIndex;
    }

    function executeTask(uint256 taskIndex) external onlyOperator nonReentrant whenClawNotPaused {
        if (taskIndex >= taskQueueIndex) revert Anna_InvalidRoundId();
        AnnaTaskEntry storage t = taskQueue[taskIndex];
        if (t.executed) revert Anna_OrderAlreadySettled();
        if (block.number < lastExecutionBlock[tx.origin] + executionCooldownBlocks) revert Anna_CooldownActive();
        t.executed = true;
        t.executedAtBlock = block.number;
        executionCountByAddress[tx.origin]++;
        totalExecutions++;
        lastExecutionBlock[tx.origin] = block.number;
        emit TaskExecuted(taskIndex, block.number);
    }

    function attestCapability(uint256 slotIndex, bytes32 capabilityId) external {
        if (slotIndex >= capabilitySlots) revert Anna_InvalidStrategyId();
        AnnaCapabilitySlot storage c = capabilityByIndex[slotIndex];
        if (c.attestedAtBlock != 0 && !c.revoked) revert Anna_StrategySealed();
        c.capabilityId = capabilityId;
        c.attester = msg.sender;
        c.attestedAtBlock = block.number;
        c.revoked = false;
        emit CapabilityAttested(slotIndex, capabilityId, msg.sender);
    }

    function revokeCapability(uint256 slotIndex) external onlyGovernor {
        if (slotIndex >= capabilitySlots) revert Anna_InvalidStrategyId();
        capabilityByIndex[slotIndex].revoked = true;
        emit CapabilityRevoked(slotIndex, block.number);
    }

    function disburseReward(address to, uint256 amountWei) external onlyGovernor nonReentrant {
        if (to == address(0)) revert Anna_ZeroAddress();
        if (amountWei == 0) revert Anna_ZeroAmount();
        (bool sent,) = to.call{value: amountWei}("");
        if (!sent) revert Anna_TransferReverted();
        totalRewardDisbursed += amountWei;
        emit RewardDisbursed(to, amountWei);
    }

    function getRound(uint256 roundId) external view returns (
        bytes32 promptDigest,
        bytes32 responseRoot,
        uint256 startedAt,
        uint256 sealedAt,
        bool finalized,
        uint8 confidenceTier,
        address proposer
    ) {
        AnnaInferenceRound storage r = rounds[roundId];
        if (r.startedAt == 0) revert Anna_InvalidRoundId();
        return (
            r.promptDigest,
            r.responseRoot,
            r.startedAt,
            r.sealedAt,
            r.finalized,
            r.confidenceTier,
            r.proposer
        );
    }

    function getTask(uint256 taskIndex) external view returns (
        bytes32 taskHash,
        address requester,
        uint256 enqueuedBlock,
        uint8 priority,
        bool executed,
        uint256 executedAtBlock
    ) {
        if (taskIndex >= taskQueueIndex) revert Anna_InvalidRoundId();
        AnnaTaskEntry storage t = taskQueue[taskIndex];
        return (
            t.taskHash,
            t.requester,
            t.enqueuedBlock,
            t.priority,
            t.executed,
            t.executedAtBlock
        );
    }

    function getCapability(uint256 slotIndex) external view returns (
        bytes32 capabilityId,
        address attester,
        uint256 attestedAtBlock,
        bool revoked
    ) {
        if (slotIndex >= capabilitySlots) revert Anna_InvalidStrategyId();
        AnnaCapabilitySlot storage c = capabilityByIndex[slotIndex];
        return (
            c.capabilityId,
            c.attester,
            c.attestedAtBlock,
            c.revoked
        );
    }

    function getDeposit(uint256 depositId) external view returns (
        address user,
        uint256 amountWei,
        uint256 depositedAtBlock,
        bool swept
    ) {
        AnnaDeposit storage d = deposits[depositId];
        if (d.depositedAtBlock == 0) revert Anna_OrderMissing();
        return (
            d.user,
            d.amountWei,
            d.depositedAtBlock,
            d.swept
        );
    }

    function getWithdrawRequest(uint256 requestId) external view returns (
        address user,
        uint256 amountWei,
        uint256 requestedAtBlock,
        bool completed
    ) {
        AnnaWithdrawRequest storage r = withdrawRequests[requestId];
        if (r.requestedAtBlock == 0) revert Anna_OrderMissing();
        return (
            r.user,
            r.amountWei,
            r.requestedAtBlock,
            r.completed
        );
    }

    receive() external payable {}

    // -------------------------------------------------------------------------
    // Extended swap and path helpers (multi-hop, ETH pairs)
    // -------------------------------------------------------------------------

    function executeSwapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert Anna_ZeroAmount();
        if (tokenIn == address(0)) revert Anna_ZeroAddress();
