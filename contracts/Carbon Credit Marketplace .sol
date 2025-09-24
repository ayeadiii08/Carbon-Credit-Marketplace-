mapping(uint256 => address) public originalSeller;

function listCarbonCredit(
    string memory _projectName,
    uint256 _amount,
    uint256 _pricePerTon,
    string memory _verificationHash,
    uint256 _vintage
) external nonZeroAmount(_amount) returns (uint256) {
    ...
    carbonCredits[creditId] = CarbonCredit({
        ...
    });
    originalSeller[creditId] = msg.sender; // track first seller
    ...
}
uint256 royalty = (totalPrice * 2) / 100; 
payable(originalSeller[_creditId]).transfer(royalty);
sellerAmount -= royalty;
bool public paused;

modifier notPaused() {
    require(!paused, "Marketplace is paused");
    _;
}

function setPause(bool _state) external onlyOwner {
    paused = _state;
}
struct Escrow {
    uint256 creditId;
    address buyer;
    uint256 amount;
    uint256 totalPrice;
    bool sellerConfirmed;
    bool buyerConfirmed;
}

mapping(uint256 => Escrow) public escrows;
uint256 public nextEscrowId;

function initiateEscrow(uint256 _creditId, uint256 _amount) 
    external 
    payable 
    validCredit(_creditId) 
    nonZeroAmount(_amount) 
    notPaused 
{
    CarbonCredit storage credit = carbonCredits[_creditId];
    uint256 totalPrice = _amount * credit.pricePerTon;
    require(msg.value >= totalPrice, "Insufficient payment");

    uint256 escrowId = nextEscrowId++;
    escrows[escrowId] = Escrow(_creditId, msg.sender, _amount, totalPrice, false, false);
}
mapping(address => uint256) public sellerRatings;
mapping(address => uint256) public ratingCounts;

function rateSeller(address _seller, uint8 _rating) external {
    require(_rating >= 1 && _rating <= 5, "Invalid rating");
    sellerRatings[_seller] += _rating;
    ratingCounts[_seller]++;
}

function getSellerReputation(address _seller) external view returns (uint256 avgRating) {
    if (ratingCounts[_seller] == 0) return 0;
    return sellerRatings[_seller] / ratingCounts[_seller];
}
function retireBatch(uint256[] calldata _creditIds, uint256[] calldata _amounts) external {
    require(_creditIds.length == _amounts.length, "Mismatched input");

    for (uint256 i = 0; i < _creditIds.length; i++) {
        retireCarbonCredit(_creditIds[i], _amounts[i]);
    }
}
mapping(address => bool) public whitelisted;

function updateWhitelist(address _user, bool _status) external onlyOwner {
    whitelisted[_user] = _status;
}

modifier onlyWhitelisted() {
    require(whitelisted[msg.sender], "Not KYC verified");
    _;
}











