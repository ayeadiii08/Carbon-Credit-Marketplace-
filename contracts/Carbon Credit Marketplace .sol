mapping(address => uint256) public completedTrades;
mapping(address => uint256) public disputesLost;

function updateReputation(address _user, bool _wonDispute) internal {
    completedTrades[_user]++;
    if (!_wonDispute) disputesLost[_user]++;
}

function getReputationScore(address _user) public view returns (uint256) {
    uint256 total = completedTrades[_user] + disputesLost[_user];
    if (total == 0) return 0;
    uint256 score = (completedTrades[_user] * 100) / total; // percentage success
    return score;
}
function calculateFee(address _seller, uint256 baseFee) public view returns (uint256) {
    uint256 discount = getTierDiscount(_seller);
    return (baseFee * discount) / 100;
}
event NFTRetired(address indexed user, uint256 creditId, uint256 amount, string certificateURI);

function issueRetirementNFT(address _to, uint256 _creditId, uint256 _amount) internal {
    string memory certificateURI = string(
        abi.encodePacked("ipfs://certificate_", uint2str(_creditId), "_", uint2str(_amount))
    );
    emit NFTRetired(_to, _creditId, _amount, certificateURI);
}

function retireCredit(uint256 _creditId, uint256 _amount) external onlyVerified(_creditId) {
    CarbonCredit storage credit = carbonCredits[_creditId];
    require(_amount <= credit.amount, "Not enough credits");
    credit.amount -= _amount;
    issueRetirementNFT(msg.sender, _creditId, _amount);
    emit CreditRetired(_creditId, _amount, msg.sender);
}
uint256 public confirmationTimeLimit = 2 days;

function checkLateConfirmation(uint256 _escrowId) internal {
    Escrow storage esc = escrows[_escrowId];
    if (block.timestamp > esc.createdAt + confirmationTimeLimit) {
        // penalize both if no confirmation
        loyaltyPoints[esc.buyer] = loyaltyPoints[esc.buyer] > 5 ? loyaltyPoints[esc.buyer] - 5 : 0;
        loyaltyPoints[esc.seller] = loyaltyPoints[esc.seller] > 5 ? loyaltyPoints[esc.seller] - 5 : 0;
    }
}
mapping(address => uint256) public totalRetiredCredits;

function retireCredit(uint256 _creditId, uint256 _amount) external onlyVerified(_creditId) {
    CarbonCredit storage credit = carbonCredits[_creditId];
    require(_amount <= credit.amount, "Not enough credits");
    credit.amount -= _amount;
    totalRetiredCredits[msg.sender] += _amount;
    emit CreditRetired(_creditId, _amount, msg.sender);
}
function checkMilestones(address _user) internal {
    if (completedTrades[_user] % 10 == 0) rewardUser(_user, 50);
    if (totalRetiredCredits[_user] >= 1000) rewardUser(_user, 100);
}
event AuditLog(address indexed actor, string action, uint256 timestamp);

function logAction(string memory _action) internal {
    emit AuditLog(msg.sender, _action, block.timestamp);
}
logAction("Dispute Raised");
logAction("Credit Retired");
bool public paused = false;

modifier whenNotPaused() {
    require(!paused, "Contract is paused");
    _;
}

function pauseContract(bool _state) external onlyOwner {
    paused = _state;
}

function emergencyWithdraw() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
}
