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
