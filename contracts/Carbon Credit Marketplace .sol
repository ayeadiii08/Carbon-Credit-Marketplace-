mapping(uint256 => bool) public buyerConfirmed;
mapping(uint256 => bool) public sellerConfirmed;

event TradeConfirmed(uint256 escrowId, address confirmer);

function confirmTrade(uint256 _escrowId) external {
    Escrow storage esc = escrows[_escrowId];
    require(!esc.cancelled && !esc.completed, "Escrow closed");
    require(msg.sender == esc.buyer || msg.sender == esc.seller, "Not a participant");

    if (msg.sender == esc.buyer) buyerConfirmed[_escrowId] = true;
    if (msg.sender == esc.seller) sellerConfirmed[_escrowId] = true;

    if (buyerConfirmed[_escrowId] && sellerConfirmed[_escrowId]) {
        esc.completed = true;
        payable(esc.seller).transfer(esc.amount);
        updateReputation(esc.seller, true);
        updateReputation(esc.buyer, true);
        logAction("Trade Completed");
    }

    emit TradeConfirmed(_escrowId, msg.sender);
}
event AirdropClaimed(address indexed user, uint256 amount);

function randomAirdrop(address _user) internal {
    uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, _user))) % 100;
    if (random < 10) { // 10% chance
        uint256 reward = 25 + (random % 25);
        loyaltyPoints[_user] += reward;
        emit AirdropClaimed(_user, reward);
    }
}
enum VerificationLevel { Unverified, Basic, Advanced, Institutional }
mapping(address => VerificationLevel) public verificationLevel;

event UserVerified(address indexed user, VerificationLevel level);

function verifyUser(address _user, VerificationLevel _level) external onlyOwner {
    verificationLevel[_user] = _level;
    emit UserVerified(_user, _level);
}
modifier onlyAdvanced(address _user) {
    require(uint(verificationLevel[_user]) >= uint(VerificationLevel.Advanced), "Not verified enough");
    _;
}
struct Feedback {
    uint8 rating; // 1–5 stars
    string comment;
}

mapping(address => Feedback[]) public feedbacks;

function leaveFeedback(address _to, uint8 _rating, string calldata _comment) external {
    require(_rating >= 1 && _rating <= 5, "Invalid rating");
    feedbacks[_to].push(Feedback(_rating, _comment));
    logAction("Feedback Submitted");
}
IERC721 public membershipNFT;

function setMembershipNFT(address _nft) external onlyOwner {
    membershipNFT = IERC721(_nft);
}

function hasMembership(address _user) public view returns (bool) {
    return membershipNFT.balanceOf(_user) > 0;
}

function getTierDiscount(address _seller) public view returns (uint256) {
    if (hasMembership(_seller)) return 60; // extra 40% discount
    Tier tier = userTier[_seller];
    if (tier == Tier.Platinum) return 70;
    if (tier == Tier.Gold) return 80;
    if (tier == Tier.Silver) return 90;
    return 100;
}
function decayTier(address _user) internal {
    if (block.timestamp > lastActivity[_user] + 90 days) {
        if (userTier[_user] == Tier.Platinum) userTier[_user] = Tier.Gold;
        else if (userTier[_user] == Tier.Gold) userTier[_user] = Tier.Silver;
        else if (userTier[_user] == Tier.Silver) userTier[_user] = Tier.Bronze;
    }
}
address[] public leaderboard;

function updateLeaderboard(address _user) internal {
    if (leaderboard.length < 10) leaderboard.push(_user);
    else {
        // Replace lowest scorer
        uint256 lowestScore;
        uint256 index;
        for (uint256 i = 0; i < leaderboard.length; i++) {
            uint256 score = getReputationScore(leaderboard[i]);
            if (score < lowestScore) {
                lowestScore = score;
                index = i;
            }
        }
        if (getReputationScore(_user) > lowestScore) {
            leaderboard[index] = _user;
        }
    }
}
address public treasury;
uint256 public burnPercentage = 5; // 5%

function setTreasury(address _treasury) external onlyOwner {
    treasury = _treasury;
}

function distributeFee(uint256 _amount) internal {
    uint256 burnAmount = (_amount * burnPercentage) / 100;
    uint256 treasuryAmount = _amount - burnAmount;
    payable(treasury).transfer(treasuryAmount);
    // optional: burn tokens here if ERC20
}
