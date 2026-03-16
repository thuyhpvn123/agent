// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "forge-std/console.sol";

contract FreeGasStorage is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => bool) public isAllowed;
    address public iqrFactory;
    uint256[48] private __gap;
    event ContractRegistration(address indexed agent,address[] contracts);
    constructor() {
        _disableInitializers();
    }
    function initialize(address _iqrFactory) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        iqrFactory = _iqrFactory;
    }
    function _authorizeUpgrade(address newImplementation) internal override  {}
    modifier onlySCAllowed(){
        require(isAllowed[msg.sender],"caller is not allowed to add free contract");
        _;
    }
    modifier onlyAdmin(){
        require(msg.sender == iqrFactory || msg.sender == owner(),"only admin freegas can call");
        _;
    }
    function registerSCAdmin(address contractAdd, bool agreed)external onlyAdmin{
        isAllowed[contractAdd] = agreed;
     }
    function AddSC(
        address _agent,
        address[] memory contractAdds
    ) external onlySCAllowed {
        emit ContractRegistration(_agent, contractAdds);
    }
}
