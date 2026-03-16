// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import {AgentManagement} from "./agent.sol";
// import {PaginationResult,License,AgentInfo,Agent, AgentAnalytics, TimeFilter, IIQRFactory, ILoyaltyFactory, IRestaurantLoyaltySystem, IAgentIQR, IRevenueManager,IQRContracts,BranchInfo,BranchInfoInput,IBMFactory,IMeosFactory} from "./interfaces/IAgent.sol";
// // import "forge-std/console.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";

// // ============================================================================
// // ENHANCED AGENT MANAGEMENT WITH MISSING FEATURES
// // ============================================================================

// /**
//  * @title Enhanced Agent Management
//  * @dev Extension of the main AgentManagement contract with additional features
//  */
// contract EnhancedAgentManagement is AgentManagement {
//     using Strings for uint256;

//     // Additional structures for advanced filtering and analytics
//     mapping(address => AgentAnalytics) public agentAnalytics;
//     mapping(uint256 => address[]) public monthlyAgents; // month timestamp => agents created
//     mapping(uint256 => address[]) public yearlyAgents;  // year timestamp => agents created
//     // Enhanced events
//     event AgentPerformanceUpdated(address indexed agent, uint256 score, uint256 timestamp);
//     event BulkOperationCompleted(string operation, uint256 successCount, uint256 failureCount);
//     event AnalyticsCalculated(address indexed agent, uint256 timestamp);
    
//     // ========================================================================
//     // ENHANCED AGENT CREATION WITH ANALYTICS TRACKING
//     // ========================================================================
//     /**
//      * @dev Enhanced agent creation with automatic analytics setup
//      */
//      //sau khi gọi createAgentWithAnalytics thì cần gọi thêm 2 hàm để khởi tạo các contract iqr: setAgentIQR, setPointsIQR
//     function createAgentWithAnalytics(
//         address _walletAddress,
//         string memory _storeName,
//         string memory _address,
//         string memory _phone,
//         string memory _note,
//         bool[4] memory _permissions,
//         // string[] memory _subLocations,
//         // string[] memory _subPhones,
//         string memory _domain,
//         BranchInfoInput[] memory branchInfoInputs
//     ) external onlySuperAdmin whenNotPaused nonReentrant returns (bool) {
//         // Create basic agent using internal function
//         bool success = _createAgentInternal(
//             _walletAddress, 
//             _storeName, 
//             _address, 
//             _phone, 
//             _note, 
//             _permissions,
//             // _subLocations,
//             // _subPhones,
//             _domain,
//             branchInfoInputs
//         );
        
//         if (success) {
//             // Initialize analytics
//             agentAnalytics[_walletAddress] = AgentAnalytics({
//                 totalOrders: 0,
//                 totalRevenue: 0,
//                 loyaltyTokensIssued: 0,
//                 meosLicensesActive: _permissions[2] ? 1 : 0,
//                 customerCount: 0,
//                 averageOrderValue: 0,
//                 lastActivityTimestamp: block.timestamp,
//                 performanceScore: 50
//             });
            
//             // Add to time-based tracking
//             uint256 monthKey = _getMonthTimestamp(block.timestamp);
//             uint256 yearKey = _getYearTimestamp(block.timestamp);
            
//             monthlyAgents[monthKey].push(_walletAddress);
//             yearlyAgents[yearKey].push(_walletAddress);
            
//             emit AnalyticsCalculated(_walletAddress, block.timestamp);
//         }
        
//         return success;
//     }    
//      function _createAgentInternal(
//         address _walletAddress,
//         string memory _storeName,
//         string memory _address,
//         string memory _phone,
//         string memory _note,
//         bool[4] memory _permissions,
//         // string[] memory _subLocations,
//         // string[] memory _subPhones,
//         string memory _domain,
//         BranchInfoInput[] memory branchInfoInputs
//     ) internal returns (bool) {
//         // require(_subLocations.length == _subPhones.length, "length of subLocations and subPhones not match");
//         require(_walletAddress != address(0),"InvalidWallet");
//         require(!agents[_walletAddress].exists,"DuplicateAgent");
//         require(bytes(_storeName).length != 0 && bytes(_storeName).length < 100,"Invalid Store Name");
//         mDomainToWallet[_domain] = _walletAddress;
//         mAgentToDomain[_walletAddress] = _domain;
        
        
//         agentList.push(_walletAddress);
        
//         // Add to revenue manager
//         if (revenueManager != address(0)) {
//             IRevenueManager(revenueManager).addAgent(_walletAddress);
//         }
//         branchIdCount++ ;
//         mAgentToMainBranchId[_walletAddress] = branchIdCount;
//         mBranchIdToBranch[branchIdCount] = BranchInfo({
//             branchId: branchIdCount,
//             name: _storeName,
//             location: _address,
//             phone: _phone,
//             domain: _domain,
//             isActive: true,
//             isMain: true,
//             createdAt: block.timestamp
//         });
//         agentToBranchIds[_walletAddress].push(branchIdCount);
//         mDomainToBranchId[_domain] = branchIdCount;
//         BranchInfo[] memory branchInfos = new BranchInfo[](branchInfoInputs.length );
//         if (branchInfoInputs.length > 0){
//             for(uint i ; i < branchInfoInputs.length; i++){
//                 branchIdCount++ ;
//                 BranchInfoInput memory input = branchInfoInputs[i];
//                 BranchInfo memory branch = BranchInfo({
//                     branchId: branchIdCount,
//                     name: input.name,
//                     location: input.location,
//                     phone: input.phone,
//                     domain: input.domain,
//                     isActive: true,
//                     isMain: false,
//                     createdAt: block.timestamp
//                 });
//                 mBranchIdToBranch[branchIdCount] = branch;
//                 branchInfos[i] = branch;
//                 agentToBranchIds[_walletAddress].push(branchIdCount);
//                 mDomainToBranchId[branchInfoInputs[i].domain] = branchIdCount;
//                 mDomainToWallet[branchInfoInputs[i].domain] = _walletAddress;
//             }

//         }
//         agents[_walletAddress] = Agent({
//             walletAddress: _walletAddress,
//             storeName: _storeName,
//             storeAddress: _address,
//             phone: _phone,
//             note: _note,
//             permissions: _permissions,
//             // subLocations: _subLocations,
//             // subPhones: _subPhones,
//             createdAt: block.timestamp,
//             updatedAt: block.timestamp,
//             isActive: true,
//             exists: true,
//             domain: _domain,
//             branches: branchInfos
//         });
//          // Grant permissions with error handling
//          _grantPermissions(_walletAddress, _permissions,agentToBranchIds[_walletAddress]);
//         emit AgentCreated(_walletAddress, _storeName, block.timestamp);
//         return true;
//     }

//     function getAgentBranchIds(address _agent) external view returns(uint[] memory){
//         return agentToBranchIds[_agent];
//     }
//     /*** SET FOR MEOS sau khi goi createAgen co chon meos*/

//     function _setAgentMEOS(address _agent,uint _branchId) internal {
//         address _branchManagement = IBMFactory(bmFactory).getBranchManagement(_agent);
//         require(_branchManagement != address(0),"branchMangament not set yet");
//         IMeosFactory(meosFactory).setAgentMeos(_agent,_branchId, _branchManagement);
//     }

//     //FE goi BatchSetAgentMEOS hoặc BatchSetAllAgentMEOS sau khi goi createAgent chon meos
//     function BatchSetAgentMEOS(address _agent,uint[] memory _branchIds)external onlySuperAdmin{
//         require (meosFactory != address(0) , "MeosFactory is not set");
//         require(_branchIds.length>0,"have no branch id found");
//         for(uint i; i< _branchIds.length; i++){
//             _setAgentMEOS( _agent,_branchIds[i]);
//         }
//     }
//     function BatchSetAllAgentMEOS(address _agent)external onlySuperAdmin{
//         require (meosFactory != address(0) , "IQRFactory is not set");
//         uint[] memory _branchIds = agentToBranchIds[_agent];
//         require(_branchIds.length>0,"have no branch id found");
//         for(uint i; i< _branchIds.length; i++){
//             _setAgentMEOS( _agent,_branchIds[i]);
//         }
//     }

//     /*** SET FOR IQR sau khi goi createAgen chon iqr*/
//     function _setAgentIQR(address _agent,uint _branchId) internal {
//         address _branchManagement = IBMFactory(bmFactory).getBranchManagement(_agent);
//         require(_branchManagement != address(0),"branchMangament not set yet");
//         IIQRFactory(iqrFactory).setAgentIQR(_agent,_branchId, _branchManagement);
//     }

//     //FE goi BatchSetAgentIQR hoặc BatchSetAllAgentIQR sau khi goi createAgent chon iqr
//     function BatchSetAgentIQR(address _agent,uint[] memory _branchIds)external onlySuperAdmin{
//         require (iqrFactory != address(0) , "IQRFactory is not set");
//         require(_branchIds.length>0,"have no branch id found");
//         for(uint i; i< _branchIds.length; i++){
//             _setAgentIQR( _agent,_branchIds[i]);
//         }
//     }
//     function BatchSetAllAgentIQR(address _agent)external onlySuperAdmin{
//         require (iqrFactory != address(0) , "IQRFactory is not set");
//         uint[] memory _branchIds = agentToBranchIds[_agent];
//         require(_branchIds.length>0,"have no branch id found");
//         for(uint i; i< _branchIds.length; i++){
//             _setAgentIQR( _agent,_branchIds[i]);
//         }
//     }
//     function BatchSetAllPointsIQR(address _agent)external onlySuperAdmin{
//         require (iqrFactory != address(0) , "IQRFactory is not set");
//         uint[] memory _branchIds = agentToBranchIds[_agent];
//         require(_branchIds.length>0,"have no branch id found");
//         for(uint i; i< _branchIds.length; i++){
//              _setPointsIQR(_agent,_branchIds[i]);
//         }
//     }

//     //hàm này luôn gọi sau createAgent để tranfer quyền bộ iqr contract cho agent
//     //dang le goi trong hàm createAgent nhung phai tach ra de tranh loi out of gas cho FE
//     function _setPointsIQR(address _agent,uint _branchId) internal{
//         if (agentLoyaltyContracts[_agent][_branchId] != address(0) ){
//             IIQRFactory(iqrFactory).setPointsIQRFactory(_agent,agentLoyaltyContracts[_agent][_branchId],_branchId);
//             IQRContracts memory iqr = IIQRFactory(iqrFactory).getIQRSCByAgentFromFactory(_agent,_branchId);
//             address POINTS_PROXY = ILoyaltyFactory(loyaltyFactory).setPointsLoyaltyFactory(_agent,iqr.Management, iqr.Order,_branchId);
//             ILoyaltyFactory(loyaltyFactory).transferOwnerPointSC(_agent,POINTS_PROXY);
//         }
//         //transfer owner to agent
//         if(iqrTransfered[_agent][_branchId] == false){
//             IIQRFactory(iqrFactory).transferOwnerIQRContracts(_agent,_branchId);
//             iqrTransfered[_agent][_branchId] = true ;
//         }
//     }
//     function BatchSetPointsIQR(address _agent,uint[] memory _branchIds )external onlySuperAdmin{
//         require(_branchIds.length>0,"have no branch id found");
//         for(uint i; i< _branchIds.length; i++){
//             _setPointsIQR(_agent,_branchIds[i]);
//         }
//     }
//     function CheckAgentExisted(address _agent)external view returns(bool){
//         return agents[_agent].exists;
//     }
//     function getAgentFromDomain(string memory _domain)external view returns(address agentAdd,uint branchId){
//         return (mDomainToWallet[_domain],mDomainToBranchId[_domain]);
//     }
//     // ========================================================================
//     // ADVANCED FILTERING AND SEARCH
//     // ========================================================================
    
//     /**
//      * @dev Get agents created in specific time period
//      */
//     function getAgentsByTimePeriod(
//         string memory _period,
//         uint256 _timestamp
//     ) external view returns (address[] memory) {
//         if (keccak256(bytes(_period)) == keccak256(bytes("month"))) {
//             uint256 monthKey = _getMonthTimestamp(_timestamp);
//             return monthlyAgents[monthKey];
//         } else if (keccak256(bytes(_period)) == keccak256(bytes("year"))) {
//             uint256 yearKey = _getYearTimestamp(_timestamp);
//             return yearlyAgents[yearKey];
//         }
        
//         return new address[](0);
//     }
//     /**
//  * @dev OPTIMIZED: Get agents info with pagination and search filter
//  * Key optimizations:
//  * 1. Single-pass filtering instead of multiple array allocations
//  * 2. Early exit on search mismatch
//  * 3. Reduced memory allocations
//  * 4. Combined filtering and sorting logic
//  */
// function getAgentsInfoPaginatedWithSearchOptimized(
//     uint256 _fromTime,
//     uint256 _toTime,
//     string memory _sortBy,
//     bool _ascending,
//     uint256 _page,
//     uint256 _pageSize,
//     string memory _searchTerm
// ) external view returns (
//     AgentInfo[] memory agents,
//     uint256 totalCount,
//     uint256 totalPages,
//     uint256 currentPage
// ) {
//     bytes memory searchBytes = bytes(_searchTerm);
//     bool hasSearch = searchBytes.length > 0;
    
//     // Convert search term to lowercase once
//     bytes memory searchLower;
//     if (hasSearch) {
//         searchLower = bytes(_toLower(_searchTerm));
//     }
    
//     // Single-pass filtering: count matching agents
//     uint256 matchCount = 0;
//     for (uint256 i = 0; i < agentList.length; i++) {
//         address agentAddr = agentList[i];
//         Agent storage agent = agents[agentAddr];
        
//         // Quick checks first (most likely to fail)
//         if (!agent.isActive) continue;
//         if (agent.createdAt < _fromTime || agent.createdAt > _toTime) continue;
        
//         // Search check (if applicable)
//         if (hasSearch && !_matchesSearchOptimized(agentAddr, searchLower)) continue;
        
//         matchCount++;
//     }
    
//     // Handle empty results
//     if (matchCount == 0) {
//         return (new AgentInfo[](0), 0, 0, _page);
//     }
    
//     // Allocate exact size needed
//     address[] memory filtered = new address[](matchCount);
//     uint256[] memory sortValues = new uint256[](matchCount);
    
//     // Second pass: collect matching agents and sort values
//     uint256 index = 0;
//     for (uint256 i = 0; i < agentList.length; i++) {
//         address agentAddr = agentList[i];
//         Agent storage agent = agents[agentAddr];
        
//         if (!agent.isActive) continue;
//         if (agent.createdAt < _fromTime || agent.createdAt > _toTime) continue;
//         if (hasSearch && !_matchesSearchOptimized(agentAddr, searchLower)) continue;
        
//         filtered[index] = agentAddr;
//         sortValues[index] = _getSortValue(agentAddr, _sortBy);
//         index++;
//     }
    
//     // In-place sorting using insertion sort (efficient for small-medium datasets)
//     _insertionSort(filtered, sortValues, _ascending);
    
//     // Calculate pagination
//     totalCount = matchCount;
//     totalPages = (totalCount + _pageSize - 1) / _pageSize;
//     currentPage = _page;
    
//     if (_page == 0 || _page > totalPages) {
//         return (new AgentInfo[](0), totalCount, totalPages, currentPage);
//     }
    
//     // Calculate page bounds
//     uint256 startIndex = (_page - 1) * _pageSize;
//     uint256 endIndex = startIndex + _pageSize;
//     if (endIndex > totalCount) {
//         endIndex = totalCount;
//     }
    
//     // Build only the required page
//     uint256 pageLength = endIndex - startIndex;
//     AgentInfo[] memory pageResult = new AgentInfo[](pageLength);
    
//     for (uint256 i = 0; i < pageLength; i++) {
//         pageResult[i] = _buildAgentInfo(filtered[startIndex + i]);
//     }
    
//     return (pageResult, totalCount, totalPages, currentPage);
// }

// /**
//  * @dev OPTIMIZED: Check if agent matches search (uses pre-lowercased search term)
//  */
// function _matchesSearchOptimized(
//     address _agent, 
//     bytes memory _searchLower
// ) internal view returns (bool) {
//     // Search in store name
//     bytes memory storeNameBytes = bytes(agents[_agent].storeName);
//     if (_containsIgnoreCaseOptimized(storeNameBytes, _searchLower)) {
//         return true;
//     }
    
//     // Search in wallet address
//     string memory walletStr = Strings.toHexString(uint160(_agent), 20);
//     bytes memory walletBytes = bytes(walletStr);
    
//     if (_containsIgnoreCaseOptimized(walletBytes, _searchLower)) {
//         return true;
//     }
    
//     return false;
// }

// /**
//  * @dev OPTIMIZED: Case-insensitive contains (needle is already lowercase)
//  */
// function _containsIgnoreCaseOptimized(
//     bytes memory _haystack, 
//     bytes memory _needleLower
// ) internal pure returns (bool) {
//     if (_needleLower.length > _haystack.length) return false;
//     if (_needleLower.length == 0) return true;
    
//     uint256 haystackLen = _haystack.length;
//     uint256 needleLen = _needleLower.length;
//     uint256 maxPos = haystackLen - needleLen;
    
//     for (uint256 i = 0; i <= maxPos; i++) {
//         bool isMatch = true;
        
//         for (uint256 j = 0; j < needleLen; j++) {
//             bytes1 haystackChar = _haystack[i + j];
            
//             // Convert to lowercase on-the-fly
//             if (haystackChar >= 0x41 && haystackChar <= 0x5A) {
//                 haystackChar = bytes1(uint8(haystackChar) + 32);
//             }
            
//             if (haystackChar != _needleLower[j]) {
//                 isMatch = false;
//                 break;
//             }
//         }
        
//         if (isMatch) return true;
//     }
    
//     return false;
// }

// /**
//  * @dev OPTIMIZED: Insertion sort (more efficient than bubble sort for most cases)
//  * Best for: n < 50, or nearly sorted data
//  * Time: O(n²) worst case, O(n) best case
//  * Space: O(1)
//  */
// function _insertionSort(
//     address[] memory _agents,
//     uint256[] memory _values,
//     bool _ascending
// ) internal pure {
//     uint256 n = _agents.length;
    
//     for (uint256 i = 1; i < n; i++) {
//         address keyAgent = _agents[i];
//         uint256 keyValue = _values[i];
//         uint256 j = i;
        
//         while (j > 0) {
//             bool shouldSwap = _ascending 
//                 ? _values[j - 1] > keyValue 
//                 : _values[j - 1] < keyValue;
                
//             if (!shouldSwap) break;
            
//             _agents[j] = _agents[j - 1];
//             _values[j] = _values[j - 1];
//             j--;
//         }
        
//         _agents[j] = keyAgent;
//         _values[j] = keyValue;
//     }
// }

// /**
//  * @dev ALTERNATIVE: Quick sort for larger datasets (n > 50)
//  * Time: O(n log n) average, O(n²) worst case
//  * Space: O(log n)
//  */
// function _quickSort(
//     address[] memory _agents,
//     uint256[] memory _values,
//     bool _ascending,
//     uint256 _left,
//     uint256 _right
// ) internal pure {
//     if (_left >= _right) return;
    
//     uint256 pivotIndex = _partition(_agents, _values, _ascending, _left, _right);
    
//     if (pivotIndex > _left) {
//         _quickSort(_agents, _values, _ascending, _left, pivotIndex - 1);
//     }
//     _quickSort(_agents, _values, _ascending, pivotIndex + 1, _right);
// }

// function _partition(
//     address[] memory _agents,
//     uint256[] memory _values,
//     bool _ascending,
//     uint256 _left,
//     uint256 _right
// ) internal pure returns (uint256) {
//     uint256 pivotValue = _values[_right];
//     uint256 i = _left;
    
//     for (uint256 j = _left; j < _right; j++) {
//         bool shouldSwap = _ascending 
//             ? _values[j] < pivotValue 
//             : _values[j] > pivotValue;
            
//         if (shouldSwap) {
//             (_agents[i], _agents[j]) = (_agents[j], _agents[i]);
//             (_values[i], _values[j]) = (_values[j], _values[i]);
//             i++;
//         }
//     }
    
//     (_agents[i], _agents[_right]) = (_agents[_right], _agents[i]);
//     (_values[i], _values[_right]) = (_values[_right], _values[i]);
    
//     return i;
// }

// /**
//  * @dev Adaptive sort: chooses best algorithm based on data size
//  */
// function _sortAgentsOptimized(
//     address[] memory _agents,
//     uint256[] memory _values,
//     bool _ascending
// ) internal pure {
//     uint256 n = _agents.length;
    
//     if (n < 2) return;
    
//     // Use insertion sort for small arrays
//     if (n <= 50) {
//         _insertionSort(_agents, _values, _ascending);
//     } else {
//         // Use quick sort for larger arrays
//         _quickSort(_agents, _values, _ascending, 0, n - 1);
//     }
// }
//     /**
//      * @dev Get agents info with pagination and search filter
//      * @param _searchTerm Search term for store name or wallet address (empty string for no filter)
//      */
//     function getAgentsInfoPaginatedWithSearchOld(
//         uint256 _fromTime,
//         uint256 _toTime,
//         string memory _sortBy,
//         bool _ascending,
//         uint256 _page,
//         uint256 _pageSize,
//         string memory _searchTerm
//     ) external view returns (
//         AgentInfo[] memory agents,
//         uint256 totalCount,
//         uint256 totalPages,
//         uint256 currentPage
//     ) {
//         // Filter by time first
//         address[] memory timeFiltered = _filterAgentsByTime(_fromTime, _toTime);
        
//         // Then filter by search term (if provided)
//         address[] memory searchFiltered;
//         bytes memory searchBytes = bytes(_searchTerm);
//         if (searchBytes.length > 0) {
//             searchFiltered = _filterAgentsBySearch(timeFiltered, searchBytes);
//         } else {
//             searchFiltered = timeFiltered;
//         }
        
//         // Sort the filtered agents
//         address[] memory sortedAddresses;
//         if (searchFiltered.length >= 1) {
//             sortedAddresses = _sortAgents(searchFiltered, _sortBy, _ascending);
//         } else {
//             sortedAddresses = new address[](0);
//         }
        
//         totalCount = sortedAddresses.length;
//         totalPages = totalCount > 0 ? (totalCount + _pageSize - 1) / _pageSize : 0;
//         currentPage = _page;
        
//         // Calculate pagination
//         if (_page == 0 || _page > totalPages || totalCount == 0) {
//             return (new AgentInfo[](0), totalCount, totalPages, currentPage);
//         }
        
//         uint256 startIndex = (_page - 1) * _pageSize;
//         uint256 endIndex = startIndex + _pageSize;
//         if (endIndex > totalCount) {
//             endIndex = totalCount;
//         }
        
//         // Build page result
//         uint256 pageLength = endIndex - startIndex;
//         AgentInfo[] memory pageResult = new AgentInfo[](pageLength);
        
//         for (uint256 i = 0; i < pageLength; i++) {
//             pageResult[i] = _buildAgentInfo(sortedAddresses[startIndex + i]);
//         }
        
//         return (pageResult, totalCount, totalPages, currentPage);
//     }
//     /**
//      * @dev Advanced search with multiple filters
//      */
//     function searchAgentsAdvanced(
//         string memory _storeName,
//         bool[4] memory _requiredPermissions,
//         uint256 _minRevenue,
//         uint256 _minPerformanceScore,
//         TimeFilter memory _timeFilter
//     ) external view returns (address[] memory) {
//         address[] memory results = new address[](agentList.length);
//         uint256 count = 0;
        
//         for (uint256 i = 0; i < agentList.length; i++) {
//             address agentAddr = agentList[i];
//             Agent memory agent = agents[agentAddr];
//             AgentAnalytics memory analytics = agentAnalytics[agentAddr];
            
//             if (!agent.isActive) continue;
            
//             // Store name filter
//             if (bytes(_storeName).length > 0) {
//                 bytes memory storeNameBytes = bytes(agent.storeName);
//                 bytes memory searchBytes = bytes(_storeName);
//                 if (!_contains(storeNameBytes, searchBytes)) continue;
//             }
            
//             // Permissions filter
//             bool hasRequiredPermissions = true;
//             for (uint8 j = 0; j < 3; j++) {
//                 if (_requiredPermissions[j] && !agent.permissions[j]) {
//                     hasRequiredPermissions = false;
//                     break;
//                 }
//             }
//             if (!hasRequiredPermissions) continue;
            
//             // Revenue filter
//             if (_minRevenue > 0 && analytics.totalRevenue < _minRevenue) continue;
            
//             // Performance score filter
//             if (_minPerformanceScore > 0 && analytics.performanceScore < _minPerformanceScore) continue;
            
//             // Time filter
//             if (_timeFilter.startTime > 0 || _timeFilter.endTime > 0) {
//                 if (agent.createdAt < _timeFilter.startTime || 
//                     agent.createdAt > _timeFilter.endTime) continue;
//             }
            
//             results[count] = agentAddr;
//             count++;
//         }
        
//         // Resize array
//         address[] memory finalResults = new address[](count);
//         for (uint256 i = 0; i < count; i++) {
//             finalResults[i] = results[i];
//         }
        
//         return finalResults;
//     }
    
//     /**
//      * @dev Get agents sorted by various criteria
//      */
//     function getAgentsSorted(
//         string memory _sortBy,
//         bool _ascending,
//         uint256 _limit
//     ) public view returns (address[] memory, uint256[] memory) {
//         if(_limit > agentList.length){_limit = agentList.length;}
//         if (_limit == 0) _limit = agentList.length;
        
//         address[] memory sortedAgents = new address[](_limit);
//         uint256[] memory sortedValues = new uint256[](_limit);
        
//         // Simple sorting implementation (bubble sort - not efficient for large arrays)
//         for (uint256 i = 0; i < _limit && i < agentList.length; i++) {
//             address selectedAgent = address(0);
//             uint256 selectedValue = 0;
//             uint256 selectedIndex = 0;
            
//             for (uint256 j = 0; j < agentList.length; j++) {
//                 if (!agents[agentList[j]].isActive) continue;
                
//                 // Check if already selected
//                 bool alreadySelected = false;
//                 for (uint256 k = 0; k < i; k++) {
//                     if (sortedAgents[k] == agentList[j]) {
//                         alreadySelected = true;
//                         break;
//                     }
//                 }
//                 if (alreadySelected) continue;
                
//                 uint256 currentValue = _getSortValue(agentList[j], _sortBy);
                
//                 if (selectedAgent == address(0) || 
//                     (_ascending ? currentValue < selectedValue : currentValue > selectedValue)) {
//                     selectedAgent = agentList[j];
//                     selectedValue = currentValue;
//                     selectedIndex = j;
//                 }
//             }
            
//             if (selectedAgent != address(0)) {
//                 sortedAgents[i] = selectedAgent;
//                 sortedValues[i] = selectedValue;
//             }
//         }
        
//         return (sortedAgents, sortedValues);
//     }
    
//     /**
//      * @dev Get sort value for agent based on criteria
//      */
//     function _getSortValue(address _agent, string memory _sortBy) internal view returns (uint256) {
//         if (keccak256(bytes(_sortBy)) == keccak256(bytes("createdAt"))) {
//             return agents[_agent].createdAt;
//         } else if (keccak256(bytes(_sortBy)) == keccak256(bytes("revenue"))) {
//             return agentAnalytics[_agent].totalRevenue;
//         } else if (keccak256(bytes(_sortBy)) == keccak256(bytes("orders"))) {
//             return agentAnalytics[_agent].totalOrders;
//         } else if (keccak256(bytes(_sortBy)) == keccak256(bytes("performance"))) {
//             return agentAnalytics[_agent].performanceScore;
//         } else if (keccak256(bytes(_sortBy)) == keccak256(bytes("customers"))) {
//             return agentAnalytics[_agent].customerCount;
//         }
        
//         return 0;
//     }
    
//     // // ========================================================================
//     // // BULK OPERATIONS
//     // // ========================================================================
    
//     // /**
//     //  * @dev Bulk delete agents (with safety checks)
//     //  */
//     // function bulkUpdatePermissions(
//     //     address[] memory _agents,
//     //     bool[4] memory _permissions
//     // ) external onlySuperAdmin nonReentrant returns (uint256 successCount, uint256 failureCount) {
//     //     for (uint256 i = 0; i < _agents.length; i++) {
//     //         if (_safeBulkUpdatePermission(_agents[i], _permissions)) {
//     //             successCount++;
//     //         } else {
//     //             failureCount++;
//     //         }
//     //     }
        
//     //     emit BulkOperationCompleted("updatePermissions", successCount, failureCount);
//     // }
    
//     // /**
//     //  * @dev Safe permission update for bulk operations
//     //  */
//     // function _safeBulkUpdatePermission(
//     //     address _agent,
//     //     bool[4] memory _newPermissions
//     // ) internal returns (bool) {
//     //     // Validate agent
//     //     if (!agents[_agent].exists || !agents[_agent].isActive) {
//     //         return false;
//     //     }
        
//     //     Agent storage agent = agents[_agent];
//     //     bool hasChanges = false;
        
//     //     // Update each permission individually with error handling
//     //     for (uint8 i = 0; i < 3; i++) {
//     //         if (agent.permissions[i] != _newPermissions[i]) {
//     //             hasChanges = true;
                
//     //             if (_newPermissions[i]) {
//     //                 // Grant permission
//     //                 // bool success = false;
//     //                 _grantIQRPermissionSafe(_agent);
//     //                 _grantLoyaltyPermissionSafe(_agent);
//     //                 _grantMeOSPermission(_agent);                    
//     //                 agent.permissions[i] = true;
//     //             } else {
//     //                 // Revoke permission
//     //                 _revokePermission(_agent, i);
//     //                 agent.permissions[i] = false;
//     //             }
//     //         }
//     //     }
        
//     //     if (hasChanges) {
//     //         agent.updatedAt = block.timestamp;
//     //         emit AgentUpdated(_agent, block.timestamp);
//     //     }
        
//     //     return true;
//     // }
    
//     // /**
//     //  * @dev Safe IQR permission grant
//     //  */
//     // function _grantIQRPermissionSafe(address _agent) internal {
//     //     require (iqrFactory != address(0),"iqrFactory address can be address(0)"); 
//     //     require(agentIQRContracts[_agent] == address(0),"IQRContract already exists"); 
        
//     //     address contractAddr = IIQRFactory(iqrFactory).createAgentIQR(_agent);
//     //     agentIQRContracts[_agent] = contractAddr;
//     //     emit PermissionGranted(_agent, 0, block.timestamp);
//     // }
    
//     // /**
//     //  * @dev Safe Loyalty permission grant
//     //  */
//     // function _grantLoyaltyPermissionSafe(address _agent,uint _branchId) internal  {
//     //     require (loyaltyFactory != address(0),"loyaltyFactory address can be address(0)") ;
//     //     require (agentLoyaltyContracts[_agent][_branchId] == address(0),"agentLoyaltyContracts already exists") ; // Already exists
        
//     //     address contractAddr = ILoyaltyFactory(loyaltyFactory).createAgentLoyalty(_agent,_branchId);
//     //         agentLoyaltyContracts[_agent][_branchId] = contractAddr;
//     //         emit PermissionGranted(_agent, 1, block.timestamp);
//     // }
    
//     // /**
//     //  * @dev Bulk delete agents - CORRECTED VERSION
//     //  */
//     // function bulkDeleteAgents(address[] memory _agents) 
//     //     external 
//     //     onlySuperAdmin 
//     //     nonReentrant 
//     //     returns (uint256 successCount, uint256 failureCount) 
//     // {
//     //     for (uint256 i = 0; i < _agents.length; i++) {
//     //         if (_safeDeleteAgent(_agents[i])) {
//     //             successCount++;
//     //         } else {
//     //             failureCount++;
//     //         }
//     //     }
        
//     //     emit BulkOperationCompleted("delete", successCount, failureCount);
//     // }
    
//     // /**
//     //  * @dev Safe agent deletion for bulk operations
//     //  */
//     // function _safeDeleteAgent(address _agent,uint _branchId) internal returns (bool) {
//     //     // Validate agent exists
//     //     if (!agents[_agent].exists) {
//     //         return false;
//     //     }
        
//     //     // Check if has active loyalty tokens
//     //     if (agents[_agent].permissions[1]) {
//     //         address loyaltyContract = agentLoyaltyContracts[_agent][_branchId];
//     //         if (loyaltyContract != address(0)) {
//     //             try IRestaurantLoyaltySystem(loyaltyContract).totalSupply() returns (uint256 supply) {
//     //                 if (supply > 0) {
//     //                     try IRestaurantLoyaltySystem(loyaltyContract).isFrozen() returns (bool isFrozen) {
//     //                         try IRestaurantLoyaltySystem(loyaltyContract).isRedeemOnly() returns (bool isRedeemOnly) {
//     //                             if (!isFrozen && !isRedeemOnly) {
//     //                                 return false; // Cannot delete with active tokens
//     //                             }
//     //                         } catch {
//     //                             return false;
//     //                         }
//     //                     } catch {
//     //                         return false;
//     //                     }
//     //                 }
//     //             } catch {
//     //                 // If we can't read supply, play it safe
//     //                 return false;
//     //             }
//     //         }
//     //     }
        
//     //     // Revoke all permissions
//     //     bool[4] memory noPermissions = [false, false, false];
//     //     _safeBulkUpdatePermission(_agent, noPermissions);
        
//     //     // Mark as deleted
//     //     agents[_agent].isActive = false;
//     //     agents[_agent].updatedAt = block.timestamp;
        
//     //     emit AgentDeleted(_agent, block.timestamp);
//     //     return true;
//     // }
    
//     // ========================================================================
//     // ANALYTICS AND PERFORMANCE TRACKING
//     // ========================================================================
    
//     function updateAgentAnalytics(
//         address _agent,
//         uint256 _totalOrders,
//         uint256 _totalRevenue,
//         uint256 _customerCount
//     ) external onlySuperAdmin validAgent(_agent) {
//         AgentAnalytics storage analytics = agentAnalytics[_agent];
        
//         analytics.totalOrders = _totalOrders;
//         analytics.totalRevenue = _totalRevenue;
//         analytics.customerCount = _customerCount;
//         analytics.averageOrderValue = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0;
//         analytics.lastActivityTimestamp = block.timestamp;
        
//         // Calculate performance score (simplified algorithm)
//         analytics.performanceScore = _calculatePerformanceScore(_agent);
        
//         emit AnalyticsCalculated(_agent, block.timestamp);
//         emit AgentPerformanceUpdated(_agent, analytics.performanceScore, block.timestamp);
//     }
    
//     /**
//      * @dev Calculate performance score based on multiple metrics
//      */
//     function _calculatePerformanceScore(address _agent) internal view returns (uint256) {
//         AgentAnalytics memory analytics = agentAnalytics[_agent];
//         Agent memory agent = agents[_agent];
        
//         uint256 score = 0;
        
//         // Base score for having permissions
//         uint8 permissionCount = 0;
//         for (uint8 i = 0; i < 3; i++) {
//             if (agent.permissions[i]) permissionCount++;
//         }
//         score += permissionCount * 15; // Max 45 points for all permissions
        
//         // Revenue performance (normalized, assuming max revenue of 1M for 100% score)
//         score += (analytics.totalRevenue * 25) / 1000000; // Max 25 points
        
//         // Order volume (normalized, assuming max 10000 orders for 100% score)
//         score += (analytics.totalOrders * 15) / 10000; // Max 15 points
        
//         // Customer base (normalized, assuming max 5000 customers for 100% score)
//         score += (analytics.customerCount * 10) / 5000; // Max 10 points
        
//         // Activity recency (points decrease over time)
//         uint256 daysSinceActivity = (block.timestamp - analytics.lastActivityTimestamp) / 86400;
//         if (daysSinceActivity < 7) {
//             score += 5; // Active within week
//         } else if (daysSinceActivity < 30) {
//             score += 3; // Active within month
//         } else if (daysSinceActivity < 90) {
//             score += 1; // Active within quarter
//         }
//         // No points for inactive agents
        
//         return score > 100 ? 100 : score;
//     }
    
//     /**
//      * @dev Get comprehensive agent analytics
//      */
//     function getAgentAnalytics(address _agent) 
//         external 
//         view 
//         validAgent(_agent) 
//         returns (AgentAnalytics memory) 
//     {
//         return agentAnalytics[_agent];
//     }
    
//     /**
//      * @dev Get system-wide analytics
//      */
//     function getSystemAnalytics() external view returns (
//         uint256 totalAgents,
//         uint256 activeAgents,
//         uint256 totalRevenue,
//         uint256 totalOrders,
//         uint256 averagePerformanceScore,
//         uint256[4] memory permissionStats // [IQR count, Loyalty count, MeOS count]
//     ) {
//         totalAgents = agentList.length;
        
//         uint256 totalScore = 0;
        
//         for (uint256 i = 0; i < agentList.length; i++) {
//             address agentAddr = agentList[i];
//             Agent memory agent = agents[agentAddr];
//             AgentAnalytics memory analytics = agentAnalytics[agentAddr];
            
//             if (agent.isActive) {
//                 activeAgents++;
//                 totalRevenue += analytics.totalRevenue;
//                 totalOrders += analytics.totalOrders;
//                 totalScore += analytics.performanceScore;
                
//                 // Count permissions
//                 if (agent.permissions[0]) permissionStats[0]++;
//                 if (agent.permissions[1]) permissionStats[1]++;
//                 if (agent.permissions[2]) permissionStats[2]++;
//             }
//         }
        
//         averagePerformanceScore = activeAgents > 0 ? totalScore / activeAgents : 0;
//     }
    
//     /**
//      * @dev Get performance leaderboard
//      */
//     function getPerformanceLeaderboard(uint256 _limit) 
//         external 
//         view 
//         returns (address[] memory agents, uint256[] memory scores) 
//     {
//         return getAgentsSorted("performance", false, _limit);
//     }
    
//     // ========================================================================
//     // ENHANCED DASHBOARD METRICS WITH TIME PERIODS
//     // ========================================================================
    
//     /**
//      * @dev Get dashboard metrics for specific time period
//      */
//     function getDashboardMetricsByPeriod(
//         // string memory _period,
//         uint256 _startTime,
//         uint256 _endTime
//     ) external view returns (
//         uint256 newAgents,
//         uint256 activeAgents,
//         uint256 totalRevenue,
//         uint256 totalOrders,
//         uint256[4] memory revenueByModule, // [IQR, Loyalty, MeOS]
//         uint256 averagePerformance
//     ) {
//         uint256 totalScore = 0;
//         uint256 scoreCount = 0;
        
//         for (uint256 i = 0; i < agentList.length; i++) {
//             address agentAddr = agentList[i];
//             Agent memory agent = agents[agentAddr];
//             AgentAnalytics memory analytics = agentAnalytics[agentAddr];
            
//             // Check if agent was created in time period
//             if (agent.createdAt >= _startTime && agent.createdAt <= _endTime) {
//                 newAgents++;
//             }
            
//             if (agent.isActive) {
//                 activeAgents++;
//                 totalRevenue += analytics.totalRevenue;
//                 totalOrders += analytics.totalOrders;
                
//                 if (analytics.performanceScore > 0) {
//                     totalScore += analytics.performanceScore;
//                     scoreCount++;
//                 }
                
//                 // Get revenue breakdown from revenue manager
//                 if (revenueManager != address(0)) {
//                     (uint256 iqr, uint256 loyalty, uint256 meos,) = IRevenueManager(revenueManager).getAgentRevenue(agentAddr) ;
//                     revenueByModule[0] += iqr;
//                     revenueByModule[1] += loyalty;
//                     revenueByModule[2] += meos;
//                 }
//             }
//         }
        
//         averagePerformance = scoreCount > 0 ? totalScore / scoreCount : 0;
//     }
    
//     // ========================================================================
//     // ADDITIONAL HELPER FUNCTIONS
//     // ========================================================================
    
//     /**
//      * @dev Get month timestamp for time-based grouping
//      */
//     function _getMonthTimestamp(uint256 _timestamp) internal pure returns (uint256) {
//         return (_timestamp / (30 * 24 * 60 * 60)) * (30 * 24 * 60 * 60);
//     }
    
//     /**
//      * @dev Get year timestamp for time-based grouping
//      */
//     function _getYearTimestamp(uint256 _timestamp) internal pure returns (uint256) {
//         return (_timestamp / (365 * 24 * 60 * 60)) * (365 * 24 * 60 * 60);
//     }
    
//     /**
//      * @dev Emergency function to recalculate all analytics
//      */
//     function recalculateAllAnalytics() external onlySuperAdmin {
//         for (uint256 i = 0; i < agentList.length; i++) {
//             address agentAddr = agentList[i];
//             if (agents[agentAddr].isActive) {
//                 // Recalculate performance score
//                 agentAnalytics[agentAddr].performanceScore = _calculatePerformanceScore(agentAddr);
//                 emit AnalyticsCalculated(agentAddr, block.timestamp);
//             }
//         }
//     }
    
//     /**
//      * @dev Get agent status summary
//      */
//     function getAgentStatusSummary(address _agent, uint _branchId) 
//         external 
//         view 
//         validAgent(_agent) 
//         returns (
//             bool isActive,
//             bool[4] memory permissions,
//             bool hasActiveLoyalty,
//             bool hasActiveMeOS,
//             bool hasActiveIQR,
//             uint256 performanceScore
//         ) 
//     {
//         Agent memory agent = agents[_agent];
//         AgentAnalytics memory analytics = agentAnalytics[_agent];
        
//         isActive = agent.isActive;
//         permissions = agent.permissions;
//         performanceScore = analytics.performanceScore;
        
//         // Check active contracts
//         if (permissions[0] && agentIQRContracts[_agent][_branchId] != address(0)) {
//             bool active = IAgentIQR(agentIQRContracts[_agent][_branchId]).isActive();
//             hasActiveIQR = active;
//         }
        
//         if (permissions[1] && agentLoyaltyContracts[_agent][_branchId] != address(0)) {
//             bool frozen = IRestaurantLoyaltySystem(agentLoyaltyContracts[_agent][_branchId]).isFrozen();
//             hasActiveLoyalty = !frozen;
//         }
        
//         if (permissions[2]) {
//             hasActiveMeOS = meosLicenses[_agent][_branchId].isActive && 
//                           meosLicenses[_agent][_branchId].expiryAt > block.timestamp;
//         }
//     }
//     /**
//      * @dev Get agents sorted by various criteria with time filter
//      */
//     function getAgentsSortedByTimeRange(
//         uint256 _fromTime,
//         uint256 _toTime,
//         string memory _sortBy,
//         bool _ascending,
//         uint256 _limit
//     ) external view returns (AgentInfo[] memory) {
//         // First, filter agents by time
//         address[] memory filteredAgents = _filterAgentsByTime(_fromTime, _toTime);
//         if (filteredAgents.length == 0) {
//             return new AgentInfo[](0);
//         }
        
//         // Determine actual limit
//         uint256 resultLimit = _limit;
//         if (resultLimit == 0 || resultLimit > filteredAgents.length) {
//             resultLimit = filteredAgents.length;
//         }
        
//         // Sort the filtered agents
//         address[] memory sortedAddresses = _sortAgents(filteredAgents, _sortBy, _ascending);
        
//         // Build AgentInfo array with limit
//         AgentInfo[] memory result = new AgentInfo[](resultLimit);
        
//         for (uint256 i = 0; i < resultLimit; i++) {
//             result[i] = _buildAgentInfo(sortedAddresses[i]);
//         }
        
//         return result;
//     }
    
//     /**
//      * @dev Filter agents by creation time
//      */
//     function _filterAgentsByTime(
//         uint256 _fromTime,
//         uint256 _toTime
//     ) internal view returns (address[] memory) {
//         // Count matching agents
//         uint256 count = 0;
//         for (uint256 i = 0; i < agentList.length; i++) {
//             Agent memory agent = agents[agentList[i]];
//             if (agent.isActive && 
//                 agent.createdAt >= _fromTime && 
//                 agent.createdAt <= _toTime) {
//                 count++;
//             }
//         }
        
//         // Build filtered array
//         address[] memory filtered = new address[](count);
//         uint256 index = 0;
        
//         for (uint256 i = 0; i < agentList.length; i++) {
//             Agent memory agent = agents[agentList[i]];
//             if (agent.isActive && 
//                 agent.createdAt >= _fromTime && 
//                 agent.createdAt <= _toTime) {
//                 filtered[index] = agentList[i];
//                 index++;
//             }
//         }
        
//         return filtered;
//     }
    
//     /**
//      * @dev Sort agents by criteria (bubble sort for simplicity)
//      */
//     function _sortAgents(
//         address[] memory _agents,
//         string memory _sortBy,
//         bool _ascending
//     ) internal view returns (address[] memory) {
//         address[] memory sorted = _agents;
//         uint256 n = sorted.length;
        
//         // Bubble sort
//         for (uint256 i = 0; i < n - 1; i++) {
//             for (uint256 j = 0; j < n - i - 1; j++) {
//                 uint256 value1 = _getSortValue(sorted[j], _sortBy);
//                 uint256 value2 = _getSortValue(sorted[j + 1], _sortBy);
                
//                 bool shouldSwap = _ascending ? value1 > value2 : value1 < value2;
                
//                 if (shouldSwap) {
//                     address temp = sorted[j];
//                     sorted[j] = sorted[j + 1];
//                     sorted[j + 1] = temp;
//                 }
//             }
//         }
        
//         return sorted;
//     }
//     /**
//      * @dev Build complete agent info
//      */
//     function _buildAgentInfo(address _agent) internal view returns (AgentInfo memory) {
//         Agent memory agent = agents[_agent];
        
//         // Get revenue data
//         uint256[4] memory revenueByModule;
//         if (revenueManager != address(0)) {
//             (uint256 iqr, uint256 loyalty, uint256 meos,uint robot ) = IRevenueManager(revenueManager).getAgentRevenue(_agent);
//             revenueByModule[0] = iqr;
//             revenueByModule[1] = loyalty;
//             revenueByModule[2] = meos;
//             revenueByModule[3] = robot;
//         }
        
//         // Get number of branches (subLocations)
//         uint256 numOfBranch = 0;
//         // if (agent.permissions[0]) { // Has IQR
//             // address iqrContract = agentIQRContracts[_agent];
//             // if (revenueManager != address(0)) {
//                 try this.getSubLocationCount(_agent) returns (uint256 count) {
//                     numOfBranch = count;
//                 } catch {
//                     numOfBranch = 0;
//                 }
//             // }
//         // }
        
//         return AgentInfo({
//             walletAddress: agent.walletAddress,
//             storeName: agent.storeName,
//             storeAddress: agent.storeAddress,
//             numOfBranch: numOfBranch,
//             permissions: agent.permissions,
//             createdAt: agent.createdAt,
//             revenueByModule: revenueByModule
//         });
//     }
    
//     /**
//      * @dev Struct for returning complete agent information
//      */
    
//     /**
//      * @dev Get all agents with complete info (no time filter, no sort)
//      */
//     function getAllAgentsInfo() external view returns (AgentInfo[] memory) {
//         uint256 activeCount = 0;
//         for (uint256 i = 0; i < agentList.length; i++) {
//             if (agents[agentList[i]].isActive) {
//                 activeCount++;
//             }
//         }
        
//         AgentInfo[] memory result = new AgentInfo[](activeCount);
//         uint256 index = 0;
        
//         for (uint256 i = 0; i < agentList.length; i++) {
//             if (agents[agentList[i]].isActive) {
//                 result[index] = _buildAgentInfo(agentList[i]);
//                 index++;
//             }
//         }
        
//         return result;
//     }
    
//     /**
//      * @dev Get agents info with pagination
//      */
//     function getAgentsInfoPaginated(
//         uint256 _fromTime,
//         uint256 _toTime,
//         string memory _sortBy,
//         bool _ascending,
//         uint256 _page,
//         uint256 _pageSize
//     ) external view returns (
//         AgentInfo[] memory agents,
//         uint256 totalCount,
//         uint256 totalPages,
//         uint256 currentPage
//     ) {
//         // Get all sorted agents
//         AgentInfo[] memory allAgents = this.getAgentsSortedByTimeRange(
//             _fromTime,
//             _toTime,
//             _sortBy,
//             _ascending,
//             0 // Get all
//         );
        
//         totalCount = allAgents.length;
//         totalPages = (totalCount + _pageSize - 1) / _pageSize;
//         currentPage = _page;
        
//         // Calculate pagination
//         if (_page == 0 || _page > totalPages) {
//             return (new AgentInfo[](0), totalCount, totalPages, currentPage);
//         }
        
//         uint256 startIndex = (_page - 1) * _pageSize;
//         uint256 endIndex = startIndex + _pageSize;
//         if (endIndex > totalCount) {
//             endIndex = totalCount;
//         }
        
//         // Build page result
//         uint256 pageLength = endIndex - startIndex;
//         AgentInfo[] memory pageResult = new AgentInfo[](pageLength);
        
//         for (uint256 i = 0; i < pageLength; i++) {
//             pageResult[i] = allAgents[startIndex + i];
//         }
        
//         return (pageResult, totalCount, totalPages, currentPage);
//     }
// /**
//  * @dev Get agents info paginated with permissions filter and search functionality
//  * @param _fromTime Start time filter
//  * @param _toTime End time filter
//  * @param _sortBy Sort criteria (e.g., "createdAt", "revenue", "performance")
//  * @param _ascending Sort direction (true = ascending, false = descending)
//  * @param _page Page number (starts from 1)
//  * @param _pageSize Number of items per page
//  * @param _permissionFilter [IQR, Loyalty, MeOS] - true = must have, false = ignore
//  * @param _searchTerm Search term for store name or wallet address (empty for no search)
//  * @return agents Array of agent information
//  * @return totalCount Total number of matching agents
//  * @return totalPages Total number of pages
//  * @return currentPage Current page number
//  */
// function getAgentsInfoPaginatedWithPemissionsSearch(
//     uint256 _fromTime,
//     uint256 _toTime,
//     string memory _sortBy,
//     bool _ascending,
//     uint256 _page,
//     uint256 _pageSize,
//     bool[4] memory _permissionFilter,
//     string memory _searchTerm  // NEW: Search parameter
// ) external view returns (
//     AgentInfo[] memory agents,
//     uint256 totalCount,
//     uint256 totalPages,
//     uint256 currentPage
// ) {
//     // Filter by time first
//     address[] memory timeFiltered = _filterAgentsByTime(_fromTime, _toTime);
    
//     // Then filter by permissions
//     address[] memory permissionFiltered = _filterAgentsByPermissions(timeFiltered, _permissionFilter);
    
//     // NEW: Then filter by search term (if provided)
//     address[] memory searchFiltered;
//     bytes memory searchBytes = bytes(_searchTerm);
//     if (searchBytes.length > 0) {
//         searchFiltered = _filterAgentsBySearch(permissionFiltered, searchBytes);
//     } else {
//         searchFiltered = permissionFiltered;
//     }

//     // Sort the filtered agents
//     address[] memory sortedAddresses;
//     if (searchFiltered.length >= 1) {
//         sortedAddresses = _sortAgents(searchFiltered, _sortBy, _ascending);
//     } else {
//         sortedAddresses = new address[](0);
//     }
    
//     totalCount = sortedAddresses.length;
//     totalPages = totalCount > 0 ? (totalCount + _pageSize - 1) / _pageSize : 0;
//     currentPage = _page;
    
//     // Calculate pagination
//     if (_page == 0 || _page > totalPages || totalCount == 0) {
//         return (new AgentInfo[](0), totalCount, totalPages, currentPage);
//     }
    
//     uint256 startIndex = (_page - 1) * _pageSize;
//     uint256 endIndex = startIndex + _pageSize;
//     if (endIndex > totalCount) {
//         endIndex = totalCount;
//     }
    
//     // Build page result
//     uint256 pageLength = endIndex - startIndex;
//     AgentInfo[] memory pageResult = new AgentInfo[](pageLength);
    
//     for (uint256 i = 0; i < pageLength; i++) {
//         pageResult[i] = _buildAgentInfo(sortedAddresses[startIndex + i]);
//     }
    
//     return (pageResult, totalCount, totalPages, currentPage);
// }

// /**
//  * @dev Filter agents by search term (store name or wallet address)
//  * @param _agents Array of agent addresses to filter
//  * @param _searchBytes Search term in bytes
//  * @return address[] Filtered array of agent addresses
//  */
// function _filterAgentsBySearch(
//     address[] memory _agents,
//     bytes memory _searchBytes
// ) internal view returns (address[] memory) {
//     // Count matching agents
//     uint256 count = 0;
//     for (uint256 i = 0; i < _agents.length; i++) {
//         if (_matchesSearch(_agents[i], _searchBytes)) {
//             count++;
//         }
//     }
    
//     // Build filtered array
//     address[] memory filtered = new address[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 0; i < _agents.length; i++) {
//         if (_matchesSearch(_agents[i], _searchBytes)) {
//             filtered[index] = _agents[i];
//             index++;
//         }
//     }
    
//     return filtered;
// }
// /**
//  * @dev Helper function to check if agent matches search criteria
//  * @param _agent Agent address to check
//  * @param _searchBytes Search term in bytes
//  * @return bool True if agent matches search term
//  */
// function _matchesSearch(address _agent, bytes memory _searchBytes) internal view returns (bool) {
//     // Search in store name
//     bytes memory storeNameBytes = bytes(agents[_agent].storeName);
//     if (_containsIgnoreCase(storeNameBytes, _searchBytes)) {
//         return true;
//     }
    
//     // Search in wallet address (convert address to lowercase hex string)
//     string memory walletStr = Strings.toHexString(uint160(_agent), 20);
//     bytes memory walletBytes = bytes(walletStr);
    
//     // Also check without "0x" prefix
//     string memory searchStr = string(_searchBytes);
//     bytes memory searchLower = bytes(_toLower(searchStr));
    
//     if (_containsIgnoreCase(walletBytes, searchLower)) {
//         return true;
//     }
    
//     return false;
// }

// /**
//  * @dev Helper function to check if bytes contains substring (case-insensitive)
//  * @param _haystack The string to search in
//  * @param _needle The string to search for
//  * @return bool True if needle is found in haystack
//  */
// function _containsIgnoreCase(bytes memory _haystack, bytes memory _needle) internal pure returns (bool) {
//     if (_needle.length > _haystack.length) return false;
//     if (_needle.length == 0) return true;
    
//     // Convert both to lowercase for comparison
//     bytes memory haystackLower = new bytes(_haystack.length);
//     bytes memory needleLower = new bytes(_needle.length);
    
//     for (uint256 i = 0; i < _haystack.length; i++) {
//         haystackLower[i] = _toLowerByte(_haystack[i]);
//     }
    
//     for (uint256 i = 0; i < _needle.length; i++) {
//         needleLower[i] = _toLowerByte(_needle[i]);
//     }
    
//     // Search for substring
//     for (uint256 i = 0; i <= haystackLower.length - needleLower.length; i++) {
//         bool isMatch = true;
//         for (uint256 j = 0; j < needleLower.length; j++) {
//             if (haystackLower[i + j] != needleLower[j]) {
//                 isMatch = false;
//                 break;
//             }
//         }
//         if (isMatch) return true;
//     }
    
//     return false;
// }

// /**
//  * @dev Convert a byte to lowercase if it's an uppercase letter
//  * @param _b Byte to convert
//  * @return bytes1 Lowercase byte
//  */
// function _toLowerByte(bytes1 _b) internal pure returns (bytes1) {
//     if (_b >= 0x41 && _b <= 0x5A) { // A-Z
//         return bytes1(uint8(_b) + 32);
//     }
//     return _b;
// }

// /**
//  * @dev Convert string to lowercase
//  * @param _str String to convert
//  * @return string Lowercase string
//  */
// function _toLower(string memory _str) internal pure returns (string memory) {
//     bytes memory bStr = bytes(_str);
//     bytes memory bLower = new bytes(bStr.length);
    
//     for (uint256 i = 0; i < bStr.length; i++) {
//         bLower[i] = _toLowerByte(bStr[i]);
//     }
    
//     return string(bLower);
// }     
// function getAgentsInfoPaginatedWithPemissions(
//         uint256 _fromTime,
//         uint256 _toTime,
//         string memory _sortBy,
//         bool _ascending,
//         uint256 _page,
//         uint256 _pageSize,
//         bool[4] memory _permissionFilter  // [IQR, Loyalty, MeOS] - true = must have, false = ignore
//     ) external view returns (
//         AgentInfo[] memory agents,
//         uint256 totalCount,
//         uint256 totalPages,
//         uint256 currentPage
//     ) {
//         // Filter by time first
//         address[] memory timeFiltered = _filterAgentsByTime(_fromTime, _toTime);
//         // Then filter by permissions
//         address[] memory permissionFiltered = _filterAgentsByPermissions(timeFiltered, _permissionFilter);

//         // Sort the filtered agents
//         address[] memory sortedAddresses;
//         if(permissionFiltered.length >=1){
//             sortedAddresses = _sortAgents(permissionFiltered, _sortBy, _ascending);
//         }        
//         totalCount = sortedAddresses.length;
//         totalPages = totalCount > 0 ? (totalCount + _pageSize - 1) / _pageSize : 0;
//         currentPage = _page;
        
//         // Calculate pagination
//         if (_page == 0 || _page > totalPages || totalCount == 0) {
//             return (new AgentInfo[](0), totalCount, totalPages, currentPage);
//         }
        
//         uint256 startIndex = (_page - 1) * _pageSize;
//         uint256 endIndex = startIndex + _pageSize;
//         if (endIndex > totalCount) {
//             endIndex = totalCount;
//         }
        
//         // // Build page result
//         uint256 pageLength = endIndex - startIndex;
//         AgentInfo[] memory pageResult = new AgentInfo[](pageLength);
        
//         for (uint256 i = 0; i < pageLength; i++) {
//             pageResult[i] = _buildAgentInfo(sortedAddresses[startIndex + i]);
//         }
        
//         return (pageResult, totalCount, totalPages, currentPage);
//     }
    
//     /**
//      * @dev Filter agents by permissions
//      * Only returns agents that have ALL the permissions marked as true in the filter
//      */
//     function _filterAgentsByPermissions(
//         address[] memory _agents,
//         bool[4] memory _permissionFilter
//     ) internal view returns (address[] memory) {
//         // Count matching agents
//         uint256 count = 0;
//         for (uint256 i = 0; i < _agents.length; i++) {
//             if (_hasRequiredPermissions(_agents[i], _permissionFilter)) {
//                 count++;
//             }
//         }
        
//         // Build filtered array
//         address[] memory filtered = new address[](count);
//         uint256 index = 0;
        
//         for (uint256 i = 0; i < _agents.length; i++) {
//             if (_hasRequiredPermissions(_agents[i], _permissionFilter)) {
//                 filtered[index] = _agents[i];
//                 index++;
//             }
//         }
        
//         return filtered;
//     }
    
//     /**
//      * @dev Check if agent has all required permissions
//      */
//     function _hasRequiredPermissions(
//         address _agent,
//         bool[4] memory _required
//     ) internal view returns (bool) {
//         Agent memory agent = agents[_agent];
        
//         // Check each permission
//         for (uint8 i = 0; i < 3; i++) {
//             if (_required[i] && !agent.permissions[i]) {
//                 return false; // Required permission not found
//             }
//         }
        
//         return true;
//     }
// }

// /**
//  * @title MeOS License Manager
//  * @dev Separate contract for managing MeOS licenses and validation
//  */
// contract MeOSLicenseManager is OwnableUpgradeable {
        
//     mapping(string => License) public licenses;
//     mapping(address => string[]) public agentLicenses;
//     mapping(bytes32 => string) public hardwareToLicense;
    
//     string[] public allLicenseKeys;
    
//     event LicenseCreated(string indexed licenseKey, address indexed agent, uint256 expiryAt);
//     event LicenseActivated(string indexed licenseKey, bytes32 hardwareFingerprint);
//     event LicenseDeactivated(string indexed licenseKey, address indexed agent);
//     event LicenseValidated(string indexed licenseKey, bool isValid);
    
//     /**
//      * @dev Create new MeOS license
//      */
//     function createLicense(
//         address _agent,
//         uint256 _durationDays,
//         uint256 _maxInstalls,
//         string memory _version
//     ) external onlyOwner returns (string memory) {
//         string memory licenseKey = _generateSecureLicenseKey(_agent, _version);
        
//         licenses[licenseKey] = License({
//             licenseKey: licenseKey,
//             agent: _agent,
//             isActive: true,
//             createdAt: block.timestamp,
//             expiryAt: block.timestamp + (_durationDays * 1 days),
//             installCount: 0,
//             maxInstalls: _maxInstalls,
//             version: _version,
//             hardwareFingerprint: bytes32(0)
//         });
        
//         agentLicenses[_agent].push(licenseKey);
//         allLicenseKeys.push(licenseKey);
        
//         emit LicenseCreated(licenseKey, _agent, licenses[licenseKey].expiryAt);
//         return licenseKey;
//     }
    
//     /**
//      * @dev Validate license for installation
//      */
//     function validateLicense(
//         string memory _licenseKey,
//         bytes32 _hardwareFingerprint
//     ) public view returns (bool isValid, string memory reason) {
//         License memory license = licenses[_licenseKey];
        
//         if (bytes(license.licenseKey).length == 0) {
//             return (false, "License not found");
//         }
        
//         if (!license.isActive) {
//             return (false, "License deactivated");
//         }
        
//         if (block.timestamp > license.expiryAt) {
//             return (false, "License expired");
//         }
        
//         if (license.installCount >= license.maxInstalls) {
//             return (false, "Maximum installations exceeded");
//         }
        
//         if (license.hardwareFingerprint != bytes32(0) && 
//             license.hardwareFingerprint != _hardwareFingerprint) {
//             return (false, "Hardware fingerprint mismatch");
//         }
        
//         return (true, "Valid");
//     }
    
//     /**
//      * @dev Activate license on hardware
//      */
//     function activateLicense(
//         string memory _licenseKey,
//         bytes32 _hardwareFingerprint
//     ) external onlyOwner returns (bool) {
//         (bool isValid, ) = validateLicense(_licenseKey, _hardwareFingerprint);
        
//         if (!isValid) return false;
        
//         License storage license = licenses[_licenseKey];
        
//         if (license.hardwareFingerprint == bytes32(0)) {
//             license.hardwareFingerprint = _hardwareFingerprint;
//             hardwareToLicense[_hardwareFingerprint] = _licenseKey;
//         }
        
//         license.installCount++;
        
//         emit LicenseActivated(_licenseKey, _hardwareFingerprint);
//         return true;
//     }
    
//     /**
//      * @dev Deactivate license
//      */
//     function deactivateLicense(string memory _licenseKey) external onlyOwner {
//         License storage license = licenses[_licenseKey];
//         require(bytes(license.licenseKey).length > 0, "License not found");
        
//         license.isActive = false;
        
//         if (license.hardwareFingerprint != bytes32(0)) {
//             delete hardwareToLicense[license.hardwareFingerprint];
//         }
        
//         emit LicenseDeactivated(_licenseKey, license.agent);
//     }
    
//     /**
//      * @dev Generate secure license key
//      */
//     function _generateSecureLicenseKey(address _agent, string memory _version) 
//         internal 
//         view 
//         returns (string memory) 
//     {
//         bytes32 hash = keccak256(abi.encodePacked(
//             _agent,
//             _version,
//             block.timestamp,
//             block.prevrandao,
//             msg.sender
//         ));
        
//         return string(abi.encodePacked("MEOS-", _toHexString(hash)));
//     }
    
//     /**
//      * @dev Convert bytes32 to hex string
//      */
//     function _toHexString(bytes32 _hash) internal pure returns (string memory) {
//         bytes memory alphabet = "0123456789ABCDEF";
//         bytes memory str = new bytes(64);
        
//         for (uint256 i = 0; i < 32; i++) {
//             str[i * 2] = alphabet[uint8(_hash[i] >> 4)];
//             str[1 + i * 2] = alphabet[uint8(_hash[i] & 0x0f)];
//         }
        
//         return string(str);
//     }
    
//     /**
//      * @dev Get agent licenses
//      */
//     function getAgentLicenses(address _agent) external view returns (string[] memory) {
//         return agentLicenses[_agent];
//     }
    
//     /**
//      * @dev Get license details
//      */
//     function getLicense(string memory _licenseKey) external view returns (License memory) {
//         return licenses[_licenseKey];
//     }
//     /**
//      * @dev Paginate agent results
//      */
//     function paginate(
//         address[] memory _allAgents,
//         uint256 _page,
//         uint256 _limit
//     ) internal pure returns (PaginationResult memory) {
//         require(_limit > 0, "Limit must be greater than 0");
//         require(_page > 0, "Page must be greater than 0");
        
//         uint256 totalCount = _allAgents.length;
//         uint256 totalPages = (totalCount + _limit - 1) / _limit; // Ceiling division
        
//         if (_page > totalPages) {
//             return PaginationResult({
//                 agents: new address[](0),
//                 totalCount: totalCount,
//                 currentPage: _page,
//                 totalPages: totalPages,
//                 hasNext: false,
//                 hasPrev: _page > 1
//             });
//         }
        
//         uint256 startIndex = (_page - 1) * _limit;
//         uint256 endIndex = startIndex + _limit;
//         if (endIndex > totalCount) {
//             endIndex = totalCount;
//         }
        
//         address[] memory pageAgents = new address[](endIndex - startIndex);
//         for (uint256 i = 0; i < pageAgents.length; i++) {
//             pageAgents[i] = _allAgents[startIndex + i];
//         }
        
//         return PaginationResult({
//             agents: pageAgents,
//             totalCount: totalCount,
//             currentPage: _page,
//             totalPages: totalPages,
//             hasNext: _page < totalPages,
//             hasPrev: _page > 1
//         });
//     }
    
//     /**
//      * @dev Format wallet address for display
//      */
//     function formatWalletAddress(address _wallet) internal pure returns (string memory) {
//         bytes memory walletBytes = abi.encodePacked(_wallet);
//         bytes memory alphabet = "0123456789abcdef";
        
//         bytes memory str = new bytes(42);
//         str[0] = '0';
//         str[1] = 'x';
        
//         for (uint256 i = 0; i < 20; i++) {
//             str[2 + i * 2] = alphabet[uint8(walletBytes[i] >> 4)];
//             str[3 + i * 2] = alphabet[uint8(walletBytes[i] & 0x0f)];
//         }
        
//         // Return shortened version: 0x1234...5678
//         bytes memory shortStr = new bytes(10);
//         for (uint256 i = 0; i < 6; i++) {
//             shortStr[i] = str[i];
//         }
//         shortStr[6] = '.';
//         shortStr[7] = '.';
//         shortStr[8] = '.';
//         for (uint256 i = 38; i < 42; i++) {
//             shortStr[i - 29] = str[i];
//         }
        
//         return string(shortStr);
//     }
// }