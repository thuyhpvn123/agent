// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";

contract RevenueManager is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    string public version;
    mapping(address => AgentRevenue) public agentRevenues;
    address[] public agentList;
    RevenueRecord[] public revenueRecords;
    
    Revenue public systemRevenue;
    
    // Time-based analytics
    mapping(uint256 => Revenue) public dailyRevenue; // timestamp (day) => revenue
    mapping(uint256 => Revenue) public monthlyRevenue; // timestamp (month) => revenue
    mapping(uint256 => Revenue) public yearlyRevenue; // timestamp (year) => revenue
    address public enhancedAgent;

    event AgentAdded(address indexed agent, uint256 timestamp);
    event RevenueRecorded(
        address indexed agent, 
        uint8 moduleType, 
        uint256 amount, 
        uint256 timestamp,
        string metadata
    );
    event RevenueUpdated(
        uint256 dailyTotal,
        uint256 monthlyTotal,
        uint256 yearlyTotal,
        uint256 timestamp
    );
    event ContractUpgraded(string oldVersion, string newVersion, uint256 timestamp);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        version = "1.0.0";
    }
     modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
    }

    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    /**
     * @dev Add new agent to revenue tracking
     */
    function addAgent(address _agent) external onlyEnhanceSC {
        require(_agent != address(0), "Invalid agent address");
        require(agentRevenues[_agent].agent == address(0), "Agent already exists");
        
        agentRevenues[_agent] = AgentRevenue({
            agent: _agent,
            iqr: 0,
            loyalty: 0,
            meos: 0,
            total: 0,
            lastUpdated: block.timestamp
        });
        
        agentList.push(_agent);
        emit AgentAdded(_agent, block.timestamp);
    }
    
    /**
     * @dev Record revenue for specific agent and module
     */
    function recordRevenue(
        address _agent, 
        uint8 _moduleType, 
        uint256 _amount,
        string memory _metadata
    ) external  {
        _recordSingleRevenue(_agent, _moduleType, _amount, _metadata);
    }
    
    /**
     * @dev Internal function for recording single revenue entry
     */
    function _recordSingleRevenue(
        address _agent,
        uint8 _moduleType,
        uint256 _amount,
        string memory _metadata
    ) internal {
        require(agentRevenues[_agent].agent != address(0), "Agent not found");
        require(_moduleType >= 1 && _moduleType <= 3, "Invalid module type");
        require(_amount > 0, "Amount must be greater than 0");
        
        AgentRevenue storage agentRev = agentRevenues[_agent];
        
        // Update agent revenue
        if (_moduleType == 1) { // IQR
            agentRev.iqr += _amount;
            systemRevenue.iqr += _amount;
        } else if (_moduleType == 2) { // Loyalty
            agentRev.loyalty += _amount;
            systemRevenue.loyalty += _amount;
        } else if (_moduleType == 3) { // MeOS
            agentRev.meos += _amount;
            systemRevenue.meos += _amount;
        }
        
        agentRev.total += _amount;
        agentRev.lastUpdated = block.timestamp;
        systemRevenue.total += _amount;
        
        // Record transaction
        revenueRecords.push(RevenueRecord({
            agent: _agent,
            moduleType: _moduleType,
            amount: _amount,
            timestamp: block.timestamp,
            metadata: _metadata
        }));
        
        // Update time-based analytics
        _updateTimeBasedRevenue(_moduleType, _amount);
        
        emit RevenueRecorded(_agent, _moduleType, _amount, block.timestamp, _metadata);
    }
    
    /**
     * @dev Batch record revenue (for efficiency)
     */
    function batchRecordRevenue(
        address[] memory _agents,
        uint8[] memory _moduleTypes,
        uint256[] memory _amounts,
        string[] memory _metadatas
    ) external onlyEnhanceSC {
        require(
            _agents.length == _moduleTypes.length &&
            _moduleTypes.length == _amounts.length &&
            _amounts.length == _metadatas.length,
            "Arrays length mismatch"
        );
        
        for (uint256 i = 0; i < _agents.length; i++) {
            _recordSingleRevenue(_agents[i], _moduleTypes[i], _amounts[i], _metadatas[i]);
        }
    }
    
    /**
     * @dev Update time-based revenue analytics
     */
    function _updateTimeBasedRevenue(uint8 _moduleType, uint256 _amount) internal {
        uint256 today = _getDayTimestamp(block.timestamp);
        uint256 thisMonth = _getMonthTimestamp(block.timestamp);
        uint256 thisYear = _getYearTimestamp(block.timestamp);
        
        // Update daily
        if (_moduleType == 1) {
            dailyRevenue[today].iqr += _amount;
            monthlyRevenue[thisMonth].iqr += _amount;
            yearlyRevenue[thisYear].iqr += _amount;
        } else if (_moduleType == 2) {
            dailyRevenue[today].loyalty += _amount;
            monthlyRevenue[thisMonth].loyalty += _amount;
            yearlyRevenue[thisYear].loyalty += _amount;
        } else if (_moduleType == 3) {
            dailyRevenue[today].meos += _amount;
            monthlyRevenue[thisMonth].meos += _amount;
            yearlyRevenue[thisYear].meos += _amount;
        }
        
        dailyRevenue[today].total += _amount;
        monthlyRevenue[thisMonth].total += _amount;
        yearlyRevenue[thisYear].total += _amount;
        
        emit RevenueUpdated(
            dailyRevenue[today].total,
            monthlyRevenue[thisMonth].total,
            yearlyRevenue[thisYear].total,
            block.timestamp
        );
    }
    
    /**
     * @dev Get day timestamp (start of day)
     */
    function _getDayTimestamp(uint256 _timestamp) internal pure returns (uint256) {
        return (_timestamp / 86400) * 86400; // 86400 = 24 * 60 * 60
    }
    
    /**
     * @dev Get month timestamp (start of month)
     */
    function _getMonthTimestamp(uint256 _timestamp) internal pure returns (uint256) {
        return (_timestamp / (86400 * 30)) * (86400 * 30);
    }
    
    /**
     * @dev Get year timestamp (start of year)
     */
    function _getYearTimestamp(uint256 _timestamp) internal pure returns (uint256) {
        return (_timestamp / (86400 * 365)) * (86400 * 365);
    }
    
    /**
     * @dev Remove agent (admin only - for cleanup)
     */
    function removeAgent(address _agent) external onlyOwner {
        require(agentRevenues[_agent].agent != address(0), "Agent not found");
        
        // Remove from agentList
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agentList[i] == _agent) {
                agentList[i] = agentList[agentList.length - 1];
                agentList.pop();
                break;
            }
        }
        
        // Clear agent revenue data (keep historical records)
        delete agentRevenues[_agent];
    }
    
    // ========================================================================
    // VIEW FUNCTIONS
    // ========================================================================
    
    /**
     * @dev Get system total revenue
     */
    function getSystemRevenue() 
        external 
        view 
        returns (uint256, uint256, uint256, uint256) 
    {
        return (
            systemRevenue.iqr,
            systemRevenue.loyalty,
            systemRevenue.meos,
            systemRevenue.total
        );
    }
    
    /**
     * @dev Get specific agent revenue
     */
    function getAgentRevenue(address _agent) 
        external 
        view 
        returns (uint256, uint256, uint256, uint256) 
    {
        AgentRevenue memory agentRev = agentRevenues[_agent];
        return (agentRev.iqr, agentRev.loyalty, agentRev.meos, agentRev.total);
    }
    
    /**
     * @dev Get all agents revenue
     */
    function getAllAgentsRevenue() 
        external 
        view 
        returns (AgentRevenue[] memory) 
    {
        AgentRevenue[] memory revenues = new AgentRevenue[](agentList.length);
        
        for (uint256 i = 0; i < agentList.length; i++) {
            revenues[i] = agentRevenues[agentList[i]];
        }
        
        return revenues;
    }
    
    /**
     * @dev Get revenue by time period
     */
    function getRevenueByPeriod(
        string memory _period, 
        uint256 _timestamp
    ) external view returns (Revenue memory) {
        if (keccak256(bytes(_period)) == keccak256(bytes("daily"))) {
            return dailyRevenue[_getDayTimestamp(_timestamp)];
        } else if (keccak256(bytes(_period)) == keccak256(bytes("monthly"))) {
            return monthlyRevenue[_getMonthTimestamp(_timestamp)];
        } else if (keccak256(bytes(_period)) == keccak256(bytes("yearly"))) {
            return yearlyRevenue[_getYearTimestamp(_timestamp)];
        }
        
        return Revenue(0, 0, 0, 0);
    }
    
    /**
     * @dev Get revenue by time range (more flexible than period)
     */
    function getRevenueByTimeRange(uint256 _fromTimestamp, uint256 _toTimestamp)
        external
        view
        returns (Revenue memory)
    {
        require(_fromTimestamp < _toTimestamp, "Invalid timestamp range");
        
        Revenue memory rangeRevenue;
        
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            RevenueRecord memory record = revenueRecords[i];
            
            if (record.timestamp >= _fromTimestamp && record.timestamp <= _toTimestamp) {
                if (record.moduleType == 1) {
                    rangeRevenue.iqr += record.amount;
                } else if (record.moduleType == 2) {
                    rangeRevenue.loyalty += record.amount;
                } else if (record.moduleType == 3) {
                    rangeRevenue.meos += record.amount;
                }
                rangeRevenue.total += record.amount;
            }
        }
        
        return rangeRevenue;
    }
    
    /**
     * @dev Get revenue records for agent
     */
    function getAgentRevenueRecords(address _agent) 
        external 
        view 
        returns (RevenueRecord[] memory) 
    {
        // Count records for this agent
        uint256 count = 0;
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            if (revenueRecords[i].agent == _agent) {
                count++;
            }
        }
        
        // Build result array
        RevenueRecord[] memory agentRecords = new RevenueRecord[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            if (revenueRecords[i].agent == _agent) {
                agentRecords[index] = revenueRecords[i];
                index++;
            }
        }
        
        return agentRecords;
    }
    
    /**
     * @dev Get recent revenue records (last N records)
     */
    function getRecentRevenueRecords(uint256 _limit) 
        external 
        view 
        returns (RevenueRecord[] memory) 
    {
        require(_limit > 0, "Limit must be greater than 0");
        
        uint256 startIndex = revenueRecords.length > _limit ? 
            revenueRecords.length - _limit : 0;
        uint256 actualLimit = revenueRecords.length - startIndex;
        
        RevenueRecord[] memory recentRecords = new RevenueRecord[](actualLimit);
        
        for (uint256 i = 0; i < actualLimit; i++) {
            recentRecords[i] = revenueRecords[startIndex + i];
        }
        
        return recentRecords;
    }
    
    /**
     * @dev Get revenue records by module type
     */
    function getRevenueRecordsByModule(uint8 _moduleType) 
        external 
        view 
        returns (RevenueRecord[] memory) 
    {
        require(_moduleType >= 1 && _moduleType <= 3, "Invalid module type");
        
        // Count records for this module
        uint256 count = 0;
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            if (revenueRecords[i].moduleType == _moduleType) {
                count++;
            }
        }
        
        // Build result array
        RevenueRecord[] memory moduleRecords = new RevenueRecord[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            if (revenueRecords[i].moduleType == _moduleType) {
                moduleRecords[index] = revenueRecords[i];
                index++;
            }
        }
        
        return moduleRecords;
    }
    
    /**
     * @dev Get total number of revenue records
     */
    function getTotalRevenueRecords() external view returns (uint256) {
        return revenueRecords.length;
    }
    
    /**
     * @dev Get revenue record by index
     */
    function getRevenueRecord(uint256 _index) 
        external 
        view 
        returns (RevenueRecord memory) 
    {
        require(_index < revenueRecords.length, "Record not found");
        return revenueRecords[_index];
    }
    
    /**
     * @dev Get top performing agents by revenue
     */
    function getTopAgentsByRevenue(uint256 _limit) 
        external 
        view 
        returns (address[] memory agents, uint256[] memory revenues) 
    {
        require(_limit > 0, "Limit must be greater than 0");
        uint256 actualLimit = _limit > agentList.length ? agentList.length : _limit;
        
        agents = new address[](actualLimit);
        revenues = new uint256[](actualLimit);
        
        // Create a copy of agent list with their revenues
        address[] memory tempAgents = new address[](agentList.length);
        uint256[] memory tempRevenues = new uint256[](agentList.length);
        
        for (uint256 i = 0; i < agentList.length; i++) {
            tempAgents[i] = agentList[i];
            tempRevenues[i] = agentRevenues[agentList[i]].total;
        }
        
        // Simple bubble sort (for small arrays)
        for (uint256 i = 0; i < agentList.length; i++) {
            for (uint256 j = 0; j < agentList.length - i - 1; j++) {
                if (tempRevenues[j] < tempRevenues[j + 1]) {
                    // Swap revenues
                    uint256 tempRev = tempRevenues[j];
                    tempRevenues[j] = tempRevenues[j + 1];
                    tempRevenues[j + 1] = tempRev;
                    
                    // Swap agents
                    address tempAgent = tempAgents[j];
                    tempAgents[j] = tempAgents[j + 1];
                    tempAgents[j + 1] = tempAgent;
                }
            }
        }
        
        // Take top performers
        for (uint256 i = 0; i < actualLimit; i++) {
            agents[i] = tempAgents[i];
            revenues[i] = tempRevenues[i];
        }
        
        return (agents, revenues);
    }
    
    /**
     * @dev Get agents by module performance
     */
    function getTopAgentsByModule(uint8 _moduleType, uint256 _limit)
        external
        view
        returns (address[] memory agents, uint256[] memory revenues)
    {
        require(_moduleType >= 1 && _moduleType <= 3, "Invalid module type");
        require(_limit > 0, "Limit must be greater than 0");
        uint256 actualLimit = _limit > agentList.length ? agentList.length : _limit;
        
        agents = new address[](actualLimit);
        revenues = new uint256[](actualLimit);
        
        // Create arrays for sorting
        address[] memory tempAgents = new address[](agentList.length);
        uint256[] memory tempRevenues = new uint256[](agentList.length);
        
        for (uint256 i = 0; i < agentList.length; i++) {
            tempAgents[i] = agentList[i];
            AgentRevenue memory agentRev = agentRevenues[agentList[i]];
            
            if (_moduleType == 1) {
                tempRevenues[i] = agentRev.iqr;
            } else if (_moduleType == 2) {
                tempRevenues[i] = agentRev.loyalty;
            } else if (_moduleType == 3) {
                tempRevenues[i] = agentRev.meos;
            }
        }
        
        // Sort by module revenue (descending)
        for (uint256 i = 0; i < agentList.length; i++) {
            for (uint256 j = 0; j < agentList.length - i - 1; j++) {
                if (tempRevenues[j] < tempRevenues[j + 1]) {
                    // Swap revenues
                    uint256 tempRev = tempRevenues[j];
                    tempRevenues[j] = tempRevenues[j + 1];
                    tempRevenues[j + 1] = tempRev;
                    
                    // Swap agents
                    address tempAgent = tempAgents[j];
                    tempAgents[j] = tempAgents[j + 1];
                    tempAgents[j + 1] = tempAgent;
                }
            }
        }
        
        // Take top performers
        for (uint256 i = 0; i < actualLimit; i++) {
            agents[i] = tempAgents[i];
            revenues[i] = tempRevenues[i];
        }
        
        return (agents, revenues);
    }
    
    /**
     * @dev Get revenue growth for agent (comparing periods)
     */
    function getAgentRevenueGrowth(address _agent, uint256 _fromTimestamp, uint256 _toTimestamp)
        external
        view
        returns (
            uint256 totalRevenue,
            uint256 iqrRevenue,
            uint256 loyaltyRevenue,
            uint256 meosRevenue,
            uint256 transactionCount
        )
    {
        require(agentRevenues[_agent].agent != address(0), "Agent not found");
        require(_fromTimestamp < _toTimestamp, "Invalid timestamp range");
        
        uint256 count = 0;
        
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            RevenueRecord memory record = revenueRecords[i];
            
            if (record.agent == _agent && 
                record.timestamp >= _fromTimestamp && 
                record.timestamp <= _toTimestamp) {
                
                totalRevenue += record.amount;
                count++;
                
                if (record.moduleType == 1) {
                    iqrRevenue += record.amount;
                } else if (record.moduleType == 2) {
                    loyaltyRevenue += record.amount;
                } else if (record.moduleType == 3) {
                    meosRevenue += record.amount;
                }
            }
        }
        
        transactionCount = count;
    }
    
    /**
     * @dev Get system revenue growth for period
     */
    function getSystemRevenueGrowth(uint256 _fromTimestamp, uint256 _toTimestamp)
        external
        view
        returns (
            uint256 totalRevenue,
            uint256 iqrRevenue,
            uint256 loyaltyRevenue,
            uint256 meosRevenue,
            uint256 transactionCount,
            uint256 activeAgentsCount
        )
    {
        require(_fromTimestamp < _toTimestamp, "Invalid timestamp range");
        
        uint256 count = 0;
        address[] memory uniqueAgents = new address[](agentList.length);
        uint256 agentsCount = 0;
        
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            RevenueRecord memory record = revenueRecords[i];
            
            if (record.timestamp >= _fromTimestamp && record.timestamp <= _toTimestamp) {
                totalRevenue += record.amount;
                count++;
                
                // Track unique active agents
                bool found = false;
                for (uint256 j = 0; j < agentsCount; j++) {
                    if (uniqueAgents[j] == record.agent) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    uniqueAgents[agentsCount] = record.agent;
                    agentsCount++;
                }
                
                if (record.moduleType == 1) {
                    iqrRevenue += record.amount;
                } else if (record.moduleType == 2) {
                    loyaltyRevenue += record.amount;
                } else if (record.moduleType == 3) {
                    meosRevenue += record.amount;
                }
            }
        }
        
        transactionCount = count;
        activeAgentsCount = agentsCount;
    }
    
    /**
     * @dev Get agent performance summary
     */
    function getAgentPerformanceSummary(address _agent)
        external
        view
        returns (
            AgentRevenue memory revenue,
            uint256 totalTransactions,
            uint256 avgTransactionValue,
            uint256 firstTransactionDate,
            uint256 lastTransactionDate
        )
    {
        require(agentRevenues[_agent].agent != address(0), "Agent not found");
        
        revenue = agentRevenues[_agent];
        
        uint256 transactionCount = 0;
        uint256 firstDate = type(uint256).max;
        uint256 lastDate = 0;
        
        for (uint256 i = 0; i < revenueRecords.length; i++) {
            if (revenueRecords[i].agent == _agent) {
                transactionCount++;
                
                if (revenueRecords[i].timestamp < firstDate) {
                    firstDate = revenueRecords[i].timestamp;
                }
                
                if (revenueRecords[i].timestamp > lastDate) {
                    lastDate = revenueRecords[i].timestamp;
                }
            }
        }
        
        totalTransactions = transactionCount;
        avgTransactionValue = transactionCount > 0 ? revenue.total / transactionCount : 0;
        firstTransactionDate = firstDate == type(uint256).max ? 0 : firstDate;
        lastTransactionDate = lastDate;
    }
    
    /**
     * @dev Get system performance metrics
     */
    function getSystemPerformanceMetrics()
        external
        view
        returns (
            Revenue memory totalRevenue,
            uint256 totalTransactions,
            uint256 totalAgents,
            uint256 avgRevenuePerAgent,
            uint256 avgRevenuePerTransaction
        )
    {
        totalRevenue = systemRevenue;
        totalTransactions = revenueRecords.length;
        totalAgents = agentList.length;
        
        avgRevenuePerAgent = totalAgents > 0 ? totalRevenue.total / totalAgents : 0;
        avgRevenuePerTransaction = totalTransactions > 0 ? totalRevenue.total / totalTransactions : 0;
    }
    
    /**
     * @dev Get contract version
     */
    function getVersion() external view returns (string memory) {
        return version;
    }
    
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}