function createAuction(uint256 auctionId, uint256 creditId, uint256 startPrice, uint256 duration) external nonReentrant {
    // transfer credit to contract (seller must approve)
    carbonToken.safeTransferFrom(msg.sender, address(this), creditId, 1, "");
    auctions[auctionId] = Auction(msg.sender, creditId, startPrice, 0, address(0), block.timestamp + duration, true);
    logAction("AuctionCreated");
}

function placeBid(uint256 auctionId) external payable nonReentrant {
    Auction storage a = auctions[auctionId];
    require(a.active && block.timestamp < a.endTime, "Not active");
    require(msg.value > a.highestBid && msg.value >= a.startPrice, "Bid too low");

    // refund previous bidder
    if (a.highestBidder != address(0)) payable(a.highestBidder).transfer(a.highestBid);
    a.highestBid = msg.value;
    a.highestBidder = msg.sender;
    logAction("BidPlaced");
}

function finalizeAuction(uint256 auctionId) external nonReentrant {
    Auction storage a = auctions[auctionId];
    require(a.active && block.timestamp >= a.endTime, "Not ended");
    a.active = false;
    if (a.highestBidder == address(0)) {
        // no sale, return NFT to seller
        carbonToken.safeTransferFrom(address(this), a.seller, a.creditId, 1, "");
    } else {
        // transfer funds to seller (minus fees)
        uint256 afterDonation = donatePortion(a.highestBid);
        splitFees(afterDonation);
        payable(a.seller).transfer(afterDonation);
        // transfer NFT to winner
        carbonToken.safeTransferFrom(address(this), a.highestBidder, a.creditId, 1, "");
    }
    logAction("AuctionFinalized");
}
function paySubscription() external payable nonReentrant {
    Subscription storage s = subscriptions[msg.sender];
    require(s.active, "No plan");
    require(msg.value == s.amountPerMonth, "Wrong amount");
    // extend nextDue by 30 days (or plan period)
    if (s.nextDue < block.timestamp) s.nextDue = block.timestamp;
    s.nextDue += 30 days;
    // handle funds
    uint256 afterDonation = donatePortion(msg.value);
    splitFees(afterDonation);
    logAction("SubscriptionPaid");
}
function retireCreditFor(address user, uint256 _creditId, uint256 _amount) public onlyRelayer nonReentrant {
    // require the contract holds user's tokens or user approved relayer to burn from user's balance
    carbonToken.safeTransferFrom(user, address(this), _creditId, _amount, "");
    carbonToken.burn(address(this), _creditId, _amount); // if CarbonToken supports burn
    totalRetiredCredits[user] += _amount;
    updateTitle(user);
    issueRetirementNFT(user, _creditId, _amount);
    logAction("RetiredForUser");
}
function buybackAndBurn(uint256 creditId, uint256 amount) external payable onlyAdmin nonReentrant {
    // admin sends ETH, contract buys (offchain) or directly accepts tokens and burns
    // Here: if tokens are sent to contract:
    carbonToken.burn(address(this), creditId, amount);
    logAction("BuybackBurn");
}
uint256 public insurancePool;
function fundInsurance() external payable {
    insurancePool += msg.value;
    logAction("InsuranceFunded");
}

function payoutInsurance(address to, uint256 amount) external onlyAdmin nonReentrant {
    require(insurancePool >= amount, "Insufficient pool");
    insurancePool -= amount;
    payable(to).transfer(amount);
    logAction("InsurancePayout");
}
mapping(uint256 => uint256) public royaltyBps; // creditId => bps
mapping(uint256 => address) public originalIssuer;

function setRoyalty(uint256 creditId, address issuer, uint256 bps) external onlyAdmin {
    royaltyBps[creditId] = bps; originalIssuer[creditId] = issuer;
}

function buyListedCredit(uint256 listingId) external payable override nonReentrant {
    Listing storage l = listings[listingId];
    require(l.active, "Not active");
    require(msg.value == l.price, "Incorrect price");
    l.active = false;

    uint256 royalty = (msg.value * royaltyBps[l.creditId]) / 10000;
    uint256 sellerAmount = msg.value - royalty;
    if (royalty > 0) payable(originalIssuer[l.creditId]).transfer(royalty);
    payable(l.seller).transfer(sellerAmount);
    // transfer NFT
    emit Purchased(listingId, msg.sender);
}
// Simplified: create an ERC20 representing fractions off-chain or via factory
event Fractionalized(uint256 creditId, address fractionalToken, uint256 totalShares);

function fractionalize(uint256 creditId, address fractionalToken, uint256 totalShares) external onlyAdmin {
    // lock/burn original NFT and issue ERC20 fractions to owner
    emit Fractionalized(creditId, fractionalToken, totalShares);
}
for (uint i = 0; i < ids.length; i++) {
    unchecked { /* increment only */ }
    // operations
}
mapping(address => bool) public kycVerified;

function setKYC(address user, bool ok) external onlyAdmin {
    kycVerified[user] = ok;
    logAction("KYCUpdated");
}

modifier onlyKYC() {
    require(kycVerified[_msgSender()], "KYC required");
    _;
}
event TradeCompletedDetailed(uint256 escrowId, address buyer, address seller, uint256 amount, uint256 price, uint256 timestamp);

function _emitTradeDetailed(Escrow storage esc) internal {
    emit TradeCompletedDetailed(esc.id, esc.buyer, esc.seller, esc.amount, esc.price, block.timestamp);
}
uint256 public flashFeeBps = 5; // 0.05% = 5 bps

function flashLoan(uint256 amount) external nonReentrant {
    uint256 balanceBefore = carbonToken.balanceOf(address(this));
    require(balanceBefore >= amount, "Insufficient liquidity");
    carbonToken.transfer(msg.sender, amount);

    // call back hook: user must call `repayFlashLoan` in same tx (or handle via checks)
    // After user logic, require balance restored + fee
    uint256 required = amount + (amount * flashFeeBps) / 10000;
    require(carbonToken.balanceOf(address(this)) >= balanceBefore + (required - amount), "Loan+fee not returned");

    // credit fee to treasury or staking pool
    uint256 fee = (amount * flashFeeBps) / 10000;
    flashLoanDebt[msg.sender] += fee;
    // optionally distribute fee immediately
    // splitFees(fee);
}
function buyBundle(uint256 bundleId) external payable nonReentrant {
    Bundle storage b = bundles[bundleId];
    require(b.active, "Inactive");
    require(msg.value == b.price, "Wrong price");

    b.active = false;
    // transfer price minus donation/fees
    uint256 afterDonation = donatePortion(msg.value);
    splitFees(afterDonation);

    // transfer ERC1155 tokens from contract to buyer (assumes bundle held by contract)
    for (uint i = 0; i < b.creditIds.length; i++) {
        carbonToken.safeTransferFrom(address(this), msg.sender, b.creditIds[i], b.amounts[i], "");
    }
    logAction("BundlePurchased");
}

