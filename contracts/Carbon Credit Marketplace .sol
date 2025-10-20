// import "openzeppelin-contracts/contracts/access/AccessControl.sol";
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

// In initialize / constructor:
_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
_setupRole(ADMIN_ROLE, msg.sender);

modifier onlyAdmin() {
    require(hasRole(ADMIN_ROLE, _msgSender()), "Not admin");
    _;
}
// import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
contract CarbonToken is ERC1155 {
    constructor() ERC1155("ipfs://carbon/{id}.json") {}
    function mint(address to, uint256 id, uint256 amount) external onlyAdmin {
        _mint(to, id, amount, "");
    }
    function burn(address from, uint256 id, uint256 amount) external {
        require(msg.sender == from || isApprovedForAll(from, msg.sender), "No permission");
        _burn(from, id, amount);
    }
}
struct Vest {
    uint256 total;
    uint256 released;
    uint256 start;
    uint256 duration;
}
mapping(address => Vest) public vestings;

function createVesting(address to, uint256 amount, uint256 duration) internal {
    vestings[to] = Vest(amount, 0, block.timestamp, duration);
    // don't transfer here; transfer on claim
}

function claimVested() external {
    Vest storage v = vestings[msg.sender];
    uint256 vested = ((block.timestamp - v.start) * v.total) / v.duration;
    if (vested > v.total) vested = v.total;
    uint256 claimable = vested - v.released;
    require(claimable > 0, "Nothing to claim");
    v.released += claimable;
    payable(msg.sender).transfer(claimable);
    logAction("Vested Claimed");
}
mapping(address => address) public delegates;
mapping(address => uint256) public delegatedVotes; // cached

function delegate(address to) external {
    delegates[msg.sender] = to;
    // update delegatedVotes bookkeeping (simple version)
    uint256 votes = govToken.balanceOf(msg.sender);
    delegatedVotes[to] += votes;
    logAction("Delegated");
}
// Keeper-compatible check / perform
function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory) {
    // Example: find any escrows past limit
    upkeepNeeded = false;
    // set true if maintenance needed
}

function performUpkeep(bytes calldata) external {
    // only Keeper role or trusted forwarder allowed
    // run autoCancelEscrow for stale escrows, decay inactive tiers, etc.
}
function executeTradeWithMax(uint256 escrowId, uint256 maxPrice) external {
    uint256 livePrice = getLiveCarbonPrice();
    require(livePrice <= maxPrice, "Slippage too high");
    // proceed with trade
}
event RefundIssued(uint256 escrowId, uint256 amount, address to);

function issuePartialRefund(uint256 _escrowId, uint256 _amount) external onlyAdmin nonReentrant {
    Escrow storage esc = escrows[_escrowId];
    require(esc.amount >= _amount, "Too much");
    esc.amount -= _amount;
    payable(esc.buyer).transfer(_amount);
    emit RefundIssued(_escrowId, _amount, esc.buyer);
    logAction("Partial Refund");
}
mapping(address => uint256) public lastEscrowCreated;
uint256 public escrowCooldown = 1 hours;

function createEscrow(...) external {
    require(block.timestamp >= lastEscrowCreated[msg.sender] + escrowCooldown, "Cooldown");
    lastEscrowCreated[msg.sender] = block.timestamp;
    // create escrow...
}
event CreditProvenance(uint256 indexed creditId, string ipfsMetadata, uint256 timestamp);

function registerCreditProvenance(uint256 creditId, string calldata ipfsHash) external onlyAdmin {
    emit CreditProvenance(creditId, ipfsHash, block.timestamp);
}
interface IERC20Permit {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}

function stakeWithPermit(address token, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    IERC20Permit(token).permit(msg.sender, address(this), amount, deadline, v, r, s);
    IERC20(token).transferFrom(msg.sender, address(this), amount);
    stakedAmount[msg.sender] += amount;
    logAction("StakedWithPermit");
}
mapping(bytes32 => bool) public featurePaused; // e.g., keccak256("staking")

modifier whenFeatureNotPaused(bytes32 feature) {
    require(!featurePaused[feature], "Feature paused");
    _;
}

function setFeaturePaused(bytes32 feature, bool state) external onlyAdmin {
    featurePaused[feature] = state;
    logAction("Feature Pause Toggled");
}
mapping(address => uint256) public fiatVoucher; // in stable token wei

function issueFiatVoucher(address user, uint256 amount) external onlyAdmin {
    fiatVoucher[user] += amount;
    logAction("FiatVoucherIssued");
}

function claimFiatVoucher(address payable to, uint256 amount) external {
    require(fiatVoucher[msg.sender] >= amount, "No voucher");
    fiatVoucher[msg.sender] -= amount;
    // off-chain: custodial partner picks this up, or transfer stable token if available
    payable(to).transfer(amount);
    logAction("FiatVoucherClaimed");
}
