struct Dispute {
    uint256 escrowId;
    address opener;
    string reason;
    bool resolved;
    address winner;
}

mapping(uint256 => Dispute) public disputes;

event DisputeOpened(uint256 disputeId, uint256 escrowId, address opener);
event DisputeResolved(uint256 disputeId, address winner);

function openDispute(uint256 escrowId, string calldata reason) external {
    require(msg.sender == escrows[escrowId].buyer || msg.sender == escrows[escrowId].seller, "Not participant");
    disputes[escrowId] = Dispute(escrowId, msg.sender, reason, false, address(0));
    emit DisputeOpened(escrowId, escrowId, msg.sender);
}

function resolveDispute(uint256 escrowId, address winner) external onlyRole(ARBITER_ROLE) {
    Dispute storage d = disputes[escrowId];
    require(!d.resolved, "Already resolved");
    d.resolved = true;
    d.winner = winner;
    emit DisputeResolved(escrowId, winner);
}
event AIVerified(address user, uint256 creditId, bool result);

function submitProof(bytes calldata ipfsHash) external {
    emit OracleRequested(msg.sender, ipfsHash);
}

function aiOracleCallback(address user, uint256 creditId, bool valid) external onlyOracle {
    emit AIVerified(user, creditId, valid);
}
uint256 public rewardRate = 5e18; // 5 tokens per period

function claimCarbonYield() external {
    uint256 reward = (block.timestamp - lastClaim[msg.sender]) * rewardRate;
    lastClaim[msg.sender] = block.timestamp;
    carbonToken.mint(msg.sender, 1, reward);
}
mapping(address => uint256) public greenBadges;

function mintGreenBadge(address user, uint256 score) internal {
    if(score > 1000) greenBadges[user] += 1; // soulbound badge
}
mapping(address => uint256) public esgScore;

function setESGScore(address user, uint256 score) external onlyAdmin {
    esgScore[user] = score;
}
mapping(address => bool) public blacklisted;

function blacklist(address user, bool flag) external onlyAdmin {
    blacklisted[user] = flag;
}

modifier notBlacklisted() {
    require(!blacklisted[msg.sender], "Blacklisted user");
    _;
}
event CertificateMinted(address user, uint256 certId);

function mintCertificate(address user, uint256 retiredAmount) internal {
    uint256 certId = uint256(keccak256(abi.encode(user, retiredAmount, block.timestamp)));
    emit CertificateMinted(user, certId);
}
event LotteryWin(address user, uint256 reward);

function carbonLottery(uint256 amount) external {
    carbonToken.burn(msg.sender, 1, amount);
    if(uint256(keccak256(abi.encode(block.timestamp,msg.sender))) % 10 == 0) {
        carbonToken.mint(msg.sender, 1, amount * 2);
        emit LotteryWin(msg.sender, amount * 2);
    }
}
