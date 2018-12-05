pragma solidity 0.4.25;

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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
    
    mapping(address => bool) ownerMap;

    constructor() public {
        owner = msg.sender;
        ownerMap[owner] = true;
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



/**
 * @title EncrybitTokenCrowdsale
 * @dev Crowdsale that locks tokens from withdrawal until it ends.
 */
contract EncrybitTokenCrowdsale is Owned {
    using SafeMath for uint256;
    
    /////////////////////// VARIABLE INITIALIZATION ///////////////////////
    
    
    // All dates are stored as timestamps. GMT
    uint256 constant public startPrivateSale = 1541030400; // 01.11.2018 00:00:00
    uint256 constant public endPrivateSale   = 1543881599; // 03.12.2018 23:59:59
    uint256 constant public startPreSale     = 1544832000; // 15.12.2018 00:00:00
    uint256 constant public endPreSale       = 1548979199; // 31.01.2019 23:59:59
    uint256 constant public startPublicSale  = 1548979200; // 01.02.2019 00:00:00
    uint256 constant public endPublicSale    = 1552694399; // 15.03.2019 23:59:59
    
    // Decimals
    uint8 public constant decimals = 18;
    uint constant public _decimals18 = uint(10) ** decimals;
    
    // Amount of ETH received and Token purchase during ICO
    uint256 public weiRaised;
    uint256 public ENCXRaised;
    
    // 1 ether  = 1000 ENCX
    uint256 private oneEtherValue = 1000;
    
    // Minimum investment 0.001 ether 
    uint256 private minimumWei = _decimals18 / 1000;
    
    // Map of all purchaiser's balances 
    mapping(address => uint256) public balances;
    
    // Is a crowdsale closed?
    bool private closed;
    
    // Address where funds are collected
    address private walletCollect;
    
    // Allocation token 
    uint256 public constant tokenForSale = 135000000 * _decimals18; // 50%
    uint256 public constant tokenForReferralAndBounty = 2700000 * _decimals18; //2%
    uint256 public tokenForAdvisors = 2700000 * _decimals18; //2%
    uint256 public constant tokenForEncrybit = 14850000 * _decimals18; //11%
    uint256 public constant tokenForFounders = 13500000 * _decimals18; // 10%
    uint256 public constant tokenForEarlyInvestor =  13500000 * _decimals18; //10%
    uint256 public constant tokenForTeam =  6750000 * _decimals18; //5%
    uint256 public constant tokenForDeveloppement =  13500000 * _decimals18; //10%
    
    
    // Address
    address public advisorsAddress;
    address public encrybitAddress;
    address public foundersAddress;
    address public earlyInvestorAddress;
    address public teamAddress;
    address public DeveloppementAddress;
    
    // The token being sold
    ERC20 public token;
    
    
    /////////////////////// MODIFIERS ///////////////////////

    // Ensure actions can only happen during Presale
    
    modifier notCloseICO(){
        require(!closed);
        _;
    }
    
    /////////////////////// EVENTS ///////////////////////

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

    
    constructor(ERC20 _token) public {
        require(_token != address(0));
        token = _token;
        walletCollect  = owner;
    }
    
    /**
    * @param _weiAmount Value in wei to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _weiAmount
    */
    function _getTokenAmount(address _benef, uint256 _weiAmount) private view returns (uint256) {
        uint256 amountToken = _weiAmount * oneEtherValue;
        uint256 tokenBonus;
        if(amountToken >= (1000 * _decimals18) ){
            uint256 amountTokenDiv = amountToken.div(_decimals18);
            tokenBonus = _getTokenBonus(_benef, amountTokenDiv) * _decimals18;
        }
        return amountToken.add(tokenBonus);
    }
    
    
    // get the token bonus by rate
    // for 15k$ you will get 75 000 token
    function _getTokenBonus(address _buyer, uint256 _encx) public view returns(uint256) {
        
        uint256 bonus;
        
        // 200$ - 300K$ => 5%
        if( _encx >= 1000 && _encx < 1500) {
            bonus = _encx.mul(5).div(100);
            return _encx.add(bonus);
        }
        
        // 300$ - 700K$ => 10%
        if( _encx >= 1500 && _encx < 3500) {
            bonus = _encx.mul(10).div(100);
            return _encx.add(bonus);
        }
        
        // 700$ - 15k$ => 15%
        if( _encx >= 3500 && _encx < 75000) {
            bonus = _encx.mul(15).div(100);
            return _encx.add(bonus);
        }
        
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
            token.setVestingPeriod(_buyer, bonus, 0);
            return bonus;
        }
        
        // 200k$ - 500K$ => 32% Vesting 12 month
        if( _encx >= 1000000 && _encx < 2500000) {
            bonus = _encx.mul(32).div(100);
            bonus = _encx.add(bonus);
            token.setVestingPeriod(_buyer, bonus, 1);
            return bonus;
        }
        
        // 500k$ - 1000K$ => 36% Vesting 12 month
        if( _encx >= 1000000 && _encx < 5000000) {
            bonus = _encx.mul(36).div(100);
            bonus = _encx.add(bonus);
            token.setVestingPeriod(_buyer, bonus, 1);
            return bonus;
        }
        
        // > 1000K$ => 40% Vesting 12 month
        if( _encx >= 5000000) {
            bonus = _encx.mul(40).div(100);
            bonus = _encx.add(bonus);
            token.setVestingPeriod(_buyer, bonus, 1);
            return bonus;
        }
        
        
        return _encx;
    }
    
    /**
     * @dev Tranfert wei amount
    */
    function _forwardFunds() private {
        walletCollect.transfer(msg.value);
    }
    
    
    /*
        Change token price
    */
    function setTokenPrice(uint256 _oneEtherValue) public onlyOwner returns(bool){
        oneEtherValue = _oneEtherValue;
        return true;
    }
    
    /*
        Change token price
    */
    function setWalletColect(address _wallet) public onlyOwner returns(bool){
        require(_wallet != address(0));
        walletCollect = _wallet;
        return true;
    }
    
    /*
        Change token price
    */
    function setMinimumWei(uint256 _wei) public onlyOwner returns(bool){
        require(_wei >= 1);
        minimumWei = _decimals18 / _wei;
        return true;
    }
    
    
     /**
     * @dev Deliver tokens to receiver_ after crowdsale ends.
     */
    function withdrawTokensFor(address receiver_) public onlyOwner {
        _withdrawTokensFor(receiver_);
    }


    /**
     * @dev Withdraw tokens for receiver_ after crowdsale ends.
     */
    function _withdrawTokensFor(address receiverAdd) internal {
        require(closed);
        uint256 amount = balances[receiverAdd];
        require(amount > 0);
        balances[receiverAdd] = 0;
        emit TokenDelivered(receiverAdd, amount);
        _deliverTokens(receiverAdd, amount);
    }
    
    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.transfer(_beneficiary, _tokenAmount);
    }
    
    // Callback function
    function () payable external {
        buyTokens(msg.sender);
    }
    
    /**
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary) notCloseICO public payable {

        uint256 weiAmount = msg.value;

        require(_beneficiary != address(0));
        require(weiAmount != 0 && weiAmount >= minimumWei);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(_beneficiary, weiAmount);
        
        // update state
        weiRaised = weiRaised.add(weiAmount);
        
        _processPurchase(_beneficiary, tokens);
        emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);
        
        if(tokenForSale == ENCXRaised) closed = true;
        _forwardFunds();
    }
    
        /**
     * @param _beneficiary Token purchaser
     * @param _tokenAmount Amount of tokens purchased
     */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) notCloseICO internal {
        balances[_beneficiary] = balances[_beneficiary].add(_tokenAmount);
        ENCXRaised = ENCXRaised.add(_tokenAmount);
    }
    
    function close() public onlyOwner { 
        selfdestruct(owner);  // `owner` is the owners address
    }
    
}