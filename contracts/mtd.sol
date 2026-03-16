// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
contract MTDToken is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    string public version;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Additional tracking for dashboard
    uint256 public lockedSupply;
    uint256 public burnedSupply;
    uint256 public frozenSupply;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Lock(uint256 amount);
    event Unlock(uint256 amount);
    event Freeze(uint256 amount);
    event Unfreeze(uint256 amount);
    event ContractUpgraded(string oldVersion, string newVersion, uint256 timestamp);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(uint256 _initialSupply) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        version = "1.0.0";
        name = "MetaData Token";
        symbol = "MTD";
        decimals = 18;
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // function upgradeToAndCall(
    //     address newImplementation,
    //     bytes memory data,
    //     string memory newVersion
    // ) external onlyOwner {
    //     string memory oldVersion = version;
    //     _upgradeToAndCallUUPS(newImplementation, data, true);
    //     version = newVersion;
    //     emit ContractUpgraded(oldVersion, newVersion, block.timestamp);
    // }
    
    function transfer(address _to, uint256 _amount) external returns (bool) {
        return _transfer(msg.sender, _to, _amount);
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        require(allowance[_from][msg.sender] >= _amount, "Insufficient allowance");
        allowance[_from][msg.sender] -= _amount;
        return _transfer(_from, _to, _amount);
    }
    
    function _transfer(address _from, address _to, uint256 _amount) internal returns (bool) {
        require(_from != address(0) && _to != address(0), "Invalid addresses");
        require(balanceOf[_from] >= _amount, "Insufficient balance");
        
        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;
        
        emit Transfer(_from, _to, _amount);
        return true;
    }
    
    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }
    
    function mint(address _to, uint256 _amount) external onlyOwner {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
    }
    
    function burn(uint256 _amount) external {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        burnedSupply += _amount;
        
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }
    
    function lock(uint256 _amount) external onlyOwner {
        lockedSupply += _amount;
        emit Lock(_amount);
    }
    
    function unlock(uint256 _amount) external onlyOwner {
        require(lockedSupply >= _amount, "Insufficient locked supply");
        lockedSupply -= _amount;
        emit Unlock(_amount);
    }
    
    function freeze(uint256 _amount) external onlyOwner {
        frozenSupply += _amount;
        emit Freeze(_amount);
    }
    
    function unfreeze(uint256 _amount) external onlyOwner {
        require(frozenSupply >= _amount, "Insufficient frozen supply");
        frozenSupply -= _amount;
        emit Unfreeze(_amount);
    }
    
    function getTokenStats() external view returns (
        uint256 _totalSupply,
        uint256 _lockedSupply,
        uint256 _burnedSupply,
        uint256 _frozenSupply,
        uint256 _availableSupply
    ) {
        _totalSupply = totalSupply;
        _lockedSupply = lockedSupply;
        _burnedSupply = burnedSupply;
        _frozenSupply = frozenSupply;
        _availableSupply = totalSupply - lockedSupply - frozenSupply;
    }
    
    function getVersion() external view returns (string memory) {
        return version;
    }
    
}
