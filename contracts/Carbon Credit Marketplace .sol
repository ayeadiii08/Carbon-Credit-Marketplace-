function resolveEscrow(uint256 _escrowId, bool releaseToSeller) external onlyOwner {
    Escrow storage esc = escrows[_escrowId];
    require(!esc.sellerConfirmed || !esc.buyerConfirmed, "Already confirmed");

    if (releaseToSeller) {
        payable(carbonCredits[esc.creditId].seller).transfer(esc.totalPrice);
    } else {
        payable(esc.buyer).transfer(esc.totalPrice);
    }
    delete escrows[_escrowId];
}
uint256 public royaltyFee = 2; // default 2%

function setRoyaltyFee(uint256 _fee) external onlyOwner {
    require(_fee <= 10, "Max 10%");
    royaltyFee = _fee;
}
vmapping(uint256 => bool) public verifiedCredits;

function verifyCredit(uint256 _creditId, bool _status) external onlyOwner {
    verifiedCredits[_creditId] = _status;
}

modifier onlyVerified(uint256 _creditId) {
    require(verifiedCredits[_creditId], "Credit not verified");
    _;
}
uint256 public marketplaceFee = 1; // 1%

function setMarketplaceFee(uint256 _fee) external onlyOwner {
    require(_fee <= 5, "Max 5%");
    marketplaceFee = _fee;
}
uint256 fee = (totalPrice * marketplaceFee) / 100;
payable(owner()).transfer(fee);
sellerAmount -= fee;
function calculateFee(address _seller, uint256 _price) public view returns (uint256) {
    uint256 avgRating = ratingCounts[_seller] == 0 
        ? 0 
        : sellerRatings[_seller] / ratingCounts[_seller];
    
    if (avgRating >= 4) {
        return (_price * (marketplaceFee / 2)) / 100; // 50% discount
    }
    return (_price * marketplaceFee) / 100;
}
event CarbonListed(uint256 indexed creditId, address indexed seller, uint256 amount, uint256 price);
event EscrowInitiated(uint256 indexed escrowId, uint256 creditId, address buyer, uint256 totalPrice);
event SellerRated(address indexed seller, uint8 rating);
event CreditRetired(uint256 indexed creditId, uint256 amount, address retiredBy);
function calculateBulkPrice(uint256 _amount, uint256 _pricePerTon) public pure returns (uint256) {
    if (_amount >= 100) return (_amount * _pricePerTon * 90) / 100; // 10% discount
    if (_amount >= 50) return (_amount * _pricePerTon * 95) / 100;  // 5% discount
    return _amount * _pricePerTon;
}
