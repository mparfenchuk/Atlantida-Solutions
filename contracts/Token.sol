pragma solidity ^0.4.16;

interface Owned {
    function getOwner() constant external returns (address contractOwner);
}

interface Citizens {
    function getCitizen(address _citizen) constant external returns(uint citizenId);
}

contract Token {
    
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 0;
    uint256 public totalSupply;
    uint256 public sellPrice;
    uint256 public buyPrice;
    Owned public sharesOwnedAddress;
    Citizens public sharesCitizensAddress;

    mapping (address => bool) public frozenAccount;
    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    
    modifier onlyOwner {
        require(msg.sender == sharesOwnedAddress.getOwner());
        _;
    }
    
    modifier isCitizen {
        require(sharesCitizensAddress.getCitizen(msg.sender) != 0);
        _;
    }
    
    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function Token(
        Owned ownedAddress, 
        Citizens citizensAddress,
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        sharesOwnedAddress = Owned(ownedAddress);
        sharesCitizensAddress = Citizens(citizensAddress);
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }

    /** 
     * Internal transfer, only can be called by this contract 
     */
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0                                 // Prevent transfer to 0x0 address. Use burn() instead
            && balanceOf[_from] >= _value                   // Check if the sender has enough
            && balanceOf[_to] + _value > balanceOf[_to]     // Check for overflows
            && !frozenAccount[_from]                        // Check if sender is frozen
            && !frozenAccount[_to]);                        // Check if recipient is frozen  
        balanceOf[_from] -= _value;                         // Subtract from the sender
        balanceOf[_to] += _value;                           // Add the same to the recipient
        Transfer(_from, _to, _value);
    }
    
    function getBalanceOf(address _owner) constant public 
        returns(uint256 balance){
        uint256 ownerBalance = balanceOf[_owner];
        return ownerBalance;
    }
    
    /**
     * @notice Create `mintedAmount` tokens and send it to `target`
     * @param target Address to receive the tokens
     * @param mintedAmount the amount of tokens it will receive
     */
    function mintToken(address target, uint256 mintedAmount) onlyOwner public {
        require(sharesCitizensAddress.getCitizen(target) != 0);
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, this, mintedAmount);
        Transfer(this, target, mintedAmount);
    }

    /**
     * @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) onlyOwner public {
        require(sharesCitizensAddress.getCitizen(target) != 0);
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }

    /**
     * @notice Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
     * @param newSellPrice Price the users can sell to the contract
     */
    function setPrices(uint256 newSellPrice) onlyOwner public {
        sellPrice = newSellPrice;
        buyPrice = sellPrice + sellPrice / 5;
    }

    /** 
     * @notice Buy tokens from contract by sending ether
     */
    function buy() payable isCitizen public {
        require(balanceOf[msg.sender] < 1
            && msg.value == buyPrice);
        uint commission = buyPrice - sellPrice;
        _transfer(sharesOwnedAddress.getOwner(), msg.sender, 1);              // makes the transfers
        sharesOwnedAddress.getOwner().transfer(commission);
    }

    /** 
     * @notice Sell `amount` tokens to contract
     */
    function sell() isCitizen public {
		require(balanceOf[msg.sender] == 1
		    && this.balance >= sellPrice);        // checks if the contract has enough ether to buy
        _transfer(msg.sender, sharesOwnedAddress.getOwner(), 1);    // makes the transfers
        msg.sender.transfer(sellPrice);          // sends ether to the seller. It's important to do this last to avoid recursion attacks
    }
    
}