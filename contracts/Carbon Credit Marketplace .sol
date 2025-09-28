struct Dispute {
    uint256 escrowId;
    address raiser;
    string reason;
    bool resolved;
    bool ruledInFavorOfSeller;
}

mapping(uint256 => Dispute) public disputes;

event DisputeRaised(uint256 indexed escrowId, address indexed raiser, string reason);
event DisputeResolved(uint256 indexed escrowId, bool ruledInFavorOfSeller);

function raiseDispute(uint256 _escrowId, string memory _reason) external {
    Escrow storage esc = escrows[_escrowId];
    require(msg.sender == esc.buyer || msg.sender == carbonCredits[esc.creditId].seller, "Not involved");
    require(!esc.sellerConfirmed || !esc.buyerConfirmed, "Already confirmed");
    disputes[_escrowId] = Dispute(_escrowId, msg.sender, _reason, false, false);
    emit DisputeRaised(_escrowId, msg.sender, _reason);
}

function resolveDispute(uint256 _escrowId, bool favorSeller) external onlyOwner {
    Dispute storage disp = disputes[_escrowId];
    require(!disp.resolved, "Already resolved");
    disp.resolved = true;
    disp.ruledInFavorOfSeller = favorSeller;
    resolveEscrow(_escrowId, favorSeller);
    emit DisputeResolved(_escrowId, favorSeller);
}
mapping(address => uint256) public sellerTiers; // 0=Basic,1=Silver,2=Gold

function updateSellerTier(address _seller) public {
    uint256 avgRating = ratingCounts[_seller] == 0 
        ? 0 
        : sellerRatings[_seller] / ratingCounts[_seller];
    if (avgRating >= 4 && ratingCounts[_seller] >= 10) sellerTiers[_seller] = 2;
    else if (avgRating >= 3) sellerTiers[_seller] = 1;
    else sellerTiers[_seller] = 0;
}

function getTierDiscount(address _seller) public view returns (uint256) {
    if (sellerTiers[_seller] == 2) return 80; // 20% discount on fee
    if (sellerTiers[_seller] == 1) return 90; // 10% discount
    return 100; // no discount
}
function retireCredit(uint256 _creditId, uint256 _amount) external onlyVerified(_creditId) {
    CarbonCredit storage credit = carbonCredits[_creditId];
    require(_amount <= credit.amount, "Not enough credits");
    credit.amount -= _amount;
    emit CreditRetired(_creditId, _amount, msg.sender);
}
address public sustainabilityFund;

function setSustainabilityFund(address _fund) external onlyOwner {
    sustainabilityFund = _fund;
}

function distributeFee(uint256 totalFee) internal {
    uint256 devShare = (totalFee * 60) / 100;
    uint256 fundShare = totalFee - devShare;
    payable(owner()).transfer(devShare);
    if (sustainabilityFund != address(0)) payable(sustainabilityFund).transfer(fundShare);
}
distributeFee(fee);
struct Transaction {
    uint256 escrowId;
    uint256 creditId;
    address buyer;
    address seller;
    uint256 amount;
    uint256 totalPrice;
    uint256 timestamp;
}

Transaction[] public transactions;

event TransactionLogged(uint256 indexed escrowId, address indexed buyer, address indexed seller, uint256 totalPrice);

function logTransaction(
    uint256 _escrowId,
    uint256 _creditId,
    address _buyer,
    address _seller,
    uint256 _amount,
    uint256 _totalPrice
) internal {
    transactions.push(Transaction(_escrowId, _creditId, _buyer, _seller, _amount, _totalPrice, block.timestamp));
    emit TransactionLogged(_escrowId, _buyer, _seller, _totalPrice);
}
mapping(address => uint256) public loyaltyPoints;

function rewardUser(address _user, uint256 _points) internal {
    loyaltyPoints[_user] += _points;
}

function redeemPoints(uint256 _points) external {
    require(loyaltyPoints[msg.sender] >= _points, "Not enough points");
    loyaltyPoints[msg.sender] -= _points;
    // could later mint NFT, token, or discount
}
uint256 public escrowTimeLimit = 3 days;

function autoRelease(uint256 _escrowId) external {
    Escrow storage esc = escrows[_escrowId];
    require(block.timestamp > esc.createdAt + escrowTimeLimit, "Too early");
    resolveEscrow(_escrowId, true);
}
mapping(address => bool) public verifiedSellers;

function verifySeller(address _seller, bool _status) external onlyOwner {
    verifiedSellers[_seller] = _status;
}
