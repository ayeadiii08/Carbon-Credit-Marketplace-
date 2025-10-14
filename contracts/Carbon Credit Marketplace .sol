enum Tier { Bronze, Silver, Gold, Platinum }
mapping(address => Tier) public userTier;

function updateTier(address _user) internal {
    uint256 score = getReputationScore(_user);
    uint256 retired = totalRetiredCredits[_user];

    if (score >= 90 && retired >= 2000) userTier[_user] = Tier.Platinum;
    else if (score >= 80 && retired >= 1000) userTier[_user] = Tier.Gold;
    else if (score >= 70 && retired >= 500) userTier[_user] = Tier.Silver;
    else userTier[_user] = Tier.Bronze;
}
function getTierDiscount(address _seller) public view returns (uint256) {
    Tier tier = userTier[_seller];
    if (tier == Tier.Platinum) return 70; // 30% discount
    if (tier == Tier.Gold) return 80;
    if (tier == Tier.Silver) return 90;
    return 100; // No discount
}
mapping(address => address) public referrer;
mapping(address => uint256) public referralRewards;

function registerReferrer(address _referrer) external {
    require(referrer[msg.sender] == address(0), "Already referred");
    require(_referrer != msg.sender, "Self-referral not allowed");
    referrer[msg.sender] = _referrer;
}

function rewardReferrer(address _user, uint256 _points) internal {
    address _ref = referrer[_user];
    if (_ref != address(0)) {
        referralRewards[_ref] += _points;
        rewardUser(_ref, _points / 2); // 50% of user reward
    }
}
function autoCancelEscrow(uint256 _escrowId) external {
    Escrow storage esc = escrows[_escrowId];
    require(block.timestamp > esc.createdAt + confirmationTimeLimit, "Still within limit");
    require(!esc.completed, "Already completed");

    esc.cancelled = true;
    payable(esc.buyer).transfer(esc.amount);
    logAction("Escrow Auto-Cancelled");
}
event BadgeMinted(address indexed user, string badgeName, string badgeURI);

function mintBadge(address _user, string memory _badgeName) internal {
    string memory badgeURI = string(abi.encodePacked("ipfs://badge_", _badgeName));
    emit BadgeMinted(_user, _badgeName, badgeURI);
}

function checkAchievements(address _user) internal {
    if (completedTrades[_user] >= 50) mintBadge(_user, "TrustedTrader");
    if (totalRetiredCredits[_user] >= 5000) mintBadge(_user, "EarthGuardian");
}
mapping(address => uint256) public loyaltyPoints;
IERC20 public rewardToken;

function setRewardToken(address _token) external onlyOwner {
    rewardToken = IERC20(_token);
}

function convertPointsToTokens(uint256 _points) external whenNotPaused {
    require(loyaltyPoints[msg.sender] >= _points, "Not enough points");
    loyaltyPoints[msg.sender] -= _points;
    rewardToken.transfer(msg.sender, _points * 1e18 / 100); // Example rate
}
mapping(address => uint256) public lastActivity;

function decayReputation(address _user) internal {
    if (block.timestamp > lastActivity[_user] + 30 days) {
        completedTrades[_user] = (completedTrades[_user] * 95) / 100; // -5%
        disputesLost[_user] += 1; // simulate drop
    }
    lastActivity[_user] = block.timestamp;
}
struct Proposal {
    string description;
    uint256 votesFor;
    uint256 votesAgainst;
    uint256 endTime;
    bool executed;
}

mapping(uint256 => Proposal) public proposals;
uint256 public proposalCount;
IERC20 public govToken;

function createProposal(string memory _desc) external {
    proposals[++proposalCount] = Proposal(_desc, 0, 0, block.timestamp + 3 days, false);
}

function vote(uint256 _id, bool support) external {
    Proposal storage p = proposals[_id];
    require(block.timestamp < p.endTime, "Voting ended");
    uint256 votes = govToken.balanceOf(msg.sender);
    if (support) p.votesFor += votes;
    else p.votesAgainst += votes;
}

function executeProposal(uint256 _id) external {
    Proposal storage p = proposals[_id];
    require(!p.executed && block.timestamp > p.endTime, "Cannot execute yet");
    require(p.votesFor > p.votesAgainst, "Proposal rejected");
    p.executed = true;
    logAction("Proposal Executed");
}
