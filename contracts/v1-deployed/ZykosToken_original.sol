// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract ZykosToken is ERC20, Ownable, ReentrancyGuard, Pausable {
    
    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10**18;
    uint256 public constant TOKENS_PER_POOL = 1_000_000 * 10**18;
    uint256 public constant POOL_COUNT = 100;
    uint256 public constant MAX_PER_PURCHASE = 50_000 * 10**6;
    uint256 public constant COOLDOWN_PERIOD = 8400 seconds;
    uint256 public constant ACTIVATION_THRESHOLD = 91;
    uint256 public constant RELEASE_THRESHOLD = 97;
    
    IERC20 public immutable USDC;
    IERC20 public immutable USDT;

    address public treasury_50;
    address public treasury_25;
    address public treasury_12_5_A;
    address public treasury_12_5_B;
    
    uint256 public currentPoolId;
    
    enum PoolStatus { INACTIVE, ACTIVE, RELEASED, COMPLETED }
    enum PaymentToken { USDC, USDT }
    enum BatchColor { VIRGIN, BRONZE, CHARCOAL }
    
    struct Pool {
        uint256 pricePerToken;
        uint256 tokensRemaining;
        uint256 tokensSold;
        PoolStatus status;
    }
    
    struct ServiceBatch {
        uint256 batchId;
        uint256 tokenAmount;
        uint256 usdValue;
        BatchColor color;
        uint256 timesReused;
        uint256 timestamp;
    }
    
    mapping(uint256 => Pool) public pools;
    mapping(address => uint256) public lastPurchaseTime;
    mapping(address => uint256) public totalPurchasedUSD;
    mapping(address => uint256) public purchaseCount;
    mapping(uint256 => ServiceBatch) public serviceBatches;
    uint256 public nextBatchId;
    
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 paymentAmount, PaymentToken paymentMethod, uint256 poolId);
    event PoolStatusChanged(uint256 indexed poolId, PoolStatus oldStatus, PoolStatus newStatus, uint256 percentSold, uint256 timestamp);
    event BatchCreated(uint256 indexed batchId, uint256 tokenAmount, uint256 usdValue, uint256 timestamp);
    event BatchReused(uint256 indexed batchId, uint256 timesReused, BatchColor newColor);
    event CosmicDonation(address indexed token, uint256 amount, uint256 timestamp);
    event TreasuryUpdated(address treasury50, address treasury25, address treasury12_5_A, address treasury12_5_B);

    constructor(
        address _usdc, 
        address _usdt, 
        address _treasury50,
        address _treasury25,
        address _treasury12_5_A,
        address _treasury12_5_B
    ) ERC20("Zykos", "ZKS") Ownable(msg.sender) { 
        require(_usdc != address(0) && _usdt != address(0), "Invalid stablecoin");
        require(_treasury50 != address(0) && _treasury25 != address(0) && _treasury12_5_A != address(0) && _treasury12_5_B != address(0), "Invalid treasury");

        USDC = IERC20(_usdc);
        USDT = IERC20(_usdt);
        
        treasury_50 = _treasury50;
        treasury_25 = _treasury25;
        treasury_12_5_A = _treasury12_5_A;
        treasury_12_5_B = _treasury12_5_B;
        emit TreasuryUpdated(_treasury50, _treasury25, _treasury12_5_A, _treasury12_5_B);

        _mint(address(this), TOTAL_SUPPLY);
        _initializePools();
    }
    
    function _initializePools() internal {
        uint256 basePrice = 50_000;
        uint256 currentPrice = basePrice;
        
        uint256[23] memory increasePools = [uint256(3), 6, 9, 13, 17, 21, 22, 25, 29, 33, 37, 43, 49, 57, 63, 75, 81, 83, 89, 91, 93, 95, 99];
        uint256[23] memory increasePercents = [uint256(2), 5, 3, 4, 2, 6, 1, 3, 4, 3, 5, 2, 7, 4, 3, 6, 2, 4, 3, 5, 2, 4, 8];
        
        uint256 increaseIndex = 0;
        
        for (uint256 i = 0; i < POOL_COUNT; ++i) {
            if (increaseIndex < increasePools.length && i == increasePools[increaseIndex]) {
                currentPrice = (currentPrice * (100 + increasePercents[increaseIndex])) / 100;
                ++increaseIndex;
            }
            
            pools[i] = Pool({
                pricePerToken: currentPrice,
                tokensRemaining: TOKENS_PER_POOL,
                tokensSold: 0,
                status: i == 0 ? PoolStatus.ACTIVE : PoolStatus.INACTIVE
            });
        }
    }
    
    function buyWithUSDC(uint256 tokenAmount) external nonReentrant whenNotPaused {
        uint256 usdcAmount = _calculatePayment(tokenAmount);
        _checkPurchaseLimits(msg.sender, usdcAmount);
        
        uint256 balanceBefore = USDC.balanceOf(address(this));
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);
        uint256 receivedAmount = USDC.balanceOf(address(this)) - balanceBefore;

        _processPurchase(msg.sender, tokenAmount, receivedAmount, PaymentToken.USDC);
    }
    
    function buyWithUSDT(uint256 tokenAmount) external nonReentrant whenNotPaused {
        uint256 usdtAmount = _calculatePayment(tokenAmount);
        _checkPurchaseLimits(msg.sender, usdtAmount);

        uint256 balanceBefore = USDT.balanceOf(address(this));
        USDT.safeTransferFrom(msg.sender, address(this), usdtAmount);
        uint256 receivedAmount = USDT.balanceOf(address(this)) - balanceBefore;
        
        _processPurchase(msg.sender, tokenAmount, receivedAmount, PaymentToken.USDT);
    }
    
    function _calculatePayment(uint256 tokenAmount) internal view returns (uint256) {
        Pool memory pool = pools[currentPoolId];
        require(pool.status == PoolStatus.ACTIVE, "Pool not active");
        require(tokenAmount > 0, "Amount must be > 0"); 
        require(tokenAmount <= pool.tokensRemaining, "Invalid amount");
        return (tokenAmount * pool.pricePerToken) / 10**18;
    }
    
    function _checkPurchaseLimits(address buyer, uint256 paymentAmount) internal view {
        require(paymentAmount <= MAX_PER_PURCHASE, "Max $50k per purchase");
        require(paymentAmount > 0, "Amount must be > 0");
        
        if (lastPurchaseTime[buyer] > 0) {
            require(block.timestamp >= lastPurchaseTime[buyer] + COOLDOWN_PERIOD, "Wait 8400 seconds");
        }
    }
    
    function _processPurchase(address buyer, uint256 tokenAmount, uint256 receivedAmount, PaymentToken method) internal {
        uint256 amount50 = (receivedAmount * 5000) / 10000;
        uint256 amount25 = (receivedAmount * 2500) / 10000;
        uint256 amount12_5 = (receivedAmount * 1250) / 10000;
        uint256 remainder = receivedAmount - amount50 - amount25 - amount12_5 - amount12_5;
        
        IERC20 stablecoin = (method == PaymentToken.USDC) ? USDC : USDT;

        stablecoin.safeTransfer(treasury_50, amount50 + remainder);
        stablecoin.safeTransfer(treasury_25, amount25);
        stablecoin.safeTransfer(treasury_12_5_A, amount12_5);
        stablecoin.safeTransfer(treasury_12_5_B, amount12_5);
        
        Pool storage pool = pools[currentPoolId];
        _transfer(address(this), buyer, tokenAmount);
        pool.tokensRemaining -= tokenAmount;
        pool.tokensSold += tokenAmount;
        lastPurchaseTime[buyer] = block.timestamp;
        totalPurchasedUSD[buyer] += receivedAmount;
        purchaseCount[buyer]++;
        
        emit TokensPurchased(buyer, tokenAmount, receivedAmount, method, currentPoolId);
        _checkAndAdvancePool();
    }
    
    function _checkAndAdvancePool() internal {
        Pool storage currentPool = pools[currentPoolId];
        uint256 percentSold = (currentPool.tokensSold * 100) / TOKENS_PER_POOL;
        
        if (percentSold >= ACTIVATION_THRESHOLD && currentPoolId + 1 < POOL_COUNT) {
            Pool storage nextPool = pools[currentPoolId + 1];
            if (nextPool.status == PoolStatus.INACTIVE) {
                PoolStatus oldStatus = nextPool.status;
                nextPool.status = PoolStatus.ACTIVE;
                emit PoolStatusChanged(currentPoolId + 1, oldStatus, PoolStatus.ACTIVE, 0, block.timestamp);
            }
        }
        
        if (percentSold >= RELEASE_THRESHOLD && currentPoolId + 1 < POOL_COUNT) {
            Pool storage nextPool = pools[currentPoolId + 1];
            if (nextPool.status == PoolStatus.ACTIVE) {
                PoolStatus oldStatus = nextPool.status;
                nextPool.status = PoolStatus.RELEASED;
                emit PoolStatusChanged(currentPoolId + 1, oldStatus, PoolStatus.RELEASED, 0, block.timestamp);
            }
        }
        
        if (currentPool.tokensRemaining == 0 && currentPool.status != PoolStatus.COMPLETED) {
            PoolStatus oldStatus = currentPool.status;
            currentPool.status = PoolStatus.COMPLETED;
            emit PoolStatusChanged(currentPoolId, oldStatus, PoolStatus.COMPLETED, 100, block.timestamp);
            
            if (currentPoolId + 1 < POOL_COUNT) {
                currentPoolId++;
                if (pools[currentPoolId].status == PoolStatus.INACTIVE) {
                    pools[currentPoolId].status = PoolStatus.ACTIVE;
                    emit PoolStatusChanged(currentPoolId, PoolStatus.INACTIVE, PoolStatus.ACTIVE, 0, block.timestamp);
                }
            }
        }
    }
    
    function recordBatch(uint256 amount, uint256 usdValue) external onlyOwner {
        serviceBatches[nextBatchId] = ServiceBatch(nextBatchId, amount, usdValue, BatchColor.VIRGIN, 0, block.timestamp);
        emit BatchCreated(nextBatchId, amount, usdValue, block.timestamp);
        nextBatchId++;
    }
    
    function markBatchReused(uint256 batchId) external onlyOwner {
        ServiceBatch storage batch = serviceBatches[batchId];
        require(batch.tokenAmount > 0, "Batch doesn't exist");
        batch.timesReused++;
        if (batch.timesReused >= 5) batch.color = BatchColor.CHARCOAL;
        else if (batch.timesReused >= 2) batch.color = BatchColor.BRONZE;
        emit BatchReused(batchId, batch.timesReused, batch.color);
    }
    
    function getBatchInfo(uint256 batchId) external view returns (uint256, uint256, string memory, uint256, uint256) {
        ServiceBatch memory batch = serviceBatches[batchId];
        string memory color;
        if (batch.color == BatchColor.VIRGIN) color = "Virgin";
        else if (batch.color == BatchColor.BRONZE) color = "Bronze";
        else color = "Charcoal";
        return (batch.tokenAmount, batch.usdValue, color, batch.timesReused, batch.timestamp);
    }
    
    function collectCosmicDonations(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Invalid address");
        IERC20(tokenAddress).safeTransfer(treasury_50, amount);
        emit CosmicDonation(tokenAddress, amount, block.timestamp);
    }
    
    function collectCosmicZKS(uint256 amount) external onlyOwner {
        _transfer(address(this), treasury_50, amount);
        emit CosmicDonation(address(this), amount, block.timestamp);
    }
    
    function getPool(uint256 poolId) external view returns (uint256, uint256, uint256, PoolStatus, uint256) {
        Pool memory pool = pools[poolId];
        uint256 percent = pool.tokensSold > 0 ? (pool.tokensSold * 100) / TOKENS_PER_POOL : 0;
        return (pool.pricePerToken, pool.tokensRemaining, pool.tokensSold, pool.status, percent);
    }
    
    function calculatePrice(uint256 tokenAmount) external view returns (uint256) {
        return _calculatePayment(tokenAmount);
    }
    
    function getTotalSold() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < POOL_COUNT; ++i) {
            total += pools[i].tokensSold;
        }
        return total;
    }
    
    function getBatchCountByColor() external view returns (uint256 virgin, uint256 bronze, uint256 charcoal) {
        uint256 v = 0;
        uint256 b = 0;
        uint256 c = 0;
        for (uint256 i = 0; i < nextBatchId; ++i) {
            if (serviceBatches[i].color == BatchColor.VIRGIN) v++;
            else if (serviceBatches[i].color == BatchColor.BRONZE) b++;
            else c++;
        }
        return (v, b, c);
    }
    
    function setTreasuries(
        address _treasury50,
        address _treasury25,
        address _treasury12_5_A,
        address _treasury12_5_B
    ) external onlyOwner {
        require(_treasury50 != address(0) && _treasury25 != address(0) && _treasury12_5_A != address(0) && _treasury12_5_B != address(0), "Invalid treasury");
        
        treasury_50 = _treasury50;
        treasury_25 = _treasury25;
        treasury_12_5_A = _treasury12_5_A;
        treasury_12_5_B = _treasury12_5_B;
        
        emit TreasuryUpdated(_treasury50, _treasury25, _treasury12_5_A, _treasury12_5_B);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}
