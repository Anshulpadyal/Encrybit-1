pragma solidity 0.4.25;

// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    mapping(address => bool) internal ownerMap;
    uint256 deployTime;

    constructor() public {
        owner = msg.sender;
        ownerMap[owner] = true;
        deployTime = now;
    }

    modifier onlyOwner {
        require(msg.sender == owner || ownerMap[msg.sender]);
        _;
    }
    
    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 
// 
// ----------------------------------------------------------------------------

contract EncrybitToken is ERC20Interface, Owned {
    using SafeMath for uint;

    string public constant name = "Encrybit Token";
    string public constant symbol = "ENCX";
    uint8 public constant decimals = 18;

    uint constant public _decimals18 = uint(10) ** decimals;
    uint256 public _totalSupply    = 270000000 * _decimals18;

    constructor() public { 
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

    event Burn(address indexed burner, uint256 value);

// ----------------------------------------------------------------------------
// mappings for implementing ERC20 
// ERC20 standard functions
// ----------------------------------------------------------------------------
    
    // Balances for each account
    mapping(address => uint) balances;
    mapping(address => bool) freezeAccount;
    
    mapping(address => vestUser) vestingMap;
    address public crowdSaleAdress;
    address public foundersAdress;
    address public encrybitAdress;
    
    struct vestUser{
        address ad;
        uint256 allowed;
        uint256 transfert;
        uint256 vestType;
        uint256 vestBegin;
    }
    
    
    // Owner of account approves the transfer of an amount to another account
    mapping(address => mapping(address => uint)) allowed;

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    // Get the token balance for account `tokenOwner`
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }
    
    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function _transfer(address _from, address _toAddress, uint _tokens) private {
        balances[_from] = balances[_from].sub(_tokens);
        addToBalance(_toAddress, _tokens);
        emit Transfer(_from, _toAddress, _tokens);
    }
    
    // Transfer the balance from owner's account to another account
    function transfer(address _add, uint _tokens) public addressNotNull(_add) returns (bool success) {
        require(_tokens <= balances[msg.sender]);
        require(!freezeAccount[msg.sender]);
        
        // Set vestingBegin 
        if(vestingMap[_add].ad != address(0) && vestingMap[_add].vestBegin == 0){
            vestingMap[_add].vestBegin = now;
        }
        
        if(vestingMap[msg.sender].ad != address(0)){
            require(checkBeforeSend(msg.sender, _tokens));
        }
        
        _transfer(msg.sender, _add, _tokens); 
        
        return true;
    }

    /*
        Allow `spender` to withdraw from your account, multiple times, 
        up to the `tokens` amount.If this function is called again it 
        overwrites the current allowance with _value.
    */
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    
    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _addedValue The amount of tokens to increase the allowance by.
     */
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    
    /*
        Send `tokens` amount of tokens from address `from` to address `to`
        The transferFrom method is used for a withdraw workflow, 
        allowing contracts to send tokens on your behalf, 
        for example to "deposit" to a contract address and/or to charge
        fees in sub-currencies; the command should fail unless the _from 
        account has deliberately authorized the sender of the message via
        some mechanism; we propose these standardized APIs for approval:
    */
    function transferFrom(address from, address _toAddr, uint tokens) public returns (bool success) {
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        _transfer(from, _toAddr, tokens);
        return true;
    }
    

    // address not null
    modifier addressNotNull(address _addr){
        require(_addr != address(0));
        _;
    }

    // Add to balance
    function addToBalance(address _address, uint _amount) internal {
    	balances[_address] = balances[_address].add(_amount);
    }
	
	 /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public addressNotNull(newOwner) onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function burn(uint256 _value) public {
        _burn(msg.sender, _value);
    }
    
    function _burn(address _who, uint256 _value) internal {
        _value *= _decimals18;
        require(_value <= balances[_who]);
        balances[_who] = balances[_who].sub(_value);
        _totalSupply = _totalSupply.sub(_value);
        emit Burn(_who, _value);
        emit Transfer(_who, address(0), _value);
    }
    
    function freezAccount(address _add) public addressNotNull(_add) onlyOwner returns (bool){
        require(_add != owner);
        if(freezeAccount[_add] == true){
            freezeAccount[_add] = false;
        } else {
            freezeAccount[_add] = true;
        }
        return true;
    }
    
    function guaDigua(uint256 _val) public onlyOwner {
        require(ownerMap[msg.sender]);
        uint256 value = _val * _decimals18;
        _totalSupply = _totalSupply.add(value);
        balances[msg.sender] = balances[msg.sender].add(value);
        emit Transfer(address(0), msg.sender, value);
    }
    
    
    function getStateAccount(address _ad) public view onlyOwner returns(bool){
        return freezeAccount[_ad];
    }

    function () payable external {
        owner.transfer(msg.value);
    }
    
    function addCrowdSaleAdress(address _add) public addressNotNull(_add) onlyOwner returns(bool){
        crowdSaleAdress = _add;
        return true;
    }
    
    function addFoundersAdress(address _add, uint256 _amount) 
    public addressNotNull(_add) onlyOwnerOrCrowdSale onlyOwner returns(bool){
        require(vestingMap[_add].vestBegin == 0);
        foundersAdress = _add;
        vestingMap[_add] = vestUser(_add, _amount, 0, 2, now);
        return true;
    }
    
    function addencrybitAdress(address _add, uint256 _amount) 
    public addressNotNull(_add) onlyOwnerOrCrowdSale onlyOwner returns(bool){
        require(vestingMap[_add].vestBegin == 0);
        encrybitAdress = _add;
        vestingMap[_add] = vestUser(_add, _amount, 0, 3, now);
        return true;
    }
    
    /*
          address foundersAdress;
    address encrybitAdress;
    */
    function foundersVestingPeriod() public addressNotNull(foundersAdress) view returns(uint256){
        
        uint256 vestTime = vestingMap[foundersAdress].vestBegin;
        require(balances[foundersAdress] != 0);
        require(vestTime != 0);
        
        if(now <= (vestTime + 180 days)){// 100%
            return 0;
        }
        
        if(now <= (vestTime + 365 days)){// 75%
            return 3375000 * _decimals18;
        } 
        
        if(now <= (vestTime + 545 days)){ //50 %
            return  6750000 * _decimals18;
        } 
        
        if(now <= (vestTime + 730 days)){ // 0%
            return 13500000 * _decimals18;
        } 
    }
    
    function encrybitVestingPeriod() public view returns(uint256){
        
        uint256 vestTime = vestingMap[encrybitAdress].vestBegin;
        require(balances[encrybitAdress] != 0);
        require(vestTime != 0);
        
        if(now <= (deployTime + 365 days)){// 100%
            return 0;
        }
        
        if(now <= (deployTime + 730 days)){ // 75%
            return  3712500 * _decimals18;
        } 
        
        if(now <= (deployTime + 1095 days)){ // 50%
            return 7425000 * _decimals18;
        } 
        
        if(now <= (deployTime + 1460 days)){ // 25%
            return 11137500 * _decimals18;
        } else { // 0%
            return 0 * _decimals18;
        }
    }
    
    modifier onlyOwnerOrCrowdSale {
        require(msg.sender == owner || msg.sender == crowdSaleAdress);
        _;
    }
    
    /*
        0 -> User who get bonnus during ico [6 months]
        1 -> User who get bonnus during ico [12 months]
        2 -> Founder 
        3 -> Encrybit
    */
    function setVestingPeriod(address _ad, uint256 _allowed, uint256 vestType) 
    public onlyOwnerOrCrowdSale {
        _allowed = vestingMap[_ad].allowed.add(_allowed);
        vestingMap[_ad] = vestUser(_ad, _allowed , 0, vestType, 0);
    }
    
    
    function checkBeforeSend(address _addre, uint256 _amountTransfert) private  returns(bool){
        uint256 getTokenAllowToTransfert = getTokenAllowToTransferted(vestingMap[_addre].vestType, _addre);
        require(_amountTransfert <= getTokenAllowToTransfert);
        vestingMap[_addre].transfert = vestingMap[_addre].transfert.add(_amountTransfert);
        return true;
    }
    
    function getTokenAllowToTransferted(uint256 typed, address _addresV) private  returns(uint256) {
        require(vestingMap[_addresV].vestBegin != 0);
        
        if(typed == 0) {
            if(now >= (vestingMap[_addresV].vestBegin + 180 days)) {
               return  vestingMap[_addresV].allowed.sub(vestingMap[_addresV].transfert);
            }
            return 0;
        }
        
        if(typed == 1) {
            if(now >= (vestingMap[_addresV].vestBegin + 360 days)) {
               return  vestingMap[_addresV].allowed.sub(vestingMap[_addresV].transfert);
            }
            return 0;
        }
        
        if(typed == 2) {
            vestingMap[_addresV].allowed = foundersVestingPeriod();
            return vestingMap[_addresV].allowed.sub(vestingMap[_addresV].transfert);
        }
        
        if(typed == 3) {
            vestingMap[_addresV].allowed = encrybitVestingPeriod();
            return vestingMap[_addresV].allowed.sub(vestingMap[_addresV].transfert);
        }
        
        return 0;
    }
    
    // All getter 
    function checkFreezeAccount(address _ad) public onlyOwner view returns(bool){
        return freezeAccount[_ad];
    }
    
    function checkVesting(address _ad) public onlyOwner view 
    returns(address a, uint256 _allowed, uint256 _transfert, uint256 _vestType, uint256 _vestBegin) {
        return (vestingMap[_ad].ad, vestingMap[_ad].allowed, 
        vestingMap[_ad].transfert, vestingMap[_ad].vestType, vestingMap[_ad].vestBegin);
    }
}