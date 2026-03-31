// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// ============================================
// OPENZEPPELIN CONTRACTS v5.0.0 - FLATTENED
// ============================================

// File: @openzeppelin/contracts/utils/Context.sol
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol
abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/access/Ownable2Step.sol
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}

// File: @openzeppelin/contracts/utils/Pausable.sol
abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error EnforcedPause();
    error ExpectedPause();

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/interfaces/draft-IERC6093.sol
interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// File: @openzeppelin/contracts/utils/Address.sol
library Address {
    error AddressInsufficientBalance(address account);
    error AddressEmptyCode(address target);
    error FailedInnerCall();

    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    function _revert(bytes memory returndata) private pure {
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol
library SafeERC20 {
    using Address for address;

    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// ============================================
// CHAINLINK INTERFACE
// ============================================

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

// ============================================
// ZYKOS TOKEN V3 - THE TOASTER TOKEN
// ============================================

/**
 * @title ZykosToken V3 Audited (ZKS) - THE TOASTER TOKEN
 * @author Clínica Psiquiátrica José Ingenieros
 * @notice Meme token con utilidad real - Psiquiatría On-Demand
 * @dev Versión auditada con correcciones de seguridad - FLATTENED
 */
contract ZykosTokenV3Audited is ERC20, Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============================================
    // CUSTOM ERRORS
    // ============================================
    
    error ZeroAddress();
    error ZeroAmount();
    error InvalidAmount();
    error CooldownActive();
    error SaleEnded();
    error InsufficientTokens();
    error InsufficientBalance();
    error NotAuthorized();
    error CampaignNotActive();
    error AlreadyClaimed();
    error MaxClaimsReached();
    error NotVerified();
    error ProposalNotActive();
    error VotingEnded();
    error AlreadyVoted();
    error VotingNotEnded();
    error NotApproved();
    error TooEarly();
    error AlreadyExecuted();
    error InvalidPrice();
    error OnlyStablecoins();
    error InsufficientStake();
    error OnlyProtectors();
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    uint256 private constant _TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 private constant _BOUNTIES_ALLOCATION = 15_000_000 * 1e18;
    uint256 private constant _SALE_ALLOCATION = 85_000_000 * 1e18;
    
    uint256 private constant _POOL_COUNT = 100;
    uint256 private constant _TOKENS_PER_POOL = 850_000 * 1e18;
    
    uint256 private constant _MAX_PER_PURCHASE = 50_000 * 1e18;
    uint256 private constant _COOLDOWN_PERIOD = 36000;
    uint256 private constant _VOTE_THRESHOLD = 20_000 * 1e18;
    uint256 private constant _PROTECTOR_THRESHOLD = 50_000 * 1e18;
    
    uint256 private constant _ACTIVATION_PERCENT = 91;
    
    uint256 private constant _PROPOSAL_THRESHOLD = 10_000 * 1e18;
    uint256 private constant _VOTING_PERIOD = 7 days;
    uint256 private constant _EXECUTION_DELAY = 2 days;
    uint256 private constant _QUORUM_PERCENT = 10;
    
    // Public getters
    function TOTAL_SUPPLY_CONST() external pure returns (uint256) { return _TOTAL_SUPPLY; }
    function BOUNTIES_ALLOCATION() external pure returns (uint256) { return _BOUNTIES_ALLOCATION; }
    function SALE_ALLOCATION() external pure returns (uint256) { return _SALE_ALLOCATION; }
    function POOL_COUNT() external pure returns (uint256) { return _POOL_COUNT; }
    function TOKENS_PER_POOL() external pure returns (uint256) { return _TOKENS_PER_POOL; }
    function MAX_PER_PURCHASE() external pure returns (uint256) { return _MAX_PER_PURCHASE; }
    function COOLDOWN_PERIOD() external pure returns (uint256) { return _COOLDOWN_PERIOD; }
    function VOTE_THRESHOLD() external pure returns (uint256) { return _VOTE_THRESHOLD; }
    function PROTECTOR_THRESHOLD() external pure returns (uint256) { return _PROTECTOR_THRESHOLD; }
    
    // ============================================
    // IMMUTABLES
    // ============================================
    
    IERC20 public immutable USDC;
    IERC20 public immutable USDT;
    AggregatorV3Interface public immutable BNB_USD_FEED;
    
    // ============================================
    // TOAST STATES
    // ============================================
    
    enum ToastState { VIRGIN, BRONZE, CHARCOAL }
    
    uint256 public totalVirgin;
    uint256 public totalBronze;
    uint256 public totalCharcoal;
    uint256 public totalToasted;
    
    // ============================================
    // WALLETS
    // ============================================
    
    address public treasury;
    address public treasuryBit;
    address public primesMoney;
    address public realEstate;
    address public baulera;
    address public bountiesWallet;
    
    // ============================================
    // POOL STRUCTURE
    // ============================================
    
    enum PoolStatus { Locked, Active, Releasing, Exhausted }
    
    struct Pool {
        uint256 pricePerToken;
        uint256 tokensRemaining;
        uint256 tokensSold;
        PoolStatus status;
        uint256 activatedAt;
    }
    
    mapping(uint256 => Pool) public pools;
    uint256 public currentPool;
    
    // ============================================
    // BAULERA - TOAST TRACKING
    // ============================================
    
    uint256 public bauleraVirgin;
    uint256 public bauleraBronze;
    uint256 public bauleraCharcoal;
    uint256 public bauleraTotal;
    
    struct ToastRecord {
        uint256 amount;
        ToastState fromState;
        ToastState toState;
        uint256 timestamp;
    }
    
    ToastRecord[] public toastHistory;
    
    // ============================================
    // BUYER TRACKING & ROLES
    // ============================================
    
    mapping(address => uint256) public lastPurchaseTime;
    mapping(address => uint256) public totalPurchasedUSD;
    mapping(address => bool) public hasVotingRights;
    mapping(address => bool) public isProtector;
    
    address[] private _voters;
    address[] private _protectors;
    uint256 public totalVoters;
    uint256 public totalProtectors;
    
    // ============================================
    // BOUNTIES
    // ============================================
    
    enum BountyCategory { SOCIAL, COMMUNITY, DEVELOPER, PARTNERSHIP, SPECIAL }
    
    struct BountyCampaign {
        string name;
        BountyCategory category;
        uint256 totalAllocation;
        uint256 distributed;
        uint256 perClaimAmount;
        uint256 maxClaims;
        uint256 claims;
        uint256 endTime;
        bool active;
        bool requiresVerification;
    }
    
    uint256 public campaignCount;
    mapping(uint256 => BountyCampaign) public campaigns;
    mapping(uint256 => mapping(address => bool)) public campaignClaimed;
    mapping(uint256 => mapping(address => bool)) public campaignVerified;
    
    uint256 public totalBountiesDistributed;
    mapping(BountyCategory => uint256) public categoryDistributed;
    
    // ============================================
    // GOVERNANCE
    // ============================================
    
    enum ProposalStatus { Active, Approved, Rejected, Executed, Cancelled }
    enum ProposalType { PARAMETER, TREASURY, BOUNTY, PARTNERSHIP, COMMUNITY, EMERGENCY }
    
    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 voterCount;
        uint256 votingEndsAt;
        uint256 executionTime;
        ProposalStatus status;
        bool executed;
    }
    
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256[] private _activeProposalIds;
    
    // ============================================
    // STATS
    // ============================================
    
    uint256 public totalUSDRaised;
    uint256 public totalBNBRaised;
    uint256 public totalTokensSold;
    uint256 public totalServicesReceived;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event TokensPurchased(address indexed buyer, uint256 indexed poolId, uint256 tokens, uint256 usdValue, string paymentMethod);
    event PoolActivated(uint256 indexed poolId, uint256 price);
    event PoolExhausted(uint256 indexed poolId);
    event ServicePaymentReceived(address indexed from, uint256 indexed amount);
    event TokensToasted(uint256 indexed amount, ToastState fromState, ToastState toState);
    event ToastedTokensReleasedForSale(uint256 indexed amount, ToastState state);
    event VotingRightsGranted(address indexed voter, uint256 totalPurchased);
    event ProtectorGranted(address indexed protector, uint256 totalPurchased);
    event BountyClaimed(uint256 indexed campaignId, address indexed claimer, uint256 amount);
    event CampaignCreated(uint256 indexed campaignId, string name, uint256 allocation);
    event CampaignEnded(uint256 indexed campaignId);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalFinalized(uint256 indexed proposalId, ProposalStatus status);
    event TreasuryDistributed(uint256 indexed total, uint256 toTreasury, uint256 toBit, uint256 toPrimes, uint256 toRealEstate);
    event TreasuriesUpdated(address treasury, address treasuryBit, address primesMoney, address realEstate);
    event BauleraUpdated(address indexed oldBaulera, address indexed newBaulera);
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyBaulera() {
        if (msg.sender != baulera) revert NotAuthorized();
        _;
    }
    
    modifier onlyVoter() {
        if (!hasVotingRights[msg.sender]) revert NotAuthorized();
        _;
    }
    
    modifier onlyProtectorRole() {
        if (!isProtector[msg.sender]) revert OnlyProtectors();
        _;
    }
    
    modifier notZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }
    
    modifier notZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor(
        address _usdc,
        address _usdt,
        address _bnbUsdFeed,
        address _treasury,
        address _treasuryBit,
        address _primesMoney,
        address _realEstate,
        address _baulera,
        address _bountiesWallet
    ) ERC20("Zykos", "ZKS") Ownable(msg.sender) {
        if (_usdc == address(0)) revert ZeroAddress();
        if (_usdt == address(0)) revert ZeroAddress();
        if (_bnbUsdFeed == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_treasuryBit == address(0)) revert ZeroAddress();
        if (_primesMoney == address(0)) revert ZeroAddress();
        if (_realEstate == address(0)) revert ZeroAddress();
        if (_baulera == address(0)) revert ZeroAddress();
        if (_bountiesWallet == address(0)) revert ZeroAddress();
        
        USDC = IERC20(_usdc);
        USDT = IERC20(_usdt);
        BNB_USD_FEED = AggregatorV3Interface(_bnbUsdFeed);
        
        treasury = _treasury;
        treasuryBit = _treasuryBit;
        primesMoney = _primesMoney;
        realEstate = _realEstate;
        baulera = _baulera;
        bountiesWallet = _bountiesWallet;
        
        _mint(address(this), _SALE_ALLOCATION);
        _mint(_bountiesWallet, _BOUNTIES_ALLOCATION);
        
        totalVirgin = _SALE_ALLOCATION;
        
        _initializePools();
    }
    
    // ============================================
    // POOL INITIALIZATION - 23 JUMPS
    // ============================================
    
    function _initializePools() private {
        uint256 basePrice = 5e16;
        uint256 price = basePrice;
        
        uint8[23] memory jumpPools = [3, 6, 9, 13, 17, 21, 22, 25, 29, 33, 37, 43, 49, 57, 63, 75, 81, 83, 89, 91, 93, 95, 99];
        uint8[23] memory jumpPercents = [2, 5, 3, 4, 2, 6, 1, 3, 4, 3, 5, 2, 7, 4, 3, 6, 2, 4, 3, 5, 2, 4, 8];
        
        uint256 jumpIndex;
        
        for (uint256 i; i < _POOL_COUNT; ) {
            if (jumpIndex < 23 && i == jumpPools[jumpIndex]) {
                price = (price * (100 + jumpPercents[jumpIndex])) / 100;
                unchecked { ++jumpIndex; }
            }
            
            pools[i] = Pool({
                pricePerToken: price,
                tokensRemaining: _TOKENS_PER_POOL,
                tokensSold: 0,
                status: i == 0 ? PoolStatus.Active : PoolStatus.Locked,
                activatedAt: i == 0 ? block.timestamp : 0
            });
            
            unchecked { ++i; }
        }
        
        emit PoolActivated(0, basePrice);
    }
    
    // ============================================
    // BUY FUNCTIONS
    // ============================================
    
    function buyWithUSDC(uint256 usdAmount) external nonReentrant whenNotPaused {
        _buyWithStable(USDC, usdAmount);
    }
    
    function buyWithUSDT(uint256 usdAmount) external nonReentrant whenNotPaused {
        _buyWithStable(USDT, usdAmount);
    }
    
    function buyWithBNB() external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert ZeroAmount();
        
        uint256 usdValue = getBNBValueInUSD(msg.value);
        if (usdValue > _MAX_PER_PURCHASE) revert InvalidAmount();
        if (block.timestamp < lastPurchaseTime[msg.sender] + _COOLDOWN_PERIOD) revert CooldownActive();
        if (currentPool >= _POOL_COUNT) revert SaleEnded();
        
        uint256 tokenAmount = _calculateTokens(usdValue);
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf(address(this)) < tokenAmount) revert InsufficientTokens();
        
        _distributeBNBTreasury(msg.value);
        _updatePools(tokenAmount);
        _transfer(address(this), msg.sender, tokenAmount);
        
        unchecked {
            totalBNBRaised += msg.value;
            totalUSDRaised += usdValue;
            totalTokensSold += tokenAmount;
            totalPurchasedUSD[msg.sender] += usdValue;
        }
        lastPurchaseTime[msg.sender] = block.timestamp;
        
        if (totalVirgin >= tokenAmount) {
            unchecked { totalVirgin -= tokenAmount; }
        }
        
        _checkVotingRights(msg.sender);
        
        emit TokensPurchased(msg.sender, currentPool, tokenAmount, usdValue, "BNB");
    }
    
    function _buyWithStable(IERC20 stablecoin, uint256 usdAmount) private {
        if (usdAmount == 0) revert ZeroAmount();
        if (usdAmount > _MAX_PER_PURCHASE) revert InvalidAmount();
        if (block.timestamp < lastPurchaseTime[msg.sender] + _COOLDOWN_PERIOD) revert CooldownActive();
        if (currentPool >= _POOL_COUNT) revert SaleEnded();
        
        uint256 tokenAmount = _calculateTokens(usdAmount);
        if (tokenAmount == 0) revert ZeroAmount();
        if (balanceOf(address(this)) < tokenAmount) revert InsufficientTokens();
        
        stablecoin.safeTransferFrom(msg.sender, address(this), usdAmount);
        
        _distributeStableTreasury(stablecoin, usdAmount);
        _updatePools(tokenAmount);
        _transfer(address(this), msg.sender, tokenAmount);
        
        unchecked {
            totalUSDRaised += usdAmount;
            totalTokensSold += tokenAmount;
            totalPurchasedUSD[msg.sender] += usdAmount;
        }
        lastPurchaseTime[msg.sender] = block.timestamp;
        
        if (totalVirgin >= tokenAmount) {
            unchecked { totalVirgin -= tokenAmount; }
        }
        
        _checkVotingRights(msg.sender);
        
        string memory method = address(stablecoin) == address(USDC) ? "USDC" : "USDT";
        emit TokensPurchased(msg.sender, currentPool, tokenAmount, usdAmount, method);
    }
    
    // ============================================
    // TREASURY DISTRIBUTION
    // ============================================
    
    function _distributeStableTreasury(IERC20 token, uint256 amount) private {
        uint256 toTreasury = (amount * 50) / 100;
        uint256 toBit = (amount * 25) / 100;
        uint256 toPrimes = (amount * 125) / 1000;
        uint256 toReal = amount - toTreasury - toBit - toPrimes;
        
        token.safeTransfer(treasury, toTreasury);
        token.safeTransfer(treasuryBit, toBit);
        token.safeTransfer(primesMoney, toPrimes);
        token.safeTransfer(realEstate, toReal);
        
        emit TreasuryDistributed(amount, toTreasury, toBit, toPrimes, toReal);
    }
    
    function _distributeBNBTreasury(uint256 amount) private {
        uint256 toTreasury = (amount * 50) / 100;
        uint256 toBit = (amount * 25) / 100;
        uint256 toPrimes = (amount * 125) / 1000;
        uint256 toReal = amount - toTreasury - toBit - toPrimes;
        
        (bool s1,) = treasury.call{value: toTreasury}("");
        (bool s2,) = treasuryBit.call{value: toBit}("");
        (bool s3,) = primesMoney.call{value: toPrimes}("");
        (bool s4,) = realEstate.call{value: toReal}("");
        
        require(s1 && s2 && s3 && s4, "BNB transfer failed");
        
        emit TreasuryDistributed(amount, toTreasury, toBit, toPrimes, toReal);
    }
    
    // ============================================
    // BNB PRICE FEED
    // ============================================
    
    function getBNBPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = BNB_USD_FEED.latestRoundData();
        if (price <= 0) revert InvalidPrice();
        if (block.timestamp - updatedAt > 3600) revert InvalidPrice();
        return uint256(price) * 1e10;
    }
    
    function getBNBValueInUSD(uint256 bnbAmount) public view returns (uint256) {
        uint256 bnbPrice = getBNBPrice();
        return (bnbAmount * bnbPrice) / 1e18;
    }
    
    // ============================================
    // SERVICE PAYMENT → BAULERA
    // ============================================
    
    function payService(uint256 amount) external nonReentrant notZeroAmount(amount) {
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();
        
        _transfer(msg.sender, baulera, amount);
        
        unchecked {
            bauleraVirgin += amount;
            bauleraTotal += amount;
            totalServicesReceived += amount;
        }
        
        emit ServicePaymentReceived(msg.sender, amount);
    }
    
    // ============================================
    // TOAST SYSTEM
    // ============================================
    
    function toastTokens(uint256 amount) external onlyBaulera notZeroAmount(amount) {
        uint256 remaining = amount;
        
        if (remaining != 0 && bauleraVirgin != 0) {
            uint256 toToast = remaining > bauleraVirgin ? bauleraVirgin : remaining;
            
            unchecked {
                bauleraVirgin -= toToast;
                bauleraBronze += toToast;
                totalVirgin -= toToast;
                totalBronze += toToast;
                remaining -= toToast;
            }
            
            toastHistory.push(ToastRecord({
                amount: toToast,
                fromState: ToastState.VIRGIN,
                toState: ToastState.BRONZE,
                timestamp: block.timestamp
            }));
            
            emit TokensToasted(toToast, ToastState.VIRGIN, ToastState.BRONZE);
        }
        
        if (remaining != 0 && bauleraBronze != 0) {
            uint256 toToast = remaining > bauleraBronze ? bauleraBronze : remaining;
            
            unchecked {
                bauleraBronze -= toToast;
                bauleraCharcoal += toToast;
                totalBronze -= toToast;
                totalCharcoal += toToast;
                remaining -= toToast;
                totalToasted += toToast;
            }
            
            toastHistory.push(ToastRecord({
                amount: toToast,
                fromState: ToastState.BRONZE,
                toState: ToastState.CHARCOAL,
                timestamp: block.timestamp
            }));
            
            emit TokensToasted(toToast, ToastState.BRONZE, ToastState.CHARCOAL);
        }
    }
    
    function releaseToastedForSale(uint256 amount, ToastState state) external onlyOwner notZeroAmount(amount) {
        if (state == ToastState.BRONZE) {
            if (bauleraBronze < amount) revert InsufficientBalance();
            unchecked { bauleraBronze -= amount; }
        } else if (state == ToastState.CHARCOAL) {
            if (bauleraCharcoal < amount) revert InsufficientBalance();
            unchecked { bauleraCharcoal -= amount; }
        } else {
            revert InvalidAmount();
        }
        
        unchecked { bauleraTotal -= amount; }
        
        _transfer(baulera, address(this), amount);
        
        unchecked {
            pools[currentPool].tokensRemaining += amount;
        }
        
        emit ToastedTokensReleasedForSale(amount, state);
    }
    
    // ============================================
    // CALCULATE & UPDATE POOLS
    // ============================================
    
    function _calculateTokens(uint256 usdAmount) private view returns (uint256) {
        uint256 remainingUsd = usdAmount;
        uint256 tokens;
        uint256 tempPool = currentPool;
        
        while (remainingUsd != 0 && tempPool < _POOL_COUNT) {
            Pool storage pool = pools[tempPool];
            
            if (pool.tokensRemaining == 0) {
                unchecked { ++tempPool; }
                continue;
            }
            
            uint256 tokensAtPrice = (remainingUsd * 1e18) / pool.pricePerToken;
            
            if (tokensAtPrice <= pool.tokensRemaining) {
                unchecked { tokens += tokensAtPrice; }
                remainingUsd = 0;
            } else {
                unchecked {
                    tokens += pool.tokensRemaining;
                    uint256 usdUsed = (pool.tokensRemaining * pool.pricePerToken) / 1e18;
                    remainingUsd -= usdUsed;
                    ++tempPool;
                }
            }
        }
        
        return tokens;
    }
    
    function _updatePools(uint256 tokensToDeduct) private {
        while (tokensToDeduct != 0 && currentPool < _POOL_COUNT) {
            Pool storage pool = pools[currentPool];
            
            if (tokensToDeduct >= pool.tokensRemaining) {
                unchecked {
                    tokensToDeduct -= pool.tokensRemaining;
                    pool.tokensSold += pool.tokensRemaining;
                }
                pool.tokensRemaining = 0;
                pool.status = PoolStatus.Exhausted;
                
                emit PoolExhausted(currentPool);
                
                unchecked {
                    if (currentPool + 1 < _POOL_COUNT) {
                        ++currentPool;
                        pools[currentPool].status = PoolStatus.Active;
                        pools[currentPool].activatedAt = block.timestamp;
                        emit PoolActivated(currentPool, pools[currentPool].pricePerToken);
                    }
                }
            } else {
                unchecked {
                    pool.tokensRemaining -= tokensToDeduct;
                    pool.tokensSold += tokensToDeduct;
                }
                tokensToDeduct = 0;
                
                uint256 soldPercent = (pool.tokensSold * 100) / _TOKENS_PER_POOL;
                
                unchecked {
                    if (soldPercent >= _ACTIVATION_PERCENT && currentPool + 1 < _POOL_COUNT) {
                        if (pools[currentPool + 1].status == PoolStatus.Locked) {
                            pools[currentPool + 1].status = PoolStatus.Active;
                            pools[currentPool + 1].activatedAt = block.timestamp;
                            emit PoolActivated(currentPool + 1, pools[currentPool + 1].pricePerToken);
                        }
                    }
                }
            }
        }
    }
    
    // ============================================
    // ROLES
    // ============================================
    
    function _checkVotingRights(address buyer) private {
        uint256 purchased = totalPurchasedUSD[buyer];
        
        if (!hasVotingRights[buyer] && purchased >= _VOTE_THRESHOLD) {
            hasVotingRights[buyer] = true;
            _voters.push(buyer);
            unchecked { ++totalVoters; }
            emit VotingRightsGranted(buyer, purchased);
        }
        
        if (!isProtector[buyer] && purchased >= _PROTECTOR_THRESHOLD) {
            isProtector[buyer] = true;
            _protectors.push(buyer);
            unchecked { ++totalProtectors; }
            emit ProtectorGranted(buyer, purchased);
        }
    }
    
    // ============================================
    // BOUNTIES
    // ============================================
    
    function createCampaign(
        string calldata name,
        BountyCategory category,
        uint256 totalAllocation,
        uint256 perClaimAmount,
        uint256 maxClaims,
        uint256 durationDays,
        bool requiresVerification
    ) external onlyOwner notZeroAmount(totalAllocation) returns (uint256) {
        if (balanceOf(bountiesWallet) < totalAllocation) revert InsufficientBalance();
        if (perClaimAmount == 0 || perClaimAmount > totalAllocation) revert InvalidAmount();
        
        uint256 campaignId = campaignCount;
        unchecked { ++campaignCount; }
        
        campaigns[campaignId] = BountyCampaign({
            name: name,
            category: category,
            totalAllocation: totalAllocation,
            distributed: 0,
            perClaimAmount: perClaimAmount,
            maxClaims: maxClaims,
            claims: 0,
            endTime: block.timestamp + (durationDays * 1 days),
            active: true,
            requiresVerification: requiresVerification
        });
        
        emit CampaignCreated(campaignId, name, totalAllocation);
        return campaignId;
    }
    
    function verifyUser(uint256 campaignId, address user) external onlyOwner notZeroAddress(user) {
        campaignVerified[campaignId][user] = true;
    }
    
    function batchVerifyUsers(uint256 campaignId, address[] calldata users) external onlyOwner {
        uint256 len = users.length;
        for (uint256 i; i < len; ) {
            if (users[i] != address(0)) {
                campaignVerified[campaignId][users[i]] = true;
            }
            unchecked { ++i; }
        }
    }
    
    function claimBounty(uint256 campaignId) external nonReentrant {
        BountyCampaign storage c = campaigns[campaignId];
        
        if (!c.active || block.timestamp > c.endTime) revert CampaignNotActive();
        if (campaignClaimed[campaignId][msg.sender]) revert AlreadyClaimed();
        if (c.claims >= c.maxClaims) revert MaxClaimsReached();
        if (c.requiresVerification && !campaignVerified[campaignId][msg.sender]) revert NotVerified();
        
        campaignClaimed[campaignId][msg.sender] = true;
        
        unchecked {
            ++c.claims;
            c.distributed += c.perClaimAmount;
            totalBountiesDistributed += c.perClaimAmount;
            categoryDistributed[c.category] += c.perClaimAmount;
        }
        
        _transfer(bountiesWallet, msg.sender, c.perClaimAmount);
        
        emit BountyClaimed(campaignId, msg.sender, c.perClaimAmount);
    }
    
    function endCampaign(uint256 campaignId) external onlyOwner {
        campaigns[campaignId].active = false;
        emit CampaignEnded(campaignId);
    }
    
    function distributeBounty(address to, uint256 amount, BountyCategory category) external onlyOwner notZeroAddress(to) notZeroAmount(amount) {
        if (balanceOf(bountiesWallet) < amount) revert InsufficientBalance();
        
        _transfer(bountiesWallet, to, amount);
        
        unchecked {
            totalBountiesDistributed += amount;
            categoryDistributed[category] += amount;
        }
    }
    
    // ============================================
    // GOVERNANCE
    // ============================================
    
    function createProposal(ProposalType pType, string calldata title, string calldata description) external onlyVoter returns (uint256) {
        if (totalPurchasedUSD[msg.sender] < _PROPOSAL_THRESHOLD) revert InsufficientStake();
        if (pType == ProposalType.EMERGENCY && !isProtector[msg.sender]) revert OnlyProtectors();
        
        uint256 proposalId = proposalCount;
        unchecked { ++proposalCount; }
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: pType,
            title: title,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            voterCount: 0,
            votingEndsAt: block.timestamp + _VOTING_PERIOD,
            executionTime: 0,
            status: ProposalStatus.Active,
            executed: false
        });
        
        _activeProposalIds.push(proposalId);
        
        emit ProposalCreated(proposalId, msg.sender, title);
        return proposalId;
    }
    
    function vote(uint256 proposalId, bool support) external onlyVoter {
        Proposal storage p = proposals[proposalId];
        
        if (p.status != ProposalStatus.Active) revert ProposalNotActive();
        if (block.timestamp > p.votingEndsAt) revert VotingEnded();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        
        hasVoted[proposalId][msg.sender] = true;
        
        uint256 weight = totalPurchasedUSD[msg.sender];
        if (weight > _MAX_PER_PURCHASE) {
            weight = _MAX_PER_PURCHASE;
        }
        
        unchecked {
            if (support) {
                p.votesFor += weight;
            } else {
                p.votesAgainst += weight;
            }
            ++p.voterCount;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    function finalizeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        
        if (p.status != ProposalStatus.Active) revert ProposalNotActive();
        if (block.timestamp <= p.votingEndsAt) revert VotingNotEnded();
        
        uint256 requiredVoters = (totalVoters * _QUORUM_PERCENT) / 100;
        if (requiredVoters == 0) requiredVoters = 1;
        
        if (p.voterCount >= requiredVoters && p.votesFor > p.votesAgainst) {
            p.status = ProposalStatus.Approved;
            p.executionTime = block.timestamp + _EXECUTION_DELAY;
        } else {
            p.status = ProposalStatus.Rejected;
        }
        
        emit ProposalFinalized(proposalId, p.status);
    }
    
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        
        if (p.status != ProposalStatus.Approved) revert NotApproved();
        if (block.timestamp < p.executionTime) revert TooEarly();
        if (p.executed) revert AlreadyExecuted();
        
        p.executed = true;
        p.status = ProposalStatus.Executed;
        
        emit ProposalExecuted(proposalId);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    function getPoolInfo(uint256 poolId) external view returns (uint256 price, uint256 remaining, uint256 sold, PoolStatus status) {
        Pool storage p = pools[poolId];
        return (p.pricePerToken, p.tokensRemaining, p.tokensSold, p.status);
    }
    
    function getCurrentPrice() external view returns (uint256) {
        return pools[currentPool].pricePerToken;
    }
    
    function getToastStats() external view returns (uint256 virgin, uint256 bronze, uint256 charcoal, uint256 toasted) {
        return (totalVirgin, totalBronze, totalCharcoal, totalToasted);
    }
    
    function getBauleraStats() external view returns (uint256 virgin, uint256 bronze, uint256 charcoal, uint256 total) {
        return (bauleraVirgin, bauleraBronze, bauleraCharcoal, bauleraTotal);
    }
    
    function getVoters() external view returns (address[] memory) {
        return _voters;
    }
    
    function getProtectors() external view returns (address[] memory) {
        return _protectors;
    }
    
    function getActiveProposals() external view returns (uint256[] memory) {
        return _activeProposalIds;
    }
    
    function getBountiesBalance() external view returns (uint256) {
        return balanceOf(bountiesWallet);
    }
    
    function getToastHistoryLength() external view returns (uint256) {
        return toastHistory.length;
    }
    
    // ============================================
    // ADMIN
    // ============================================
    
    function setTreasuries(address _treasury, address _treasuryBit, address _primesMoney, address _realEstate) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_treasuryBit == address(0)) revert ZeroAddress();
        if (_primesMoney == address(0)) revert ZeroAddress();
        if (_realEstate == address(0)) revert ZeroAddress();
        
        treasury = _treasury;
        treasuryBit = _treasuryBit;
        primesMoney = _primesMoney;
        realEstate = _realEstate;
        
        emit TreasuriesUpdated(_treasury, _treasuryBit, _primesMoney, _realEstate);
    }
    
    function setBaulera(address _baulera) external onlyOwner notZeroAddress(_baulera) {
        address oldBaulera = baulera;
        
        uint256 bal = balanceOf(oldBaulera);
        if (bal != 0) {
            _transfer(oldBaulera, _baulera, bal);
        }
        
        baulera = _baulera;
        
        emit BauleraUpdated(oldBaulera, _baulera);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) {
            uint256 bal = address(this).balance;
            if (bal != 0) {
                (bool success,) = owner().call{value: bal}("");
                require(success, "BNB withdraw failed");
            }
        } else {
            if (token != address(USDC) && token != address(USDT)) revert OnlyStablecoins();
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal != 0) {
                IERC20(token).safeTransfer(owner(), bal);
            }
        }
    }
    
    receive() external payable {}
}
