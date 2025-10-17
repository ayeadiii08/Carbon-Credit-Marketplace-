interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

IPriceFeed public carbonPriceFeed;

function setCarbonPriceFeed(address _feed) external onlyOwner {
    carbonPriceFeed = IPriceFeed(_feed);
}

function getLiveCarbonPrice() public view returns (uint256) {
    int256 price = carbonPriceFeed.latestAnswer();
    require(price > 0, "Invalid oracle data");
    return uint256(price);
}
address public stakingPool;
address public rewardPool;

function setFeeRecipients(address _staking, address _reward) external onlyOwner {
    stakingPool = _staking;
    rewardPool = _reward;
}

function splitFees(uint256 _amount) internal {
    uint256 daoShare = (_amount * 60) / 100;
    uint256 stakeShare = (_amount * 25) / 100;
    uint256 rewardShare = _amount - daoShare - stakeShare;
    payable(treasury).transfer(daoShare);
    payable(stakingPool).transfer(stakeShare);
    payable(rewardPool).transfer(rewardShare);
}
mapping(address => uint256) public votesCast;

function vote(uint256 _id, bool support) external {
    Proposal storage p = proposals[_id];
    require(block.timestamp < p.endTime, "Voting ended");
    uint256 votes = govToken.balanceOf(msg.sender);
    require(votes > 0, "No voting power");

    if (support) p.votesFor += votes;
    else p.votesAgainst += votes;

    votesCast[msg.sender] += 1;
    loyaltyPoints[msg.sender] += 10; // bonus
    logAction("DAO Vote Cast");
}
mapping(address => string) public achievementTitle;

function updateTitle(address _user) internal {
    if (totalRetiredCredits[_user] >= 10000)
        achievementTitle[_user] = "Eco-Legend";
    else if (totalRetiredCredits[_user] >= 5000)
        achievementTitle[_user] = "Carbon Hero";
    else if (totalRetiredCredits[_user] >= 1000)
        achievementTitle[_user] = "Eco Supporter";
}
mapping(bytes32 => bool) public usedIdentityHash;

function registerUser(bytes32 _identityHash) external {
    require(!usedIdentityHash[_identityHash], "Identity already used");
    usedIdentityHash[_identityHash] = true;
    logAction("User Registered");
}
mapping(uint256 => bool) public disputeResolved;

function resolveDispute(uint256 _escrowId, bool favorSeller) external onlyOwner {
    Escrow storage esc = escrows[_escrowId];
    require(!disputeResolved[_escrowId], "Already resolved");
    disputeResolved[_escrowId] = true;

    if (favorSeller) payable(esc.seller).transfer(esc.amount);
    else payable(esc.buyer).transfer(esc.amount);

    logAction("Dispute Resolved");
}
event LeaderboardReward(address indexed user, uint256 reward);

function rewardTopContributors() external onlyOwner {
    require(leaderboard.length > 3, "Not enough users");
    for (uint256 i = 0; i < 3; i++) {
        address top = leaderboard[i];
        rewardUser(top, (3 - i) * 100); // 1st:300, 2nd:200, 3rd:100
        emit LeaderboardReward(top, (3 - i) * 100);
    }
}
mapping(address => uint256) public stakedAmount;

function stake() external payable {
    require(msg.value > 0, "No value");
    stakedAmount[msg.sender] += msg.value;
    loyaltyPoints[msg.sender] += msg.value / 1e15; // e.g. +1 LP per 0.001 ETH
    logAction("Tokens Staked");
}

function unstake(uint256 _amount) external {
    require(stakedAmount[msg.sender] >= _amount, "Insufficient stake");
    stakedAmount[msg.sender] -= _amount;
    payable(msg.sender).transfer(_amount);
    logAction("Tokens Unstaked");
}
event CrossChainTransfer(address indexed user, uint256 creditId, uint256 amount, string targetChain);

function bridgeCredit(uint256 _creditId, uint256 _amount, string calldata _targetChain) external {
    CarbonCredit storage credit = carbonCredits[_creditId];
    require(_amount <= credit.amount, "Insufficient credits");
    credit.amount -= _amount;
    emit CrossChainTransfer(msg.sender, _creditId, _amount, _targetChain);
}
function adaptiveReward(address _user) internal {
    uint256 avgScore;
    uint256 totalUsers = leaderboard.length;
    for (uint256 i = 0; i < totalUsers; i++) {
        avgScore += getReputationScore(leaderboard[i]);
    }
    if (totalUsers > 0) avgScore /= totalUsers;

    uint256 userScore = getReputationScore(_user);
    if (userScore >= avgScore) rewardUser(_user, 30);
    else rewardUser(_user, 10);
}
