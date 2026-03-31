// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ZykosToken V3 (ZKS) - THE TOASTER TOKEN
 * @author Clínica Psiquiátrica José Ingenieros
 * @notice Meme token con utilidad real - Psiquiatría On-Demand
 * 
 * V3 FEATURES:
 * - Sistema de Bounties con campañas y categorías
 * - Governance on-chain (Propuestas + Votación)
 * - Roles: HOLDER → VOTER ($20k) → PROTECTOR ($50k)
 * - 100M supply: 85M venta + 15M bounties
 * 
 * DISCLAIMER: MEME TOKEN. DYOR. NFA.
 * "Un proyecto psiquiátrico que se tostó al prestigio"
 */
contract ZykosTokenV3 is ERC20, Ownable2Step, ReentrancyGuard, Pausable {
    
    // ============================================
    // CONSTANTES
    // ============================================
    
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10**18;
    uint256 public constant BOUNTIES_ALLOCATION = 15_000_000 * 10**18;
    uint256 public constant SALE_ALLOCATION = 85_000_000 * 10**18;
    
    uint256 public constant POOL_COUNT = 100;
    uint256 public constant TOKENS_PER_POOL = 850_000 * 10**18;
    
    uint256 public constant MAX_PER_PURCHASE = 50_000 * 10**18;
    uint256 public constant COOLDOWN_PERIOD = 36000;
    uint256 public constant VOTE_THRESHOLD = 20_000 * 10**18;
    uint256 public constant PROTECTOR_THRESHOLD = 50_000 * 10**18;
    
    uint256 public constant ACTIVATION_PERCENT = 91;
    uint256 public constant RELEASE_PERCENT = 97;
    
    // Governance constants
    uint256 public constant PROPOSAL_THRESHOLD = 10_000 * 10**18;  // $10k para crear propuesta
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENT = 10;  // 10% de voters deben participar
    
    // ============================================
    // STABLECOINS BSC
    // ============================================
    
    IERC20 public immutable USDC;
    IERC20 public immutable USDT;
    
    // ============================================
    // TREASURY
    // ============================================
    
    address public treasury_50;
    address public treasury_25;
    address public treasury_12_5_A;
    address public treasury_12_5_B;
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
    // BUYER TRACKING & ROLES
    // ============================================
    
    mapping(address => uint256) public lastPurchaseTime;
    mapping(address => uint256) public totalPurchasedUSD;
    mapping(address => bool) public hasVotingRights;
    mapping(address => bool) public isProtector;
    
    address[] public voters;
    address[] public protectors;
    uint256 public totalVoters;
    uint256 public totalProtectors;
    
    // ============================================
    // BOUNTIES SYSTEM
    // ============================================
    
    enum BountyCategory { 
        SOCIAL,       // Twitter, Discord, etc.
        COMMUNITY,    // Moderadores, helpers
        DEVELOPER,    // Contribuciones técnicas
        PARTNERSHIP,  // Colaboraciones
        SPECIAL       // Casos especiales
    }
    
    struct BountyCampaign {
        string name;
        BountyCategory category;
        uint256 totalAllocation;
        uint256 distributed;
        uint256 perClaimAmount;
        uint256 maxClaims;
        uint256 claims;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool requiresVerification;
    }
    
    struct BountyRecord {
        address recipient;
        uint256 amount;
        BountyCategory category;
        uint256 campaignId;
        string reason;
        uint256 timestamp;
    }
    
    uint256 public campaignCount;
    mapping(uint256 => BountyCampaign) public campaigns;
    mapping(uint256 => mapping(address => bool)) public campaignClaimed;
    mapping(uint256 => mapping(address => bool)) public campaignVerified;
    
    BountyRecord[] public bountyHistory;
    mapping(address => uint256) public totalBountiesReceived;
    mapping(BountyCategory => uint256) public categoryDistributed;
    
    uint256 public totalBountiesDistributed;
    
    // ============================================
    // GOVERNANCE SYSTEM
    // ============================================
    
    enum ProposalStatus { 
        Pending,     // Esperando inicio
        Active,      // Votación activa
        Approved,    // Aprobada (esperando ejecución)
        Rejected,    // Rechazada
        Executed,    // Ejecutada
        Cancelled    // Cancelada
    }
    
    enum ProposalType {
        PARAMETER_CHANGE,    // Cambio de parámetros
        TREASURY_ALLOCATION, // Asignación de treasury
        BOUNTY_CAMPAIGN,     // Nueva campaña de bounties
        PARTNERSHIP,         // Propuesta de partnership
        COMMUNITY_ACTION,    // Acción comunitaria
        EMERGENCY            // Emergencia (solo protectors)
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        bytes callData;           // Datos para ejecutar
        address targetContract;   // Contrato objetivo (address(0) = este)
        
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 voterCount;
        
        uint256 createdAt;
        uint256 votingEndsAt;
        uint256 executionTime;    // Cuando se puede ejecutar
        
        ProposalStatus status;
        bool executed;
    }
    
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => bool)) public votedFor;
    
    uint256[] public activeProposalIds;
    
    // ============================================
    // STATS
    // ============================================
    
    uint256 public totalUSDRaised;
    uint256 public totalTokensSold;
    
    // ============================================
    // EVENTS - CORE
    // ============================================
    
    event TokensPurchased(
        address indexed buyer,
        uint256 tokenAmount,
        uint256 usdPaid,
        uint256 poolId,
        uint256 pricePerToken
    );
    
    event PoolActivated(uint256 indexed poolId, uint256 price, uint256 timestamp);
    event PoolExhausted(uint256 indexed poolId, uint256 timestamp);
    event VotingRightsGranted(address indexed voter, uint256 totalPurchased);
    event ProtectorGranted(address indexed protector, uint256 totalPurchased);
    event TreasuryUpdated(address t50, address t25, address t12A, address t12B);
    
    // ============================================
    // EVENTS - BOUNTIES
    // ============================================
    
    event BountyDistributed(
        address indexed recipient,
        uint256 amount,
        BountyCategory category,
        uint256 campaignId,
        string reason
    );
    
    event CampaignCreated(
        uint256 indexed campaignId,
        string name,
        BountyCategory category,
        uint256 allocation
    );
    
    event CampaignEnded(uint256 indexed campaignId, uint256 distributed);
    event BountyClaimed(uint256 indexed campaignId, address indexed claimer, uint256 amount);
    event UserVerified(uint256 indexed campaignId, address indexed user);
    
    // ============================================
    // EVENTS - GOVERNANCE
    // ============================================
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event ProposalStatusChanged(uint256 indexed proposalId, ProposalStatus status);
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyVoter() {
        require(hasVotingRights[msg.sender], "Not a voter");
        _;
    }
    
    modifier onlyProtector() {
        require(isProtector[msg.sender], "Not a protector");
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor(
        address _usdc,
        address _usdt,
        address _treasury50,
        address _treasury25,
        address _treasury12_5_A,
        address _treasury12_5_B,
        address _bountiesWallet
    ) ERC20("Zykos", "ZKS") Ownable(msg.sender) {
        require(_usdc != address(0) && _usdt != address(0), "Invalid stablecoin");
        require(
            _treasury50 != address(0) &&
            _treasury25 != address(0) &&
            _treasury12_5_A != address(0) &&
            _treasury12_5_B != address(0),
            "Invalid treasury"
        );
        require(_bountiesWallet != address(0), "Invalid bounties wallet");
        
        USDC = IERC20(_usdc);
        USDT = IERC20(_usdt);
        
        treasury_50 = _treasury50;
        treasury_25 = _treasury25;
        treasury_12_5_A = _treasury12_5_A;
        treasury_12_5_B = _treasury12_5_B;
        bountiesWallet = _bountiesWallet;
        
        _mint(address(this), SALE_ALLOCATION);
        _mint(_bountiesWallet, BOUNTIES_ALLOCATION);
        
        _initializePools();
        
        emit TreasuryUpdated(_treasury50, _treasury25, _treasury12_5_A, _treasury12_5_B);
    }
    
    // ============================================
    // POOL INITIALIZATION
    // ============================================
    
    function _initializePools() internal {
        uint256 basePrice = 50_000_000_000_000_000; // $0.05
        uint256 currentPrice = basePrice;
        
        uint256[23] memory increasePools = [
            uint256(3), 6, 9, 13, 17, 21, 22, 25, 29, 33,
            37, 43, 49, 57, 63, 75, 81, 83, 89, 91, 93, 95, 99
        ];
        
        uint256[23] memory increasePercents = [
            uint256(2), 5, 3, 4, 2, 6, 1, 3, 4, 3,
            5, 2, 7, 4, 3, 6, 2, 4, 3, 5, 2, 4, 8
        ];
        
        uint256 increaseIndex = 0;
        
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            if (increaseIndex < 23 && i == increasePools[increaseIndex]) {
                currentPrice = (currentPrice * (100 + increasePercents[increaseIndex])) / 100;
                increaseIndex++;
            }
            
            pools[i] = Pool({
                pricePerToken: currentPrice,
                tokensRemaining: TOKENS_PER_POOL,
                tokensSold: 0,
                status: i == 0 ? PoolStatus.Active : PoolStatus.Locked,
                activatedAt: i == 0 ? block.timestamp : 0
            });
        }
        
        emit PoolActivated(0, basePrice, block.timestamp);
    }
    
    // ============================================
    // BUY FUNCTIONS
    // ============================================
    
    function buyWithUSDC(uint256 usdAmount) external nonReentrant whenNotPaused {
        _buy(address(USDC), usdAmount);
    }
    
    function buyWithUSDT(uint256 usdAmount) external nonReentrant whenNotPaused {
        _buy(address(USDT), usdAmount);
    }
    
    function _buy(address stablecoin, uint256 usdAmount) internal {
        require(usdAmount > 0 && usdAmount <= MAX_PER_PURCHASE, "Invalid amount");
        require(
            block.timestamp >= lastPurchaseTime[msg.sender] + COOLDOWN_PERIOD,
            "Cooldown active"
        );
        require(currentPool < POOL_COUNT, "Sale ended");
        
        uint256 tokenAmount = _calculateTokens(usdAmount);
        require(tokenAmount > 0, "Zero tokens");
        require(balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");
        
        IERC20(stablecoin).transferFrom(msg.sender, address(this), usdAmount);
        
        _distributeTreasury(stablecoin, usdAmount);
        _updatePools(tokenAmount);
        _transfer(address(this), msg.sender, tokenAmount);
        
        totalUSDRaised += usdAmount;
        totalTokensSold += tokenAmount;
        totalPurchasedUSD[msg.sender] += usdAmount;
        lastPurchaseTime[msg.sender] = block.timestamp;
        
        _checkVotingRights(msg.sender);
        
        emit TokensPurchased(
            msg.sender,
            tokenAmount,
            usdAmount,
            currentPool,
            pools[currentPool].pricePerToken
        );
    }
    
    function _calculateTokens(uint256 usdAmount) internal view returns (uint256) {
        uint256 remainingUsd = usdAmount;
        uint256 totalTokens = 0;
        uint256 tempPool = currentPool;
        
        while (remainingUsd > 0 && tempPool < POOL_COUNT) {
            Pool storage pool = pools[tempPool];
            if (pool.tokensRemaining == 0) {
                tempPool++;
                continue;
            }
            
            uint256 tokensAtPrice = (remainingUsd * 10**18) / pool.pricePerToken;
            
            if (tokensAtPrice <= pool.tokensRemaining) {
                totalTokens += tokensAtPrice;
                remainingUsd = 0;
            } else {
                totalTokens += pool.tokensRemaining;
                uint256 usdUsed = (pool.tokensRemaining * pool.pricePerToken) / 10**18;
                remainingUsd -= usdUsed;
                tempPool++;
            }
        }
        
        return totalTokens;
    }
    
    function _updatePools(uint256 tokensToDeduct) internal {
        while (tokensToDeduct > 0 && currentPool < POOL_COUNT) {
            Pool storage pool = pools[currentPool];
            
            if (tokensToDeduct >= pool.tokensRemaining) {
                tokensToDeduct -= pool.tokensRemaining;
                pool.tokensSold += pool.tokensRemaining;
                pool.tokensRemaining = 0;
                pool.status = PoolStatus.Exhausted;
                
                emit PoolExhausted(currentPool, block.timestamp);
                
                if (currentPool + 1 < POOL_COUNT) {
                    currentPool++;
                    pools[currentPool].status = PoolStatus.Active;
                    pools[currentPool].activatedAt = block.timestamp;
                    emit PoolActivated(currentPool, pools[currentPool].pricePerToken, block.timestamp);
                }
            } else {
                pool.tokensRemaining -= tokensToDeduct;
                pool.tokensSold += tokensToDeduct;
                tokensToDeduct = 0;
                
                uint256 soldPercent = (pool.tokensSold * 100) / TOKENS_PER_POOL;
                if (soldPercent >= ACTIVATION_PERCENT && currentPool + 1 < POOL_COUNT) {
                    if (pools[currentPool + 1].status == PoolStatus.Locked) {
                        pools[currentPool + 1].status = PoolStatus.Active;
                        pools[currentPool + 1].activatedAt = block.timestamp;
                        emit PoolActivated(currentPool + 1, pools[currentPool + 1].pricePerToken, block.timestamp);
                    }
                }
            }
        }
    }
    
    function _distributeTreasury(address token, uint256 amount) internal {
        uint256 amount50 = (amount * 50) / 100;
        uint256 amount25 = (amount * 25) / 100;
        uint256 amount12_5 = (amount * 125) / 1000;
        
        IERC20(token).transfer(treasury_50, amount50);
        IERC20(token).transfer(treasury_25, amount25);
        IERC20(token).transfer(treasury_12_5_A, amount12_5);
        IERC20(token).transfer(treasury_12_5_B, amount - amount50 - amount25 - amount12_5);
    }
    
    // ============================================
    // ROLES SYSTEM
    // ============================================
    
    function _checkVotingRights(address buyer) internal {
        if (!hasVotingRights[buyer] && totalPurchasedUSD[buyer] >= VOTE_THRESHOLD) {
            hasVotingRights[buyer] = true;
            voters.push(buyer);
            totalVoters++;
            emit VotingRightsGranted(buyer, totalPurchasedUSD[buyer]);
        }
        
        if (!isProtector[buyer] && totalPurchasedUSD[buyer] >= PROTECTOR_THRESHOLD) {
            isProtector[buyer] = true;
            protectors.push(buyer);
            totalProtectors++;
            emit ProtectorGranted(buyer, totalPurchasedUSD[buyer]);
        }
    }
    
    function getVoters() external view returns (address[] memory) {
        return voters;
    }
    
    function getProtectors() external view returns (address[] memory) {
        return protectors;
    }
    
    function getAccountRoles(address account) external view returns (
        bool canVote,
        bool protectorStatus,
        uint256 totalSpent,
        uint256 untilVote,
        uint256 untilProtector
    ) {
        uint256 spent = totalPurchasedUSD[account];
        return (
            hasVotingRights[account],
            isProtector[account],
            spent,
            spent >= VOTE_THRESHOLD ? 0 : VOTE_THRESHOLD - spent,
            spent >= PROTECTOR_THRESHOLD ? 0 : PROTECTOR_THRESHOLD - spent
        );
    }
    
    // ============================================
    // BOUNTIES SYSTEM - CAMPAIGNS
    // ============================================
    
    function createCampaign(
        string calldata name,
        BountyCategory category,
        uint256 totalAllocation,
        uint256 perClaimAmount,
        uint256 maxClaims,
        uint256 durationDays,
        bool requiresVerification
    ) external onlyOwner returns (uint256) {
        require(totalAllocation > 0, "Zero allocation");
        require(balanceOf(bountiesWallet) >= totalAllocation, "Insufficient bounties");
        require(perClaimAmount > 0 && perClaimAmount <= totalAllocation, "Invalid claim amount");
        
        uint256 campaignId = campaignCount++;
        
        campaigns[campaignId] = BountyCampaign({
            name: name,
            category: category,
            totalAllocation: totalAllocation,
            distributed: 0,
            perClaimAmount: perClaimAmount,
            maxClaims: maxClaims,
            claims: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + (durationDays * 1 days),
            active: true,
            requiresVerification: requiresVerification
        });
        
        emit CampaignCreated(campaignId, name, category, totalAllocation);
        return campaignId;
    }
    
    function verifyUserForCampaign(
        uint256 campaignId,
        address user
    ) external onlyOwner {
        require(campaignId < campaignCount, "Invalid campaign");
        require(!campaignVerified[campaignId][user], "Already verified");
        
        campaignVerified[campaignId][user] = true;
        emit UserVerified(campaignId, user);
    }
    
    function batchVerifyUsers(
        uint256 campaignId,
        address[] calldata users
    ) external onlyOwner {
        require(campaignId < campaignCount, "Invalid campaign");
        
        for (uint256 i = 0; i < users.length; i++) {
            if (!campaignVerified[campaignId][users[i]]) {
                campaignVerified[campaignId][users[i]] = true;
                emit UserVerified(campaignId, users[i]);
            }
        }
    }
    
    function claimBounty(uint256 campaignId) external nonReentrant {
        BountyCampaign storage campaign = campaigns[campaignId];
        
        require(campaign.active, "Campaign not active");
        require(block.timestamp <= campaign.endTime, "Campaign ended");
        require(!campaignClaimed[campaignId][msg.sender], "Already claimed");
        require(campaign.claims < campaign.maxClaims, "Max claims reached");
        require(
            campaign.distributed + campaign.perClaimAmount <= campaign.totalAllocation,
            "Allocation exhausted"
        );
        
        if (campaign.requiresVerification) {
            require(campaignVerified[campaignId][msg.sender], "Not verified");
        }
        
        campaignClaimed[campaignId][msg.sender] = true;
        campaign.claims++;
        campaign.distributed += campaign.perClaimAmount;
        
        _transfer(bountiesWallet, msg.sender, campaign.perClaimAmount);
        
        totalBountiesDistributed += campaign.perClaimAmount;
        totalBountiesReceived[msg.sender] += campaign.perClaimAmount;
        categoryDistributed[campaign.category] += campaign.perClaimAmount;
        
        bountyHistory.push(BountyRecord({
            recipient: msg.sender,
            amount: campaign.perClaimAmount,
            category: campaign.category,
            campaignId: campaignId,
            reason: campaign.name,
            timestamp: block.timestamp
        }));
        
        emit BountyClaimed(campaignId, msg.sender, campaign.perClaimAmount);
    }
    
    function endCampaign(uint256 campaignId) external onlyOwner {
        BountyCampaign storage campaign = campaigns[campaignId];
        require(campaign.active, "Already ended");
        
        campaign.active = false;
        emit CampaignEnded(campaignId, campaign.distributed);
    }
    
    // Manual bounty distribution (sin campaña)
    function distributeBounty(
        address to,
        uint256 amount,
        BountyCategory category,
        string calldata reason
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(balanceOf(bountiesWallet) >= amount, "Insufficient bounties");
        
        _transfer(bountiesWallet, to, amount);
        
        totalBountiesDistributed += amount;
        totalBountiesReceived[to] += amount;
        categoryDistributed[category] += amount;
        
        bountyHistory.push(BountyRecord({
            recipient: to,
            amount: amount,
            category: category,
            campaignId: type(uint256).max, // Sin campaña
            reason: reason,
            timestamp: block.timestamp
        }));
        
        emit BountyDistributed(to, amount, category, type(uint256).max, reason);
    }
    
    function batchDistributeBounty(
        address[] calldata recipients,
        uint256[] calldata amounts,
        BountyCategory category,
        string calldata reason
    ) external onlyOwner {
        require(recipients.length == amounts.length, "Length mismatch");
        
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(balanceOf(bountiesWallet) >= total, "Insufficient bounties");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] != address(0) && amounts[i] > 0) {
                _transfer(bountiesWallet, recipients[i], amounts[i]);
                
                totalBountiesDistributed += amounts[i];
                totalBountiesReceived[recipients[i]] += amounts[i];
                categoryDistributed[category] += amounts[i];
                
                bountyHistory.push(BountyRecord({
                    recipient: recipients[i],
                    amount: amounts[i],
                    category: category,
                    campaignId: type(uint256).max,
                    reason: reason,
                    timestamp: block.timestamp
                }));
                
                emit BountyDistributed(recipients[i], amounts[i], category, type(uint256).max, reason);
            }
        }
    }
    
    // ============================================
    // GOVERNANCE SYSTEM
    // ============================================
    
    function createProposal(
        ProposalType proposalType,
        string calldata title,
        string calldata description,
        bytes calldata callData,
        address targetContract
    ) external onlyVoter returns (uint256) {
        require(
            totalPurchasedUSD[msg.sender] >= PROPOSAL_THRESHOLD,
            "Insufficient stake to propose"
        );
        require(bytes(title).length > 0, "Empty title");
        
        // Emergency proposals solo protectors
        if (proposalType == ProposalType.EMERGENCY) {
            require(isProtector[msg.sender], "Only protectors for emergency");
        }
        
        uint256 proposalId = proposalCount++;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            title: title,
            description: description,
            callData: callData,
            targetContract: targetContract == address(0) ? address(this) : targetContract,
            votesFor: 0,
            votesAgainst: 0,
            voterCount: 0,
            createdAt: block.timestamp,
            votingEndsAt: block.timestamp + VOTING_PERIOD,
            executionTime: 0,
            status: ProposalStatus.Active,
            executed: false
        });
        
        activeProposalIds.push(proposalId);
        
        emit ProposalCreated(proposalId, msg.sender, proposalType, title);
        return proposalId;
    }
    
    function vote(uint256 proposalId, bool support) external onlyVoter {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Active, "Not active");
        require(block.timestamp <= proposal.votingEndsAt, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        hasVoted[proposalId][msg.sender] = true;
        votedFor[proposalId][msg.sender] = support;
        
        // Peso del voto basado en USD gastado (capped at MAX_PER_PURCHASE)
        uint256 weight = totalPurchasedUSD[msg.sender];
        if (weight > MAX_PER_PURCHASE) {
            weight = MAX_PER_PURCHASE;
        }
        
        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }
        proposal.voterCount++;
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    function finalizeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Active, "Not active");
        require(block.timestamp > proposal.votingEndsAt, "Voting not ended");
        
        // Calcular quorum (10% de totalVoters deben haber votado)
        uint256 requiredVoters = (totalVoters * QUORUM_PERCENT) / 100;
        if (requiredVoters == 0) requiredVoters = 1;
        
        bool quorumReached = proposal.voterCount >= requiredVoters;
        bool approved = proposal.votesFor > proposal.votesAgainst;
        
        if (quorumReached && approved) {
            proposal.status = ProposalStatus.Approved;
            proposal.executionTime = block.timestamp + EXECUTION_DELAY;
            emit ProposalStatusChanged(proposalId, ProposalStatus.Approved);
        } else {
            proposal.status = ProposalStatus.Rejected;
            emit ProposalStatusChanged(proposalId, ProposalStatus.Rejected);
        }
        
        // Remover de activas
        _removeFromActiveProposals(proposalId);
    }
    
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Approved, "Not approved");
        require(block.timestamp >= proposal.executionTime, "Too early");
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        proposal.status = ProposalStatus.Executed;
        
        // Ejecutar callData si existe
        if (proposal.callData.length > 0) {
            (bool success,) = proposal.targetContract.call(proposal.callData);
            require(success, "Execution failed");
        }
        
        emit ProposalExecuted(proposalId);
        emit ProposalStatusChanged(proposalId, ProposalStatus.Executed);
    }
    
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized"
        );
        require(
            proposal.status == ProposalStatus.Active || 
            proposal.status == ProposalStatus.Approved,
            "Cannot cancel"
        );
        
        proposal.status = ProposalStatus.Cancelled;
        _removeFromActiveProposals(proposalId);
        
        emit ProposalCancelled(proposalId);
        emit ProposalStatusChanged(proposalId, ProposalStatus.Cancelled);
    }
    
    function _removeFromActiveProposals(uint256 proposalId) internal {
        for (uint256 i = 0; i < activeProposalIds.length; i++) {
            if (activeProposalIds[i] == proposalId) {
                activeProposalIds[i] = activeProposalIds[activeProposalIds.length - 1];
                activeProposalIds.pop();
                break;
            }
        }
    }
    
    // ============================================
    // VIEW FUNCTIONS - GOVERNANCE
    // ============================================
    
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        ProposalType proposalType,
        string memory title,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 voterCount,
        ProposalStatus status,
        uint256 votingEndsAt
    ) {
        Proposal storage p = proposals[proposalId];
        return (
            p.proposer,
            p.proposalType,
            p.title,
            p.votesFor,
            p.votesAgainst,
            p.voterCount,
            p.status,
            p.votingEndsAt
        );
    }
    
    function getActiveProposals() external view returns (uint256[] memory) {
        return activeProposalIds;
    }
    
    function getVoteInfo(
        uint256 proposalId,
        address voter
    ) external view returns (bool voted, bool support) {
        return (hasVoted[proposalId][voter], votedFor[proposalId][voter]);
    }
    
    // ============================================
    // VIEW FUNCTIONS - BOUNTIES
    // ============================================
    
    function getCampaign(uint256 campaignId) external view returns (
        string memory name,
        BountyCategory category,
        uint256 totalAllocation,
        uint256 distributed,
        uint256 claims,
        uint256 maxClaims,
        bool active,
        uint256 endTime
    ) {
        BountyCampaign storage c = campaigns[campaignId];
        return (
            c.name,
            c.category,
            c.totalAllocation,
            c.distributed,
            c.claims,
            c.maxClaims,
            c.active,
            c.endTime
        );
    }
    
    function canClaimBounty(
        uint256 campaignId,
        address user
    ) external view returns (bool canClaim, string memory reason) {
        BountyCampaign storage campaign = campaigns[campaignId];
        
        if (!campaign.active) return (false, "Campaign not active");
        if (block.timestamp > campaign.endTime) return (false, "Campaign ended");
        if (campaignClaimed[campaignId][user]) return (false, "Already claimed");
        if (campaign.claims >= campaign.maxClaims) return (false, "Max claims reached");
        if (campaign.requiresVerification && !campaignVerified[campaignId][user]) {
            return (false, "Not verified");
        }
        
        return (true, "Eligible");
    }
    
    function getBountyHistory(uint256 start, uint256 count) external view returns (
        BountyRecord[] memory records
    ) {
        uint256 end = start + count;
        if (end > bountyHistory.length) end = bountyHistory.length;
        
        records = new BountyRecord[](end - start);
        for (uint256 i = start; i < end; i++) {
            records[i - start] = bountyHistory[i];
        }
        return records;
    }
    
    function getBountiesBalance() external view returns (uint256) {
        return balanceOf(bountiesWallet);
    }
    
    function getBountyStats() external view returns (
        uint256 totalDistributed,
        uint256 remaining,
        uint256 socialDistributed,
        uint256 communityDistributed,
        uint256 developerDistributed,
        uint256 partnershipDistributed,
        uint256 specialDistributed
    ) {
        return (
            totalBountiesDistributed,
            balanceOf(bountiesWallet),
            categoryDistributed[BountyCategory.SOCIAL],
            categoryDistributed[BountyCategory.COMMUNITY],
            categoryDistributed[BountyCategory.DEVELOPER],
            categoryDistributed[BountyCategory.PARTNERSHIP],
            categoryDistributed[BountyCategory.SPECIAL]
        );
    }
    
    // ============================================
    // VIEW FUNCTIONS - POOLS
    // ============================================
    
    function getPoolInfo(uint256 poolId) external view returns (
        uint256 price,
        uint256 remaining,
        uint256 sold,
        PoolStatus status,
        uint256 percentSold
    ) {
        require(poolId < POOL_COUNT, "Invalid pool");
        Pool storage pool = pools[poolId];
        uint256 percent = pool.tokensSold > 0 ? (pool.tokensSold * 100) / TOKENS_PER_POOL : 0;
        return (pool.pricePerToken, pool.tokensRemaining, pool.tokensSold, pool.status, percent);
    }
    
    function getCurrentPrice() external view returns (uint256) {
        return pools[currentPool].pricePerToken;
    }
    
    function calculatePurchase(uint256 usdAmount) external view returns (
        uint256 tokens,
        uint256 effectivePrice
    ) {
        tokens = _calculateTokens(usdAmount);
        effectivePrice = tokens > 0 ? (usdAmount * 10**18) / tokens : 0;
        return (tokens, effectivePrice);
    }
    
    function getBuyerInfo(address buyer) external view returns (
        uint256 totalSpent,
        uint256 lastPurchase,
        bool canVote,
        bool protectorStatus,
        uint256 cooldownEnds,
        uint256 bountiesReceived
    ) {
        return (
            totalPurchasedUSD[buyer],
            lastPurchaseTime[buyer],
            hasVotingRights[buyer],
            isProtector[buyer],
            lastPurchaseTime[buyer] + COOLDOWN_PERIOD,
            totalBountiesReceived[buyer]
        );
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    function setTreasury(
        address _t50,
        address _t25,
        address _t12A,
        address _t12B
    ) external onlyOwner {
        require(_t50 != address(0) && _t25 != address(0), "Invalid address");
        require(_t12A != address(0) && _t12B != address(0), "Invalid address");
        
        treasury_50 = _t50;
        treasury_25 = _t25;
        treasury_12_5_A = _t12A;
        treasury_12_5_B = _t12B;
        
        emit TreasuryUpdated(_t50, _t25, _t12A, _t12B);
    }
    
    function setBountiesWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid address");
        uint256 remaining = balanceOf(bountiesWallet);
        if (remaining > 0) {
            _transfer(bountiesWallet, newWallet, remaining);
        }
        bountiesWallet = newWallet;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(token == address(USDC) || token == address(USDT), "Only stablecoins");
        IERC20(token).transfer(owner(), balance);
    }

    // ============================================
    // AIRDROP SYSTEM
    // ============================================

    uint256 public airdropAmount = 500 * 10**18;
    bool public airdropActive = false;
    mapping(address => bool) public hasClaimedAirdrop;
    uint256 public totalAirdropClaimed;

    event AirdropClaimed(address indexed claimer, uint256 amount);
    event AirdropStatusChanged(bool active);
    event AirdropAmountChanged(uint256 newAmount);

    function claimAirdrop() external nonReentrant whenNotPaused {
        require(airdropActive, "Airdrop not active");
        require(!hasClaimedAirdrop[msg.sender], "Already claimed");
        require(balanceOf(bountiesWallet) >= airdropAmount, "Airdrop depleted");

        hasClaimedAirdrop[msg.sender] = true;
        totalAirdropClaimed += airdropAmount;

        _transfer(bountiesWallet, msg.sender, airdropAmount);

        emit AirdropClaimed(msg.sender, airdropAmount);
    }

    function setAirdropActive(bool _active) external onlyOwner {
        airdropActive = _active;
        emit AirdropStatusChanged(_active);
    }

    function setAirdropAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be > 0");
        airdropAmount = _amount;
        emit AirdropAmountChanged(_amount);
    }
}
