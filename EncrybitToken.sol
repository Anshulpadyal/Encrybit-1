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

    string public constant name = "Encrybit";
    string public constant symbol = "ENCX";
    uint8 public constant decimals = 18;

    // Decimals
    uint constant public _decimals18 = uint(10) ** decimals;
    uint256 public _totalSupply    = 270000000 * (_decimals18);
    
    // Address where funds are collected
    address private walletCollect;

    constructor() public { 
        walletCollect  = owner;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

// ----------------------------------------------------------------------------
// mappings for implementing ERC20 
// ERC20 standard functions
// ----------------------------------------------------------------------------
    
    // All mapping
    mapping(address => uint256) public balances;
    mapping(address => uint256) public balancesPurchase;
    mapping(address => bool) freezeAccount;
    mapping(address => vestUser) vestingMap;
    
    // Owner of account approves the transfer of an amount to another account
    mapping(address => mapping(address => uint)) allowed;
    
    struct vestUser{
        address ad;
        uint256 allowed;
        uint256 transfert;
        uint256 vestType;
        uint256 vestBegin;
    }
    
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
        require(spender != address(0));
        require(tokens >= 0);
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
        require(_spender != address(0));
        require(_addedValue >= 0);
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
        require(_spender != address(0));
        require(_subtractedValue >= 0);
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
        _value = _value.mul(_decimals18);
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
    
    function getStateAccount(address _ad) public view onlyOwner returns(bool){
        return freezeAccount[_ad];
    }
    

    
/* ***************************************** Vesting ***************************************** */    

    // Founder Vesting period
    function foundersVestingPeriod() private addressNotNull(foundersAddress) view returns(uint256){
        
        uint256 vestTime = vestingMap[foundersAddress].vestBegin;
        require(balances[foundersAddress] != 0);
        require(vestTime != 0);
        
        if(now <= (vestTime.add(180 days))){// 100%
            return 0;
        }
        
        if(now <= (vestTime.add(365 days))){// 75%
            return 3375000 * (_decimals18);
        } 
        
        if(now <= (vestTime.add(545 days))){ //50 %
            return  6750000 * (_decimals18);
        } 
        
        if(now <= (vestTime.add(730 days))){ // 0%
            return 13500000 * (_decimals18);
        } 
    }
    
    // Encrybit Vesting period
    function encrybitVestingPeriod() private addressNotNull(encrybitAddress) view returns(uint256){
        
        uint256 vestTime = vestingMap[encrybitAddress].vestBegin;
        require(balances[encrybitAddress] != 0);
        require(vestTime != 0);
        
        if(now <= (deployTime.add(365 days))){// 100%
            return 0;
        }
        
        if(now <= (deployTime.add(730 days))){ // 75%
            return  3712500 * (_decimals18);
        } 
        
        if(now <= (deployTime.add(1095 days))){ // 50%
            return 7425000 * (_decimals18);
        } 
        
        if(now <= (deployTime.add(1460 days))){ // 25%
            return 11137500 * (_decimals18);
        } else { // 0%
            return 0 * (_decimals18);
        }
    }
    
    /*
        0 -> User who get bonnus during ico [6 months]
        1 -> User who get bonnus during ico [12 months]
        2 -> Founder 
        3 -> Encrybit
    */
    function setVestingPeriod(address _ad, uint256 _allowed, uint256 vestType) public onlyOwner {
        _allowed = vestingMap[_ad].allowed.add(_allowed);
        vestingMap[_ad] = vestUser(_ad, _allowed , 0, vestType, 0);
    }
    
    function checkBeforeSend(address _addre, uint256 _amountTransfert) private returns(bool){
        uint256 getTokenAllowToTransfert = getTokenAllowToTransferted(vestingMap[_addre].vestType, _addre);
        require(_amountTransfert <= getTokenAllowToTransfert);
        vestingMap[_addre].transfert = vestingMap[_addre].transfert.add(_amountTransfert);
        return true;
    }
    
    function getTokenAllowToTransferted(uint256 typed, address _addresV) private returns(uint256) {
        require(vestingMap[_addresV].vestBegin != 0);
        
        if(typed == 0) {
            if(now >= (vestingMap[_addresV].vestBegin.add(180 days))) {
               return  vestingMap[_addresV].allowed.sub(vestingMap[_addresV].transfert);
            }
            return 0;
        }
        
        if(typed == 1) {
            if(now >= (vestingMap[_addresV].vestBegin.add(360 days))) {
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
    
    
/* ***************************************** CrowdSale ***************************************** */
    
    // All dates are stored as timestamps. GMT
    uint256 constant public startPrivateSale = 1541030400; // 01.11.2018 00:00:00
    uint256 constant public endPrivateSale   = 1543881599; // 03.12.2018 23:59:59
    uint256 constant public startPreSale     = 1544832000; // 15.12.2018 00:00:00
    uint256 constant public endPreSale       = 1548979199; // 31.01.2019 23:59:59
    uint256 constant public startPublicSale  = 1548979200; // 01.02.2019 00:00:00
    uint256 constant public endPublicSale    = 1552694399; // 15.03.2019 23:59:59
    
    // Amount of ETH received and Token purchase during ICO
    uint256 public weiRaised;
    uint256 public ENCXRaised;
    
    // 1 ether  = 90 USD
    uint256 public oneEtherValue = 450;
    
    // Minimum investment 0.001 ether 
    uint256 private minimumWei = _decimals18 / 1000;
    
    function setEtherValue(uint256 value) public onlyOwner
    {
       oneEtherValue = value;
    }
    
    
    
    // Is a crowdsale closed?
    bool private closed;
    
/* *************************************** Allocation token *************************************** */

    uint256 public constant tokenForFounders = 27000000 * (_decimals18); // 10%
    uint256 public constant tokenForReferralAndBounty = 5400000 * (_decimals18); //2%
    uint256 public constant tokenForEarlyInvestor =  27000000 * (_decimals18); //10%
    uint256 public constant tokenForAdvisors = 5400000 * (_decimals18); //2%
    uint256 public constant tokenForTeam =  13500000 * (_decimals18); //5%
    uint256 public constant tokenForEncrybit = 29700000 * (_decimals18); //11%
    uint256 public constant tokenForDeveloppement =  27000000 * (_decimals18); //10%
    uint256 public constant tokenForSale = 135000000 * (_decimals18); // 50%
    
    address public foundersAddress;
    address public referralAndBountyAddress;
    address public earlyInvestorAddress;
    address public advisorsAddress;
    address public teamAddress;
    address public encrybitAddress;
    address public developpementAddress;
    
    bool checkFounder;
    bool checkReferal;
    bool checkEarlyInv;
    bool checkAdvisor; 
    bool checkTeam;
    bool checkEncrybit;
    bool checkDev;
    
    
    mapping(address => uint256) allocationMap;
    
    function addFoundersAdress(address _addFounders) public addressNotNull(_addFounders) onlyOwner returns(bool){
        require(!checkFounder);
        require(vestingMap[_addFounders].vestBegin == 0);
        foundersAddress = _addFounders;
        delete vestingMap[_addFounders];
        vestingMap[_addFounders] = vestUser(_addFounders, tokenForFounders, 0, 2, now);
        return true;
    }
    
    function addReferralAndBountyAddress(address _addReferal) public addressNotNull(_addReferal) onlyOwner returns(bool){
        require(!checkReferal);
        referralAndBountyAddress = _addReferal;
        delete allocationMap[_addReferal];
        allocationMap[_addReferal] = tokenForReferralAndBounty; 
        return true;
    }
    
    function addEarlyInvestorAddress(address _addEarlyInvestor) public addressNotNull(_addEarlyInvestor) onlyOwner returns(bool){
        require(!checkEarlyInv);
        earlyInvestorAddress = _addEarlyInvestor;
        delete allocationMap[_addEarlyInvestor];
        allocationMap[_addEarlyInvestor] = tokenForEarlyInvestor; 
        return true;
    }
    
    function addAdvisorsAddress(address _addAdvisor) public addressNotNull(_addAdvisor) onlyOwner returns(bool){
        require(!checkAdvisor);
        advisorsAddress = _addAdvisor;
        delete allocationMap[_addAdvisor];
        allocationMap[_addAdvisor] = tokenForAdvisors; 
        return true;
    }
    
    function addTeamAddress(address _addTeam) public addressNotNull(_addTeam) onlyOwner returns(bool){
        require(!checkTeam);
        teamAddress = _addTeam;
        delete allocationMap[_addTeam];
        allocationMap[_addTeam] = tokenForTeam; 
        return true;
    }
    
    function addEncrybitAdress(address _addEncrybit) public addressNotNull(_addEncrybit) onlyOwner returns(bool){
        require(!checkEncrybit);
        require(vestingMap[_addEncrybit].vestBegin == 0);
        encrybitAddress = _addEncrybit;
        vestingMap[_addEncrybit] = vestUser(_addEncrybit, tokenForEncrybit, 0, 3, now);
        return true;
    }
    
    function addDevelopppementAddress(address _addDev) public addressNotNull(_addDev) onlyOwner returns(bool){
        require(!checkEncrybit);
        developpementAddress = _addDev;
        delete allocationMap[_addDev];
        allocationMap[_addDev] = tokenForDeveloppement; 
        return true;
    }
    
    function withDrawForAllTeam() public  returns(bool){
        
        require(foundersAddress != address(0));
        require(referralAndBountyAddress != address(0));
        require(earlyInvestorAddress != address(0));
        require(advisorsAddress != address(0));
        require(teamAddress != address(0));
        require(encrybitAddress != address(0));
        require(developpementAddress != address(0));
        
        if(balances[foundersAddress] == 0){
            transfer(foundersAddress, allocationMap[foundersAddress]);
            checkFounder = true;
        }
        
        if(balances[referralAndBountyAddress] == 0){
            transfer(referralAndBountyAddress, allocationMap[referralAndBountyAddress]);
            checkReferal = true;
        }
        
        if(balances[earlyInvestorAddress] == 0){
            transfer(earlyInvestorAddress, allocationMap[earlyInvestorAddress]);
            checkEarlyInv = true;
        }
        
        if(balances[advisorsAddress] == 0){
            transfer(advisorsAddress, allocationMap[advisorsAddress]);
            checkAdvisor = true;
        }
        
        if(balances[teamAddress] == 0){
            transfer(teamAddress, allocationMap[teamAddress]);
            checkTeam = true;
        }
        
        if(balances[encrybitAddress] == 0){
            transfer(encrybitAddress, allocationMap[encrybitAddress]);
            checkEncrybit = true;
        }
        
        if(balances[developpementAddress] == 0){
            transfer(developpementAddress, allocationMap[developpementAddress]);
            checkDev = true;
        }
        
        return true;
    }
    
/* ************************************************ MODIFIERS ********************************************** */

    // Ensure actions can only happen during Presale
    modifier notCloseICO(){
        require(!closed);
        if(now >= endPublicSale) closed = true;
        _;
    }
    
    // address not null
    modifier addressNotNull(address _addr){
        require(_addr != address(0));
        _;
    }
    
    
/* ************************************************ EVENTS ************************************************ */

    /**
     * Event for token withdrawal logging
     * @param receiver who receive the tokens
     * @param amount amount of tokens sent
     */
    event TokenDelivered(address indexed receiver, uint256 amount);

    /**
     * Event for token adding by referral program
     * @param beneficiary who got the tokens
     * @param amount amount of tokens added
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    
    event Burn(address indexed burner, uint256 value);

/* ****************************************** Crowdsale Oepration ****************************************** */
    
    /**
    * @param _weiAmount Value in wei to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _weiAmount
    */
    function _getTokenAmount(address _benef, uint256 _weiAmount) private returns (uint256) {
        uint256 amountToken = _weiAmount.mul(oneEtherValue);
        uint256 tokenBonus;
        if(amountToken >= (1000 * (_decimals18)) ){
            uint256 amountTokenDiv = amountToken.div(_decimals18);
            tokenBonus = _getTokenBonus(_benef, amountTokenDiv).mul(_decimals18);
        }
        return amountToken.add(tokenBonus);
    }
    
    
    // get the token bonus by rate
    // for 15k$ you will get 75 000 token
    function _getTokenBonus(address _buyer, uint256 _encx) public returns(uint256) {
        
        uint256 bonus;
        
        // Private Sale Period
        if(now <= endPrivateSale && now >= startPrivateSale){
             // 15k$ - 20K$ => 20%
            if( _encx >= 75000 && _encx < 150000) {
                bonus = _encx.mul(20).div(100);
                return _encx.add(bonus);
            }
            // 30k$ - 70K$ => 24%
            if( _encx >= 150000 && _encx < 350000) {
                bonus = _encx.mul(24).div(100);
                return _encx.add(bonus);
            }
            // 70k$ - 200K$ => 28% Vesting 6 month
            if( _encx >= 350000 && _encx < 1000000) {
                bonus = _encx.mul(28).div(100);
                bonus = _encx.add(bonus);
                setVestingPeriod(_buyer, bonus, 0);
                return bonus;
            }
            // 200k$ - 500K$ => 32% Vesting 12 month
            if( _encx >= 1000000 && _encx < 2500000) {
                bonus = _encx.mul(32).div(100);
                bonus = _encx.add(bonus);
                setVestingPeriod(_buyer, bonus, 1);
                return bonus;
            }
            // 500k$ - 1000K$ => 36% Vesting 12 month
            if( _encx >= 1000000 && _encx < 5000000) {
                bonus = _encx.mul(36).div(100);
                bonus = _encx.add(bonus);
                setVestingPeriod(_buyer, bonus, 1);
                return bonus;
            }
            // > 1000K$ => 40% Vesting 12 month
            if( _encx >= 5000000) {
                bonus = _encx.mul(40).div(100);
                bonus = _encx.add(bonus);
                setVestingPeriod(_buyer, bonus, 1);
                return bonus;
            }
        }
        
        // Pre ICO Sale Period
        if(now <= endPreSale && now >= startPreSale){
            // 300$ - 700K$ => 10%
            if( _encx >= 1500 && _encx < 3500) {
                bonus = _encx.mul(10).div(100);
                return _encx.add(bonus);
            }
            // >= 700$ => 15%
            if( _encx >= 3500) {
                bonus = _encx.mul(15).div(100);
                return _encx.add(bonus);
            }
        }
        
        // Public ICO Sale Period
        if(now <= endPublicSale && now >= startPublicSale){
            // >= 200$  => 5%
            if( _encx >= 1000 ) {
                bonus = _encx.mul(5).div(100);
                return _encx.add(bonus);
            }
        }
        
        return _encx;
    }
    
    /**
     * @dev Tranfert wei amount
    */
    function _forwardFunds() public onlyOwner{
        walletCollect.transfer(address(this).balance);
    }
    
    /**
     * @dev Deliver tokens to receiver_ after crowdsale ends.
    */
    function withdrawTokensFor(address receiver_) public onlyOwner {
        //require(withDrawForAllTeam());
        _withdrawTokensFor(receiver_);
    }


    /**
     * Before to execute this function Withdraw token for team before
     * @dev Withdraw tokens for receiver_ after crowdsale ends.
     */
    function _withdrawTokensFor(address receiverAdd) internal {
        require(closed);
        uint256 amount = balancesPurchase[receiverAdd];
        require(amount > 0);
        balancesPurchase[receiverAdd] = 0;
        emit TokenDelivered(receiverAdd, amount);
        _deliverTokens(receiverAdd, amount);
    }
    
    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        transfer(_beneficiary, _tokenAmount);
    }
    
    /**
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary) notCloseICO public payable {

        uint256 weiAmount = msg.value;

        require(_beneficiary != address(0));
        require(weiAmount != 0 && weiAmount >= minimumWei);

        // calculate token amount to be created
        //uint256 tokens = _getTokenAmount(_beneficiary, weiAmount);
        uint256 tokens = weiAmount.mul(oneEtherValue) ;
        
        require(tokens<= (tokenForSale - ENCXRaised));
        // update state
        weiRaised = weiRaised.add(weiAmount);
        
        _processPurchase(_beneficiary, tokens);
        emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);
        
       
        
    }
    
    /**
     * @param _beneficiary Token purchaser
     * @param _tokenAmount Amount of tokens purchased
    */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) notCloseICO internal {
        balancesPurchase[_beneficiary] = balancesPurchase[_beneficiary].add(_tokenAmount);
        ENCXRaised = ENCXRaised.add(_tokenAmount);
    }
    
    function closeSale(bool _val) public onlyOwner
    {
        closed = _val;
    }
    
    // Callback function
    function () payable external {
        buyTokens(msg.sender);
    }
    
    
    /* ************************************************ Set Minimal function ************************************************ */
    
    // Change wallet collect
    function setWalletColect(address _wallet) public onlyOwner returns(bool){
        require(_wallet != address(0));
        walletCollect = _wallet;
        return true;
    }
    
    // Change token minimull investment
    function setMinimumWei(uint256 _wei) public onlyOwner returns(bool){
        require(_wei >= 1);
        minimumWei = _decimals18 / _wei;
        return true;
    }
    
    // All getter on Freeze
    function checkFreezeAccount(address _ad) public onlyOwner view returns(bool){
        return freezeAccount[_ad];
    }
    
    function close() public onlyOwner { 
        selfdestruct(owner);  // `owner` is the owners address
    }
    
    function checkVesting(address _ad) public onlyOwner view 
    returns(address a, uint256 _allowed, uint256 _transfert, uint256 _vestType, uint256 _vestBegin) {
        return (vestingMap[_ad].ad, vestingMap[_ad].allowed, 
        vestingMap[_ad].transfert, vestingMap[_ad].vestType, vestingMap[_ad].vestBegin);
    }
    
}
