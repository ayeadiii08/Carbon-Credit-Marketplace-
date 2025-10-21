function calculateDynamicFee(address user, uint256 baseFee) public view returns (uint256) {
    uint256 rep = getReputationScore(user);
    if (rep > 90) return (baseFee * 80) / 100; // 20% discount
    if (rep > 75) return (baseFee * 90) / 100;
    return baseFee;
}
address public oracle;
event OracleUpdated(string category, string data);

function setOracle(address _oracle) external onlyAdmin { oracle = _oracle; }

function updateFromOracle(string calldata category, string calldata data) external {
    require(msg.sender == oracle, "Not oracle");
    emit OracleUpdated(category, data);
}
uint256 public donationPercent = 2; // 2%
address public donationWallet;

function setDonationWallet(address _wallet) external onlyAdmin { donationWallet = _wallet; }

function donatePortion(uint256 amount) internal returns (uint256 afterDonation) {
    uint256 donation = (amount * donationPercent) / 100;
    if (donationWallet != address(0) && donation > 0) {
        payable(donationWallet).transfer(donation);
    }
    return amount - donation;
}
mapping(address => bool) public trustedRelayers;

function setRelayer(address relayer, bool status) external onlyAdmin {
    trustedRelayers[relayer] = status;
}

modifier onlyRelayer() {
    require(trustedRelayers[msg.sender], "Not a relayer");
    _;
}

function executeForUser(address user, bytes calldata data) external onlyRelayer {
    (bool success, ) = address(this).call(abi.encodePacked(data, user));
    require(success, "Execution failed");
}
struct VaultTx {
    address to;
    uint256 amount;
    uint256 confirmations;
    bool executed;
}
mapping(uint256 => VaultTx) public vaultTxs;
mapping(uint256 => mapping(address => bool)) public vaultConfirmations;
uint256 public vaultTxCount;

event VaultSubmitted(uint256 txId, address to, uint256 amount);
event VaultExecuted(uint256 txId);

function submitVaultTx(address to, uint256 amount) external onlyAdmin {
    vaultTxs[vaultTxCount] = VaultTx(to, amount, 0, false);
    emit VaultSubmitted(vaultTxCount, to, amount);
    vaultTxCount++;
}

function confirmVaultTx(uint256 txId) external onlyAdmin {
    require(!vaultConfirmations[txId][msg.sender], "Already confirmed");
    vaultConfirmations[txId][msg.sender] = true;
    vaultTxs[txId].confirmations++;
    if (vaultTxs[txId].confirmations >= requiredAdminConfirmations()) {
        payable(vaultTxs[txId].to).transfer(vaultTxs[txId].amount);
        vaultTxs[txId].executed = true;
        emit VaultExecuted(txId);
    }
}
struct Listing {
    address seller;
    uint256 creditId;
    uint256 price;
    bool active;
}
mapping(uint256 => Listing) public listings;
uint256 public nextListingId;

event Listed(uint256 listingId, address seller, uint256 creditId, uint256 price);
event Purchased(uint256 listingId, address buyer);

function listCredit(uint256 creditId, uint256 price) external {
    listings[nextListingId] = Listing(msg.sender, creditId, price, true);
    emit Listed(nextListingId, msg.sender, creditId, price);
    nextListingId++;
}

function buyListedCredit(uint256 listingId) external payable {
    Listing storage l = listings[listingId];
    require(l.active, "Not active");
    require(msg.value == l.price, "Incorrect price");
    l.active = false;
    payable(l.seller).transfer(msg.value);
    // transfer credit NFT off-chain or via ERC1155 safeTransfer
    emit Purchased(listingId, msg.sender);
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

function propose(string calldata desc) external onlyAdmin {
    proposals[proposalCount] = Proposal(desc, 0, 0, block.timestamp + 3 days, false);
    logAction("ProposalCreated");
    proposalCount++;
}

function vote(uint256 proposalId, bool support) external {
    require(block.timestamp < proposals[proposalId].endTime, "Voting ended");
    uint256 votes = govToken.balanceOf(msg.sender) + delegatedVotes[msg.sender];
    if (support) proposals[proposalId].votesFor += votes;
    else proposals[proposalId].votesAgainst += votes;
}

function executeProposal(uint256 proposalId) external onlyAdmin {
    Proposal storage p = proposals[proposalId];
    require(!p.executed && block.timestamp >= p.endTime, "Not ready");
    p.executed = true;
    logAction("ProposalExecuted");
}
struct UserStats { uint256 retired; uint256 points; }
mapping(address => UserStats) public userStats;

function updateLeaderboard(address user, uint256 amount) internal {
    userStats[user].retired += amount;
    userStats[user].points += amount / 10;
    emitAnalytics(user, "Leaderboard", "CreditRetired", amount);
}
AggregatorV3Interface public priceFeed;

function setPriceFeed(address feed) external onlyAdmin {
    priceFeed = AggregatorV3Interface(feed);
}

function getLiveCarbonPrice() public view returns (uint256) {
    (, int price,,,) = priceFeed.latestRoundData();
    return uint256(price);
}
function emergencySelfDestruct(address payable to) external onlyOwner {
    logAction("SelfDestruct Initiated");
    selfdestruct(to);
}
