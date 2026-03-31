// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ZykosVoucher V2 (ZKS-X) - Institutional Voucher Token
 * @author Clínica Psiquiátrica José Ingenieros S.R.L.
 * @notice Non-transferable voucher - "Dólar Monopoly" del ecosistema ZYKOS
 * 
 * ══════════════════════════════════════════════════════════════════════════════
 *                              FILOSOFÍA ZKS-X
 * ══════════════════════════════════════════════════════════════════════════════
 * 
 * ZKS-X es al ZKS lo que el dólar Monopoly es al dólar real:
 * 
 * ┌────────────────────────────────────────────────────────────────────────────┐
 * │  • Valor SIMBÓLICO referenciado al ZKS real en mercado abierto            │
 * │  • Precio fijado por SERVICIO en contrato, NO por oferta/demanda          │
 * │  • Solo válido dentro del portal institucional asignado                   │
 * │  • No intercambiable en mercado abierto                                   │
 * │  • Al completar ciclo (burn), métricas retroalimentan ecosistema          │
 * └────────────────────────────────────────────────────────────────────────────┘
 * 
 * "A los reacios denle pan con manteca, ya creerán"
 * El valor se demuestra en el USO, no en la especulación.
 * 
 * ══════════════════════════════════════════════════════════════════════════════
 *                         RELACIÓN CON ZKS PRINCIPAL
 * ══════════════════════════════════════════════════════════════════════════════
 * 
 * CICLO 0 - VENTA PRIMARIA ZKS:
 * ┌─────────────────────────────────────────────────────────────────────────────┐
 * │ DEPLOY ZKS → 100M creados (evento único)                                   │
 * │   ├→ 85M → Contract (pools de venta)                                       │
 * │   └→ 15M → Bounties wallet (airdrops, expansión)                          │
 * │                                                                            │
 * │ Pool N activo:                                                             │
 * │   ├→ 93% vendido → Pool N+1 se despliega a VAULT (preparado)              │
 * │   └→ 98% vendido → Pool N+1 se LIBERA a venta (IRREVERSIBLE)              │
 * │                                                                            │
 * │ Dinero entrada → TREASURY SPLIT automático (ver abajo)                    │
 * └─────────────────────────────────────────────────────────────────────────────┘
 * 
 * POST-CICLO 0 - TOAST SYSTEM:
 * ┌─────────────────────────────────────────────────────────────────────────────┐
 * │ Servicio usado → ZKS → Baulera (VIRGIN)                                    │
 * │                            ↓ toast                                         │
 * │                          BRONZE                                            │
 * │                            ↓ toast                                         │
 * │                         CHARCOAL → disponible para re-venta                │
 * └─────────────────────────────────────────────────────────────────────────────┘
 * 
 * ══════════════════════════════════════════════════════════════════════════════
 *                          DISTRIBUCIÓN TREASURY
 * ══════════════════════════════════════════════════════════════════════════════
 * 
 * DINERO ENTRADA (USDT/USDC/BNB):
 * ┌─────────────────────────────────────────────────────────────────────────────┐
 * │  TREASURY (50%)      → Uso inmediato operativo                             │
 * │  TREASURYBIT (25%)   → Compra BTC directo desde contrato                  │
 * │  PRIMESMONEY (12.5%) → Premios/salarios/bonos/recapitalización            │
 * │  RESCUEMONEY (12.5%) → Emergencias (disposición por votación governance)  │
 * └─────────────────────────────────────────────────────────────────────────────┘
 * 
 * Nota: Bounties (15M ZKS) no reclamadas → airdrop para expansión
 * "Para quienes demuestren interés o para quienes no"
 * 
 * ══════════════════════════════════════════════════════════════════════════════
 *                        SUPERVISIÓN PROFESIONAL ÍNTEGRA
 *                                  NO BOTS
 * ══════════════════════════════════════════════════════════════════════════════
 */

interface IZykosToken {
    function balanceOf(address account) external view returns (uint256);
    function getCurrentPrice() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function currentPool() external view returns (uint256);
}

contract ZykosVoucherV2 is ERC20, Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ═══════════════════════════════════════════════════════════════
    // CUSTOM ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    error ZeroAddress();
    error ZeroAmount();
    error TransferBlocked();
    error NotPortal();
    error NotProfessional();
    error ServiceNotFound();
    error ServiceInactive();
    error InsufficientVouchers();
    error InvalidServiceCost();
    error PackNotFound();
    error PackInactive();
    error AlreadyInitialized();
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Valor simbólico base: 1 ZKS-X ≈ $0.01 referencial
    uint256 public constant SYMBOLIC_USD_VALUE = 1e16;
    
    /// @notice Distribución treasury (en basis points, 10000 = 100%)
    uint256 public constant TREASURY_BPS = 5000;      // 50%
    uint256 public constant TREASURYBIT_BPS = 2500;   // 25%
    uint256 public constant PRIMESMONEY_BPS = 1250;   // 12.5%
    uint256 public constant RESCUEMONEY_BPS = 1250;   // 12.5%
    
    uint256 private constant BPS_DIVISOR = 10000;
    uint256 private constant PRECISION = 1e18;
    
    // ═══════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════
    
    struct ServiceDefinition {
        string name;
        string category;
        uint256 zkxCost;          // Costo FIJO en ZKS-X (valor del servicio)
        uint256 usdReference;     // Referencia USD informativa
        uint256 usageCount;
        uint256 totalBurned;
        bool active;
        uint256 createdAt;
    }
    
    struct InstitutionalPack {
        string name;
        uint256 zkxAmount;
        uint256 priceUSD;         // 18 decimals
        uint256 validityDays;
        uint256 purchaseCount;
        bool active;
    }
    
    struct UsageRecord {
        uint256 serviceId;
        uint256 zkxBurned;
        uint256 timestamp;
        address professional;
        bytes32 patientHash;      // Privacidad HIPAA
    }
    
    struct PackPurchase {
        uint256 packId;
        uint256 zkxReceived;
        uint256 usdPaid;
        uint256 purchasedAt;
        uint256 expiresAt;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // IMMUTABLES
    // ═══════════════════════════════════════════════════════════════
    
    string public institutionCode;
    string public institutionName;
    
    IZykosToken public immutable ZKS_MAIN;
    IERC20 public immutable PAYMENT_TOKEN;
    uint8 public immutable PAYMENT_DECIMALS;
    
    // ═══════════════════════════════════════════════════════════════
    // TREASURY ADDRESSES (same structure as ZKS main)
    // ═══════════════════════════════════════════════════════════════
    
    address public treasury;          // 50% - Uso inmediato
    address public treasuryBit;       // 25% - Compra BTC
    address public primesMoney;       // 12.5% - Premios/bonos
    address public rescueMoney;       // 12.5% - Emergencias (votación)
    
    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════
    
    address public portal;
    
    mapping(uint256 => ServiceDefinition) public services;
    uint256 public serviceCount;
    
    mapping(uint256 => InstitutionalPack) public packs;
    uint256 public packCount;
    
    UsageRecord[] public usageHistory;
    PackPurchase[] public purchases;
    
    mapping(address => bool) public isProfessional;
    mapping(address => uint256) public professionalServiceCount;
    address[] private _professionals;
    
    uint256 public totalBurned;
    uint256 public totalMinted;
    uint256 public totalUSDReceived;
    
    // Treasury tracking
    uint256 public totalToTreasury;
    uint256 public totalToTreasuryBit;
    uint256 public totalToPrimesMoney;
    uint256 public totalToRescueMoney;
    
    bool private _initialized;
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event ServiceDefined(uint256 indexed serviceId, string name, uint256 zkxCost);
    event ServiceUsed(uint256 indexed serviceId, uint256 zkxBurned, address indexed professional, bytes32 patientHash);
    event PackDefined(uint256 indexed packId, string name, uint256 zkxAmount, uint256 priceUSD);
    event PackPurchased(uint256 indexed packId, address indexed buyer, uint256 zkxMinted, uint256 usdPaid);
    event TreasuryDistributed(uint256 total, uint256 toTreasury, uint256 toBit, uint256 toPrimes, uint256 toRescue);
    event ProfessionalAuthorized(address indexed professional);
    event ProfessionalRevoked(address indexed professional);
    event PortalUpdated(address indexed oldPortal, address indexed newPortal);
    
    // ═══════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════
    
    modifier onlyPortal() {
        if (msg.sender != portal) revert NotPortal();
        _;
    }
    
    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _code,
        string memory _institutionName,
        address _zksMain,
        address _paymentToken,
        uint8 _paymentDecimals,
        address _portal,
        address _treasury,
        address _treasuryBit,
        address _primesMoney,
        address _rescueMoney
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_zksMain == address(0)) revert ZeroAddress();
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_portal == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_treasuryBit == address(0)) revert ZeroAddress();
        if (_primesMoney == address(0)) revert ZeroAddress();
        if (_rescueMoney == address(0)) revert ZeroAddress();
        
        institutionCode = _code;
        institutionName = _institutionName;
        ZKS_MAIN = IZykosToken(_zksMain);
        PAYMENT_TOKEN = IERC20(_paymentToken);
        PAYMENT_DECIMALS = _paymentDecimals;
        portal = _portal;
        treasury = _treasury;
        treasuryBit = _treasuryBit;
        primesMoney = _primesMoney;
        rescueMoney = _rescueMoney;
        
        isProfessional[msg.sender] = true;
        _professionals.push(msg.sender);
        emit ProfessionalAuthorized(msg.sender);
    }
    
    function initialize() external onlyOwner {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        _initializeDefaultServices();
        _initializeDefaultPacks();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SOULBOUND - TRANSFERS BLOQUEADOS
    // ═══════════════════════════════════════════════════════════════
    
    function transfer(address, uint256) public pure override returns (bool) {
        revert TransferBlocked();
    }
    
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert TransferBlocked();
    }
    
    function approve(address, uint256) public pure override returns (bool) {
        revert TransferBlocked();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // COMPRA DE PACKS CON DISTRIBUCIÓN TREASURY
    // ═══════════════════════════════════════════════════════════════
    
    function purchasePack(uint256 _packId) external nonReentrant whenNotPaused {
        InstitutionalPack storage pack = packs[_packId];
        
        if (!pack.active) revert PackInactive();
        if (pack.zkxAmount == 0) revert PackNotFound();
        
        uint256 adjustedPrice = _adjustForDecimals(pack.priceUSD);
        
        // Transfer total a este contrato primero
        PAYMENT_TOKEN.safeTransferFrom(msg.sender, address(this), adjustedPrice);
        
        // Distribuir a treasuries según porcentajes
        _distributeTreasury(adjustedPrice);
        
        // Mint ZKS-X al portal
        _mint(portal, pack.zkxAmount);
        
        uint256 expiresAt = block.timestamp + (pack.validityDays * 1 days);
        
        purchases.push(PackPurchase({
            packId: _packId,
            zkxReceived: pack.zkxAmount,
            usdPaid: pack.priceUSD,
            purchasedAt: block.timestamp,
            expiresAt: expiresAt
        }));
        
        unchecked {
            totalMinted += pack.zkxAmount;
            totalUSDReceived += pack.priceUSD;
            pack.purchaseCount++;
        }
        
        emit PackPurchased(_packId, msg.sender, pack.zkxAmount, pack.priceUSD);
    }
    
    /**
     * @notice Distribuir pago a las 4 treasuries
     * @dev Misma estructura que ZKS principal
     */
    function _distributeTreasury(uint256 _amount) private {
        uint256 toTreasury = (_amount * TREASURY_BPS) / BPS_DIVISOR;
        uint256 toBit = (_amount * TREASURYBIT_BPS) / BPS_DIVISOR;
        uint256 toPrimes = (_amount * PRIMESMONEY_BPS) / BPS_DIVISOR;
        uint256 toRescue = _amount - toTreasury - toBit - toPrimes; // Remainder para evitar dust
        
        PAYMENT_TOKEN.safeTransfer(treasury, toTreasury);
        PAYMENT_TOKEN.safeTransfer(treasuryBit, toBit);
        PAYMENT_TOKEN.safeTransfer(primesMoney, toPrimes);
        PAYMENT_TOKEN.safeTransfer(rescueMoney, toRescue);
        
        unchecked {
            totalToTreasury += toTreasury;
            totalToTreasuryBit += toBit;
            totalToPrimesMoney += toPrimes;
            totalToRescueMoney += toRescue;
        }
        
        emit TreasuryDistributed(_amount, toTreasury, toBit, toPrimes, toRescue);
    }
    
    function _adjustForDecimals(uint256 amount18) private view returns (uint256) {
        if (PAYMENT_DECIMALS == 18) return amount18;
        if (PAYMENT_DECIMALS == 6) return amount18 / 1e12;
        return amount18 / (10 ** (18 - PAYMENT_DECIMALS));
    }
    
    // ═══════════════════════════════════════════════════════════════
    // USO DE SERVICIOS (BURN-ON-USE)
    // ═══════════════════════════════════════════════════════════════
    
    function useService(
        uint256 _serviceId,
        address _professional,
        bytes32 _patientHash
    ) external nonReentrant whenNotPaused onlyPortal {
        if (!isProfessional[_professional]) revert NotProfessional();
        
        ServiceDefinition storage svc = services[_serviceId];
        
        if (svc.createdAt == 0) revert ServiceNotFound();
        if (!svc.active) revert ServiceInactive();
        if (balanceOf(portal) < svc.zkxCost) revert InsufficientVouchers();
        
        // BURN - El valor se demuestra en el USO
        _burn(portal, svc.zkxCost);
        
        usageHistory.push(UsageRecord({
            serviceId: _serviceId,
            zkxBurned: svc.zkxCost,
            timestamp: block.timestamp,
            professional: _professional,
            patientHash: _patientHash
        }));
        
        unchecked {
            svc.usageCount++;
            svc.totalBurned += svc.zkxCost;
            totalBurned += svc.zkxCost;
            professionalServiceCount[_professional]++;
        }
        
        emit ServiceUsed(_serviceId, svc.zkxCost, _professional, _patientHash);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // GESTIÓN DE SERVICIOS Y PACKS
    // ═══════════════════════════════════════════════════════════════
    
    function defineService(
        string calldata _name,
        string calldata _category,
        uint256 _zkxCost,
        uint256 _usdReference
    ) external onlyOwner returns (uint256 serviceId) {
        if (_zkxCost == 0) revert InvalidServiceCost();
        
        serviceId = serviceCount;
        unchecked { ++serviceCount; }
        
        services[serviceId] = ServiceDefinition({
            name: _name,
            category: _category,
            zkxCost: _zkxCost,
            usdReference: _usdReference,
            usageCount: 0,
            totalBurned: 0,
            active: true,
            createdAt: block.timestamp
        });
        
        emit ServiceDefined(serviceId, _name, _zkxCost);
    }
    
    function definePack(
        string calldata _name,
        uint256 _zkxAmount,
        uint256 _priceUSD,
        uint256 _validityDays
    ) external onlyOwner returns (uint256 packId) {
        if (_zkxAmount == 0 || _priceUSD == 0) revert ZeroAmount();
        
        packId = packCount;
        unchecked { ++packCount; }
        
        packs[packId] = InstitutionalPack({
            name: _name,
            zkxAmount: _zkxAmount,
            priceUSD: _priceUSD,
            validityDays: _validityDays,
            purchaseCount: 0,
            active: true
        });
        
        emit PackDefined(packId, _name, _zkxAmount, _priceUSD);
    }
    
    function setServiceActive(uint256 _serviceId, bool _active) external onlyOwner {
        services[_serviceId].active = _active;
    }
    
    function setPackActive(uint256 _packId, bool _active) external onlyOwner {
        packs[_packId].active = _active;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INICIALIZACIÓN POR DEFECTO
    // ═══════════════════════════════════════════════════════════════
    
    function _initializeDefaultServices() private {
        // Costo ZKS-X | Referencia USD
        _addService("Urgencia Psiquiatrica 24/7", "Critico", 10000, 100);
        _addService("Consulta Ambulatoria", "Estandar", 3000, 30);
        _addService("Internacion Dia Completo", "Internacion", 15000, 150);
        _addService("Terapia Ocupacional", "Rehabilitacion", 4000, 40);
        _addService("Grupo Terapeutico", "Rehabilitacion", 1500, 15);
        _addService("Evaluacion Psicometrica", "Diagnostico", 5000, 50);
        _addService("Interconsulta", "Coordinacion", 2500, 25);
        _addService("Acompanamiento Terapeutico", "Seguimiento", 6000, 60);
        _addService("Telepsiquiatria PSYKooD", "Telemedicina", 2000, 20);
        _addService("Certificado Aptitud", "Administrativo", 2000, 20);
    }
    
    function _addService(string memory _name, string memory _cat, uint256 _zkx, uint256 _usd) private {
        services[serviceCount] = ServiceDefinition({
            name: _name, category: _cat,
            zkxCost: _zkx * 1e18, usdReference: _usd * 1e18,
            usageCount: 0, totalBurned: 0, active: true, createdAt: block.timestamp
        });
        unchecked { ++serviceCount; }
    }
    
    function _initializeDefaultPacks() private {
        _addPack("Pack Demo", 10000, 90, 7);
        _addPack("Pack Mensual Basico", 50000, 400, 30);
        _addPack("Pack Mensual Premium", 100000, 750, 30);
        _addPack("Pack Trimestral", 250000, 1750, 90);
        _addPack("Pack Anual Enterprise", 1000000, 5000, 365);
    }
    
    