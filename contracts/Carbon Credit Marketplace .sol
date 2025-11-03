mapping(address => uint256) public lockEnd;
mapping(address => uint256) public lockedAmount;

function lockTokens(uint256 amount, uint256 duration) external {
    carbonToken.transferFrom(msg.sender, address(this), amount);
    lockedAmount[msg.sender] += amount;
    lockEnd[msg.sender] = block.timestamp + duration;
}

function unlockTokens() external {
    require(block.timestamp >= lockEnd[msg.sender], "Still locked");
    uint256 amount = lockedAmount[msg.sender];
    lockedAmount[msg.sender] = 0;
    carbonToken.transfer(msg.sender, amount);
}
function decayReputation(address user) internal {
    if(esgScore[user] > 0) esgScore[user] -= esgScore[user] / 100; // ~1% weekly decay
}
struct VoteSession {
    uint256 escrowId;
    uint256 yes;
    uint256 no;
    bool active;
}

mapping(uint256 => VoteSession) public votes;

function startVote(uint256 escrowId) external onlyRole(ARBITER_ROLE) {
    votes[escrowId].active = true;
}

function voteDispute(uint256 escrowId, bool decision) external {
    require(holdings[msg.sender] > 0, "No stake");
    require(votes[escrowId].active, "Voting closed");
    
    if(decision) votes[escrowId].yes++;
    else votes[escrowId].no++;
}
function mintRetireNFT(address user, uint256 amount) internal {
    uint256 tokenId = uint256(keccak256(abi.encode(user, amount, block.timestamp)));
    _mint(user, tokenId); // soulbound override transfer()
}
mapping(address => uint8) public kycLevel; // 0=none, 1=light, 2=verified

function updateKYC(address user, uint8 level) external onlyOracle {
    kycLevel[user] = level;
}
bool public paused;

modifier notPaused() {
    require(!paused, "System paused");
    _;
}

function pauseSystem(bool state) external onlyAdmin {
    paused = state;
}
struct Futures {
    uint256 amount;
    uint256 settleDate;
    uint256 price;
}
mapping(address => address) public guardian;

function setGuardian(address g) external {
    guardian[msg.sender] = g;
}
