// SPDX-License-Identifier: 
pragma solidity ^0.8.19;

contract CarbonCreditMarketplace {
    struct CarbonCredit {
        uint256 id;
        string projectName;
        uint256 amount;
        uint256 pricePerTon;
        address seller;
        bool isActive;
        string verificationHash;
        uint256 vintage;
        uint256 timestamp;
    }

    struct Purchase {
        uint256 creditId;
        address buyer;
        uint256 amount;
        uint256 totalPrice;
        uint256 timestamp;
    }

    mapping(uint256 => CarbonCredit) public carbonCredits;
    mapping(uint256 => Purchase[]) public creditPurchases;
    mapping(address => uint256[]) public userCredits;
    mapping(address => uint256) public userBalances; // Track retired credits

    uint256 public nextCreditId = 1;
    uint256 public totalCreditsListed;
    uint256 public totalCreditsSold;
    uint256 public totalCreditsRetired;

    event CreditListed(
        uint256 indexed creditId,
        string projectName,
        uint256 amount,
        uint256 pricePerTon,
        address indexed seller,
        uint256 vintage
    );

    event CreditPurchased(
        uint256 indexed creditId,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice,
        uint256 timestamp
    );

    event CreditRetired(
        uint256 indexed creditId,
        address indexed buyer,
        uint256 amount,
        uint256 timestamp
    );

    modifier nonZeroAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }

    modifier validCredit(uint256 _creditId) {
        require(_creditId > 0 && _creditId < nextCreditId, "Invalid credit ID");
        require(carbonCredits[_creditId].isActive, "Credit not active");
        _;
    }

    function listCarbonCredit(
        string memory _projectName,
        uint256 _amount,
        uint256 _pricePerTon,
        string memory _verificationHash,
        uint256 _vintage
    ) external nonZeroAmount(_amount) returns (uint256) {
        require(_pricePerTon > 0, "Price must be greater than 0");
        require(bytes(_projectName).length > 0, "Project name required");
        require(bytes(_verificationHash).length > 0, "Verification hash required");
        require(_vintage >= 2000 && _vintage <= getCurrentYear(), "Invalid vintage year");

        uint256 creditId = nextCreditId++;

        carbonCredits[creditId] = CarbonCredit({
            id: creditId,
            projectName: _projectName,
            amount: _amount,
            pricePerTon: _pricePerTon,
            seller: msg.sender,
            isActive: true,
            verificationHash: _verificationHash,
            vintage: _vintage,
            timestamp: block.timestamp
        });

        userCredits[msg.sender].push(creditId);
        totalCreditsListed += _amount;

        emit CreditListed(creditId, _projectName, _amount, _pricePerTon, msg.sender, _vintage);

        return creditId;
    }

    function purchaseCarbonCredit(uint256 _creditId, uint256 _amount) 
        external 
        payable 
        validCredit(_creditId)
        nonZeroAmount(_amount)
    {
        CarbonCredit storage credit = carbonCredits[_creditId];
        require(_amount <= credit.amount, "Insufficient credits available");
        require(msg.sender != credit.seller, "Cannot buy your own credits");

        uint256 totalPrice = _amount * credit.pricePerTon;
        require(msg.value >= totalPrice, "Insufficient payment");

        credit.amount -= _amount;
        if (credit.amount == 0) {
            credit.isActive = false;
        }

        creditPurchases[_creditId].push(Purchase({
            creditId: _creditId,
            buyer: msg.sender,
            amount: _amount,
            totalPrice: totalPrice,
            timestamp: block.timestamp
        }));

        totalCreditsSold += _amount;

        uint256 platformFee = totalPrice / 10;
        uint256 sellerAmount = totalPrice - platformFee;

        payable(credit.seller).transfer(sellerAmount);
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit CreditPurchased(_creditId, msg.sender, _amount, totalPrice, block.timestamp);
    }

    function retireCarbonCredit(uint256 _creditId, uint256 _amount) 
        external 
        nonZeroAmount(_amount)
    {
        require(_creditId > 0 && _creditId < nextCreditId, "Invalid credit ID");

        Purchase[] memory purchases = creditPurchases[_creditId];
        uint256 userPurchased = 0;

        for (uint256 i = 0; i < purchases.length; i++) {
            if (purchases[i].buyer == msg.sender) {
                userPurchased += purchases[i].amount;
            }
        }

        require(userPurchased >= _amount, "Insufficient credit balance");

        userBalances[msg.sender] += _amount;
        totalCreditsRetired += _amount;

        emit CreditRetired(_creditId, msg.sender, _amount, block.timestamp);
    }

    function getCarbonCredit(uint256 _creditId) 
        external 
        view 
        returns (CarbonCredit memory) 
    {
        require(_creditId > 0 && _creditId < nextCreditId, "Invalid credit ID");
        return carbonCredits[_creditId];
    }

    function getUserCredits(address _user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userCredits[_user];
    }

    function getCreditPurchases(uint256 _creditId) 
        external 
        view 
        returns (Purchase[] memory) 
    {
        require(_creditId > 0 && _creditId < nextCreditId, "Invalid credit ID");
        return creditPurchases[_creditId];
    }

    function getUserRetiredCredits(address _user) 
        external 
        view 
        returns (uint256) 
    {
        return userBalances[_user];
    }

    function getMarketplaceStats() 
        external 
        view 
        returns (uint256 totalListed, uint256 totalSold, uint256 totalRetired, uint256 activeCredits) 
    {
        return (totalCreditsListed, totalCreditsSold, totalCreditsRetired, nextCreditId - 1);
    }

    function getActiveCredits() 
        external 
        view 
        returns (CarbonCredit[] memory) 
    {
        uint256 activeCount = 0;

        for (uint256 i = 1; i < nextCreditId; i++) {
            if (carbonCredits[i].isActive) {
                activeCount++;
            }
        }

        CarbonCredit[] memory activeCredits = new CarbonCredit[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 1; i < nextCreditId; i++) {
            if (carbonCredits[i].isActive) {
                activeCredits[currentIndex] = carbonCredits[i];
                currentIndex++;
            }
        }

        return activeCredits;
    }

    function getCurrentYear() private view returns (uint256) {
        return 1970 + (block.timestamp / 365 days);
    }

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner).transfer(balance);
    }

    function updateOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
}








