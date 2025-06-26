// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TrustEstate is ERC721, Ownable, AccessControl, ReentrancyGuard {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");

    address payable public immutable agencyWallet;
    address payable public immutable governmentWallet;

    uint256 private _propertyIds = 0;

    enum VerificationStatus { PENDING, APPROVED, REJECTED }

    struct PropertyInfo {
        string title;
        string location;
        string propertyType;
        uint256 size;
        uint256 bedrooms;
        uint256 bathrooms;
        string features;
        string description;
        string documentHash;
        string surveyReportHash;
    }

    struct PropertyStatus {
        bool isRegistered;
        VerificationStatus verificationStatus;
        bool isMinted;
        bool isForSale;
        bool isForRent;
        uint256 salePrice;
        uint256 rentPrice;
        address owner;
        address verifiedBy;
    }

    struct PropertyTimestamps {
        uint256 registeredAt;
        uint256 verifiedAt;
        uint256 mintedAt;
    }

    struct Agent {
        address agentAddress;
        string name;
        string contactInfo;
        bool isActive;
        VerificationStatus verificationStatus;
    }

    struct RentalInfo {
        address tenant;
        uint256 startTime;
        uint256 duration;
        bool isActive;
    }

     struct FeeConfiguration {
        uint256 agencyFeePercent;     // Basis points (1% = 100)
        uint256 governmentFeePercent; // Basis points
        uint256 processingFeeFlat;    // Flat amount in wei
        uint256 agentCommissionPercent; // Basis points
        bool feesEnabled;
    }

    FeeConfiguration public feeConfig;

    // Events for fee updates
    event FeesUpdated(
        uint256 agencyFeePercent,
        uint256 governmentFeePercent,
        uint256 processingFeeFlat,
        uint256 agentCommissionPercent,
        bool feesEnabled
    );

    // Mappings
    mapping(uint256 => PropertyInfo) public propertyInfo;
    mapping(uint256 => PropertyStatus) public propertyStatus;
    mapping(uint256 => PropertyTimestamps) public propertyTimestamps;
    mapping(uint256 => RentalInfo) public rentalInfo;
    mapping(address => uint256[]) public ownerProperties;
    mapping(address => Agent) public agents;
    mapping(address => bool) public registeredUsers;
    mapping(uint256 => address[]) public propertyViewers;

    address[] public registeredAgents;

    // Events
    event UserRegistered(address indexed user);
    event AgentRegistered(address indexed agent, string name);
    event AgentVerified(address indexed agent, VerificationStatus status);
    event PropertyRegistered(uint256 indexed propertyId, address indexed owner);
    event PropertyVerified(uint256 indexed propertyId, VerificationStatus status, address verifiedBy);
    event PropertyMinted(uint256 indexed tokenId, address indexed owner);
    event PropertyListedForSale(uint256 indexed propertyId, uint256 price);
    event PropertyListedForRent(uint256 indexed propertyId, uint256 price);
    event PropertySold(uint256 indexed propertyId, address indexed buyer, uint256 price);
    event PropertyRented(uint256 indexed propertyId, address indexed tenant, uint256 price);
    event RentalEnded(uint256 indexed propertyId, address indexed tenant);
    event OwnershipTransferred(uint256 indexed propertyId, address indexed previousOwner, address indexed newOwner);
    event PropertyViewed(uint256 indexed propertyId, address indexed viewer);

    constructor(address payable _agencyWallet, address payable _governmentWallet) 
        ERC721("TrustEstateProperty", "TEP") 
        Ownable(msg.sender) 
    {
        require(_agencyWallet != address(0), "Invalid agency wallet");
        require(_governmentWallet != address(0), "Invalid government wallet");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNMENT_ROLE, msg.sender);

        agencyWallet = _agencyWallet;
        governmentWallet = _governmentWallet;
    }

    // ========== MODIFIERS ==========
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyGovernment() {
        require(hasRole(GOVERNMENT_ROLE, msg.sender), "Caller is not a government agent");
        _;
    }

    modifier onlyAgent() {
        require(hasRole(AGENT_ROLE, msg.sender), "Caller is not an agent");
        _;
    }

    modifier onlyOwnerOfProperty(uint256 propertyId) {
        require(propertyStatus[propertyId].owner == msg.sender, "Not the owner");
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        require(propertyStatus[propertyId].isRegistered, "Property does not exist");
        _;
    }

    // ========== USER FUNCTIONS ==========
    function registerUser() public {
        require(!registeredUsers[msg.sender], "Already registered");
        registeredUsers[msg.sender] = true;
        emit UserRegistered(msg.sender);
    }

    // ========== AGENT FUNCTIONS ==========
    function registerAgent(
        address agentAddress, 
        string memory name, 
        string memory contactInfo
    ) public onlyAdmin {
        require(agentAddress != address(0), "Invalid agent address");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(!agents[agentAddress].isActive, "Agent already registered");

        agents[agentAddress] = Agent({
            agentAddress: agentAddress,
            name: name,
            contactInfo: contactInfo,
            isActive: true,
            verificationStatus: VerificationStatus.PENDING
        });

        _grantRole(AGENT_ROLE, agentAddress);
        registeredAgents.push(agentAddress);
        emit AgentRegistered(agentAddress, name);
    }

    // In the verifyAgent function, 
    function verifyAgent(address agentAddress, VerificationStatus status) public {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(GOVERNMENT_ROLE, msg.sender),
            "Only admin or government can verify"  // Updated error message
        );
        require(agents[agentAddress].isActive, "Agent not registered");
        agents[agentAddress].verificationStatus = status;
        emit AgentVerified(agentAddress, status);
    }

    modifier onlyAdminOrGovernment() {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(GOVERNMENT_ROLE, msg.sender),
            "Not authorized"
        );
        _;
    }

    // ========== PROPERTY FUNCTIONS ==========
    function registerProperty(
        string memory _title,
        string memory _location,
        string memory _propertyType,
        uint256 _size,
        uint256 _bedrooms,
        uint256 _bathrooms,
        string memory _features,
        string memory _description,
        string memory _documentHash
    ) public returns (uint256) {
        require(registeredUsers[msg.sender], "Not a registered user");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_size > 0, "Size must be positive");
        require(bytes(_documentHash).length > 0, "Document hash required");

        uint256 newId = _propertyIds++;

        propertyInfo[newId] = PropertyInfo({
            title: _title,
            location: _location,
            propertyType: _propertyType,
            size: _size,
            bedrooms: _bedrooms,
            bathrooms: _bathrooms,
            features: _features,
            description: _description,
            documentHash: _documentHash,
            surveyReportHash: ""
        });

        propertyStatus[newId] = PropertyStatus({
            isRegistered: true,
            verificationStatus: VerificationStatus.PENDING,
            isMinted: false,
            isForSale: false,
            isForRent: false,
            salePrice: 0,
            rentPrice: 0,
            owner: msg.sender,
            verifiedBy: address(0)
        });

        propertyTimestamps[newId] = PropertyTimestamps({
            registeredAt: block.timestamp,
            verifiedAt: 0,
            mintedAt: 0
        });

        ownerProperties[msg.sender].push(newId);
        emit PropertyRegistered(newId, msg.sender);
        return newId;
    }

    function submitSurveyReport(
        uint256 propertyId, 
        string memory reportHash
    ) public onlyGovernment propertyExists(propertyId) {
        propertyInfo[propertyId].surveyReportHash = reportHash;
    }

    function verifyProperty(
        uint256 propertyId, 
        VerificationStatus status
    ) public onlyAdminOrGovernment propertyExists(propertyId) {
        propertyStatus[propertyId].verificationStatus = status;
        propertyStatus[propertyId].verifiedBy = msg.sender;
        
        if (status == VerificationStatus.APPROVED) {
            propertyTimestamps[propertyId].verifiedAt = block.timestamp;
        } else {
            propertyTimestamps[propertyId].verifiedAt = 0;
        }

        emit PropertyVerified(propertyId, status, msg.sender);
    }

    // ========== SALES & RENTAL FUNCTIONS ==========
    function listPropertyForSale(
        uint256 propertyId, 
        uint256 price
    ) public onlyOwnerOfProperty(propertyId) propertyExists(propertyId) {
        require(price > 0, "Price must be greater than 0");
        require(
            propertyStatus[propertyId].verificationStatus == VerificationStatus.APPROVED,
            "Property not approved"
        );
        require(!rentalInfo[propertyId].isActive, "Property is currently rented");

        propertyStatus[propertyId].isForSale = true;
        propertyStatus[propertyId].salePrice = price;
        propertyStatus[propertyId].isForRent = false;

        emit PropertyListedForSale(propertyId, price);
    }

    function listPropertyForRent(
        uint256 propertyId, 
        uint256 price, 
        uint256 duration
    ) public onlyOwnerOfProperty(propertyId) propertyExists(propertyId) {
        require(price > 0, "Price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(
            propertyStatus[propertyId].verificationStatus == VerificationStatus.APPROVED,
            "Property not approved"
        );
        require(!propertyStatus[propertyId].isForSale, "Property is listed for sale");

        propertyStatus[propertyId].isForRent = true;
        propertyStatus[propertyId].rentPrice = price;
        rentalInfo[propertyId] = RentalInfo({
            tenant: address(0),
            startTime: 0,
            duration: duration,
            isActive: false
        });

        emit PropertyListedForRent(propertyId, price);
    }

    function purchaseProperty(
    uint256 propertyId
) public payable nonReentrant propertyExists(propertyId) {
    require(registeredUsers[msg.sender], "Not registered");
    require(propertyStatus[propertyId].isForSale, "Not for sale");
    require(msg.sender != propertyStatus[propertyId].owner, "Cannot buy your own property");

    address seller = propertyStatus[propertyId].owner;
    uint256 amount = propertyStatus[propertyId].salePrice; // Base price

    // Get fee breakdown
    (
        uint256 agencyCut,
        uint256 governmentCut,
        uint256 agentCommissionCut,
        uint256 flatProcessingFee // This is the flat fee the buyer pays extra
    ) = getFeeBreakdown(amount); // Use new function name

    uint256 totalAmountDueFromBuyer = amount + flatProcessingFee;
    require(msg.value >= totalAmountDueFromBuyer, "Insufficient payment including fees");

    // Calculate seller's proceeds: base amount minus percentage-based cuts
    uint256 sellerProceeds = amount - (agencyCut + governmentCut + agentCommissionCut);
    
    // Transfer fees and proceeds
    agencyWallet.transfer(agencyCut + flatProcessingFee); // Agency gets its percentage + the flat processing fee
    governmentWallet.transfer(governmentCut);
    
    // Transfer agent commission or send to agency if not agent
    if (hasRole(AGENT_ROLE, seller)) {
        payable(seller).transfer(agentCommissionCut); // Agent receives commission
    } else {
        agencyWallet.transfer(agentCommissionCut); // Commission goes to agency if seller is not agent
    }

    // Seller receives their net proceeds
    payable(seller).transfer(sellerProceeds);

    // Update state before NFT transfer and ownership records
    propertyStatus[propertyId].owner = msg.sender;
    propertyStatus[propertyId].isForSale = false;

    // Update ownership records
    removePropertyFromOwner(seller, propertyId);
    ownerProperties[msg.sender].push(propertyId);

    // If the property was minted as an NFT, transfer the NFT as well
    if (propertyStatus[propertyId].isMinted) { // Corrected: Use propertyStatus[propertyId].isMinted
        _transfer(seller, msg.sender, propertyId); // Transfer the ERC721 token
    }

    // Refund any excess payment
    if (msg.value > totalAmountDueFromBuyer) {
        payable(msg.sender).transfer(msg.value - totalAmountDueFromBuyer);
    }

    emit PropertySold(propertyId, msg.sender, amount);
    emit OwnershipTransferred(propertyId, seller, msg.sender);
}

    function rentProperty(
        uint256 propertyId
    ) public payable nonReentrant propertyExists(propertyId) {
        require(registeredUsers[msg.sender], "Not registered");
        require(propertyStatus[propertyId].isForRent, "Not for rent");
        require(!rentalInfo[propertyId].isActive, "Property already rented");

        address landlord = propertyStatus[propertyId].owner;
        uint256 amount = propertyStatus[propertyId].rentPrice; // Base rent price
        
        // Get fee breakdown
        (
            uint256 agencyCut,
            uint256 governmentCut,
            uint256 agentCommissionCut,
            uint256 flatProcessingFee // This is the flat fee the buyer pays extra
        ) = getFeeBreakdown(amount); // Use new function name

        uint256 totalAmountDueFromBuyer = amount + flatProcessingFee;
        require(msg.value >= totalAmountDueFromBuyer, "Insufficient payment including fees");

        // Calculate landlord's proceeds: base amount minus percentage-based cuts
        uint256 landlordProceeds = amount - (agencyCut + governmentCut + agentCommissionCut);

        // Update rental info
        rentalInfo[propertyId] = RentalInfo({
            tenant: msg.sender,
            startTime: block.timestamp,
            duration: rentalInfo[propertyId].duration, // Keep original duration
            isActive: true
        });

        // Transfer fees and proceeds
        agencyWallet.transfer(agencyCut + flatProcessingFee); // Agency gets its percentage + the flat processing fee
        governmentWallet.transfer(governmentCut);
        
        // Transfer agent commission or send to agency if not agent
        if (hasRole(AGENT_ROLE, landlord)) {
            payable(landlord).transfer(agentCommissionCut); // Agent receives commission
        } else {
            agencyWallet.transfer(agentCommissionCut); // Commission goes to agency if landlord is not agent
        }

        // Landlord receives their net proceeds
        payable(landlord).transfer(landlordProceeds);

        // Refund any excess payment
        if (msg.value > totalAmountDueFromBuyer) {
            payable(msg.sender).transfer(msg.value - totalAmountDueFromBuyer);
        }

        emit PropertyRented(propertyId, msg.sender, amount);
    }

    function endRental(uint256 propertyId) public propertyExists(propertyId) {
        require(
            rentalInfo[propertyId].isActive,
            "No active rental"
        );
        require(
            msg.sender == propertyStatus[propertyId].owner || 
            msg.sender == rentalInfo[propertyId].tenant,
            "Not authorized"
        );
        require(
            block.timestamp >= rentalInfo[propertyId].startTime + rentalInfo[propertyId].duration,
            "Rental period not ended"
        );

        rentalInfo[propertyId].isActive = false;
        emit RentalEnded(propertyId, rentalInfo[propertyId].tenant);
    }

    // ========== NFT FUNCTIONS ==========
   function mintPropertyNFT(uint256 propertyId) public onlyOwnerOfProperty(propertyId) propertyExists(propertyId) {
        require(
            propertyStatus[propertyId].verificationStatus == VerificationStatus.APPROVED,
            "Property not approved"
        );
        require(!propertyStatus[propertyId].isMinted, "Token already minted");
        require(!propertyStatus[propertyId].isForRent || !rentalInfo[propertyId].isActive, "Property is currently rented");

        _safeMint(msg.sender, propertyId);
        propertyStatus[propertyId].isMinted = true;
        propertyTimestamps[propertyId].mintedAt = block.timestamp;
        
        emit PropertyMinted(propertyId, msg.sender);
    }

    // ========== VIEW FUNCTIONS ==========
    function viewProperty(uint256 propertyId) public propertyExists(propertyId) {
        require(registeredUsers[msg.sender], "Not registered");
        propertyViewers[propertyId].push(msg.sender);
        emit PropertyViewed(propertyId, msg.sender);
    }

    // New view function to get all viewers for a property
    function getPropertyViewers(uint256 _propertyId) public view propertyExists(_propertyId) returns (address[] memory) {
        return propertyViewers[_propertyId];
    }

    function verifyPropertyAsBuyer(
        uint256 propertyId
    ) public view propertyExists(propertyId) returns (
        bool isVerified,
        VerificationStatus status,
        address verifiedBy,
        string memory surveyReport
    ) {
        return (
            propertyStatus[propertyId].verificationStatus == VerificationStatus.APPROVED,
            propertyStatus[propertyId].verificationStatus,
            propertyStatus[propertyId].verifiedBy,
            propertyInfo[propertyId].surveyReportHash
        );
    }

    function getApprovedProperties() public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_propertyIds);
        uint256 count = 0;

        for (uint256 i = 0; i < _propertyIds; i++) {
            if (propertyStatus[i].verificationStatus == VerificationStatus.APPROVED) {
                result[count] = i;
                count++;
            }
        }

        uint256[] memory approved = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            approved[j] = result[j];
        }
        
        return approved;
    }

    function getAgents() public view returns (
        address[] memory,
        string[] memory,
        VerificationStatus[] memory
    ) {
        uint256 count = registeredAgents.length;
        address[] memory agentAddresses = new address[](count);
        string[] memory names = new string[](count);
        VerificationStatus[] memory statuses = new VerificationStatus[](count);

        for (uint256 i = 0; i < count; i++) {
            agentAddresses[i] = registeredAgents[i];
            names[i] = agents[registeredAgents[i]].name;
            statuses[i] = agents[registeredAgents[i]].verificationStatus;
        }

        return (agentAddresses, names, statuses);
    }

    function getOwnerProperties(address owner) public view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    // ========== FEE CONFIGURATION FUNCTIONS ==========
    function setFees(
        uint256 _agencyFeePercent,
        uint256 _governmentFeePercent,
        uint256 _processingFeeFlat,
        uint256 _agentCommissionPercent,
        bool _feesEnabled
    ) external onlyAdmin {
        require(_agencyFeePercent <= 2000, "Agency fee too high"); // Max 20% (2000 basis points)
        require(_governmentFeePercent <= 1000, "Government fee too high"); // Max 10% (1000 basis points)
        require(_agentCommissionPercent <= 2000, "Agent commission too high"); // Max 20% (2000 basis points)

        feeConfig = FeeConfiguration({
            agencyFeePercent: _agencyFeePercent,
            governmentFeePercent: _governmentFeePercent,
            processingFeeFlat: _processingFeeFlat,
            agentCommissionPercent: _agentCommissionPercent,
            feesEnabled: _feesEnabled
        });

        emit FeesUpdated(
            _agencyFeePercent,
            _governmentFeePercent,
            _processingFeeFlat,
            _agentCommissionPercent,
            _feesEnabled
        );
    }

    // New function to provide a breakdown of fees without calculating net amount for seller
    function getFeeBreakdown(uint256 amount) public view returns (
        uint256 agencyCut,         // Percentage based for agency
        uint256 governmentCut,      // Percentage based for government
        uint256 agentCommissionCut, // Percentage based for agent
        uint256 flatProcessingFee   // Flat fee from buyer, always goes to agency
    ) {
        if (!feeConfig.feesEnabled) {
            return (0, 0, 0, 0);
        }

        agencyCut = (amount * feeConfig.agencyFeePercent) / 10000;
        governmentCut = (amount * feeConfig.governmentFeePercent) / 10000;
        agentCommissionCut = (amount * feeConfig.agentCommissionPercent) / 10000;
        flatProcessingFee = feeConfig.processingFeeFlat;
        
        // Validate that the total percentage-based cuts don't exceed the amount
        // The flatProcessingFee is separate and paid on top by the buyer.
        uint256 totalDeductiblePercentageFees = agencyCut + governmentCut + agentCommissionCut;
        require(totalDeductiblePercentageFees < amount, "Percentage fees exceed transaction amount");
    }


    // ========== UTILITY FUNCTIONS ==========
    function removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage props = ownerProperties[owner];
        for (uint256 i = 0; i < props.length; i++) {
            if (props[i] == propertyId) {
                props[i] = props[props.length - 1];
                props.pop();
                break;
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}
