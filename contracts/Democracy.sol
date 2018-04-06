pragma solidity ^0.4.16;

interface Token {
    function getBalanceOf(address _owner) constant external returns (uint256 balance);
}

interface Owned {
    function getOwner() constant external returns (address contractOwner);
}

interface Citizens {
    function getCitizen(address _citizen) constant external returns(uint citizenId);
}

contract Democracy {

    Proposal[] public proposals;
    uint public numProposals;
    uint public amountRaised;
    Token public sharesTokenAddress;
    Owned public sharesOwnedAddress;
    Citizens public sharesCitizensAddress;
    
    mapping(address => uint256) public balanceOf;
    
    event ProposalAdded(uint proposalID, address recipient, uint minimumVotes, uint debatingInMinutes, uint amount, string description);
    event Voted(uint proposalID, bool position, address voter);
    event ProposalTallied(uint proposalID, uint result, uint quorum, bool active);
    event ChangeOfRules(uint newDebatingPeriodInMinutes, address newSharesTokenAddress);
    event FundTransfer(address backer, uint amount);

    struct Proposal {
        address recipient;
        bool executed;
        string description;
        bytes32 proposalHash;
        uint votingDeadline;
        uint amount;
        uint numberOfVotes;
        uint minimumQuorum;
        uint yes;
        uint no;
        uint debatingPeriodInMinutes;
        Vote[] votes;
        mapping (address => bool) voted;
    }

    struct Vote {
        bool inSupport;
        address voter;
    }

    modifier onlyShareholders {
        require(sharesTokenAddress.getBalanceOf(msg.sender) > 0);
        _;
    }
    
    modifier onlyInBudget {
        if (msg.sender != sharesOwnedAddress.getOwner()){
            require(balanceOf[msg.sender] > 0);
        }
        _;
    }
    
    modifier onlyOwner {
        require(msg.sender == sharesOwnedAddress.getOwner());
        _;
    }
    
    modifier isCitizen {
        require(sharesCitizensAddress.getCitizen(msg.sender) != 0);
        _;
    }
    
    /**
     * Constructor function
     *
     * First time setup
     */
    function Democracy(Token sharesAddress, Owned ownedAddress, Citizens citizensAddress) public {
        sharesTokenAddress = Token(sharesAddress);
        sharesOwnedAddress = Owned(ownedAddress);
        sharesCitizensAddress = Citizens(citizensAddress);
        newProposal(0,0,0,0,"","");
        numProposals = 0;
    }
    
    function pay() payable isCitizen public {
        uint amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        FundTransfer(msg.sender, amount);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send, in wei
     * @param jobDescription Description of job
     * @param transactionBytecode bytecode of transaction
     */
    function newProposal(
            address beneficiary,
            uint minimumVotes,
            uint debatingInMinutes,
            uint weiAmount,
            string jobDescription,
            bytes transactionBytecode) 
        onlyShareholders onlyInBudget public returns (uint proposalId){
            
        proposalId = proposals.length++;
        Proposal storage p = proposals[proposalId];
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.description = jobDescription;
        p.proposalHash = keccak256(beneficiary, weiAmount, transactionBytecode);
        p.votingDeadline = now + debatingInMinutes * 1 minutes;
        p.executed = false;
        p.numberOfVotes = 0;
        p.yes = 0;
        p.no = 0;
        p.minimumQuorum = minimumVotes;
        p.debatingPeriodInMinutes = debatingInMinutes;
        numProposals += 1;
        ProposalAdded(proposalId, beneficiary, minimumVotes, debatingInMinutes, weiAmount, jobDescription);
        
        return proposalId;
    }

    /**
     * Check if a proposal code matches
     *
     * @param proposalNumber ID number of the proposal to query
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send
     * @param transactionBytecode bytecode of transaction
     */
    function checkProposalCode(
            uint proposalNumber,
            address beneficiary,
            uint weiAmount,
            bytes transactionBytecode)
        isCitizen constant public returns (bool codeChecksOut){
            
        Proposal storage p = proposals[proposalNumber];
        return p.proposalHash == keccak256(beneficiary, weiAmount, transactionBytecode);
    }

    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalNumber`
     *
     * @param proposalNumber number of proposal
     * @param supportsProposal either in favor or against it
     */
    function vote(
            uint proposalNumber,
            bool supportsProposal)
        onlyShareholders onlyInBudget public returns (uint voteId){
            
        Proposal storage p = proposals[proposalNumber];
        require(p.voted[msg.sender] != true
            && now < p.votingDeadline);

        voteId = p.votes.length++;
        p.votes[voteId] = Vote({inSupport: supportsProposal, voter: msg.sender});
        p.voted[msg.sender] = true;
        p.numberOfVotes = voteId +1;
        if (supportsProposal){
            p.yes += 1;
        } else {
            p.no += 1;
        }
        Voted(proposalNumber, supportsProposal, msg.sender);
        
        return voteId;
    }
    
    function checkProposalVoter(uint proposalId, address voter) public constant returns (bool voted){
        return proposals[proposalId].voted[voter];
    }
    
    function checkProposalDeadline(uint proposalId) public constant returns (bool isDeadlineOver){
        if (now > proposals[proposalId].votingDeadline){
            return true;
        } else {
            return false;
        }
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalNumber` and execute it if approved
     *
     * @param proposalNumber proposal number
     * @param transactionBytecode optional: if the transaction contained a bytecode, you need to send it
     */
    function executeProposal(uint proposalNumber, bytes transactionBytecode) onlyShareholders onlyInBudget public {
        Proposal storage p = proposals[proposalNumber];

        require(now > p.votingDeadline                                             // If it is past the voting deadline
            && !p.executed                                                          // and it has not already been executed
            && p.proposalHash == keccak256(p.recipient, p.amount, transactionBytecode)
            && p.numberOfVotes >= p.minimumQuorum); // and the supplied code matches the proposal...

        if (p.yes > p.no ) {
            // Proposal passed; execute the transaction

            p.executed = true;
            if(p.recipient != address(this)){
                _safeWithdrawal(p.recipient, p.amount, transactionBytecode);
            }
            //require(p.recipient.call.value(p.amount)(transactionBytecode));
        }

        // Fire Events
        ProposalTallied(proposalNumber, p.yes - p.no, p.numberOfVotes, p.executed);
    }
    
    /**
     * Withdraw the funds
     *
     * Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the beneficiary. If goal was not reached, each contributor can withdraw
     * the amount they contributed.
     */
    function _safeWithdrawal(address _beneficiary, uint _value, bytes transactionBytecode) internal {
        require(this.balance >= _value);
        amountRaised -= _value;
        require(_beneficiary.call.value(_value)(transactionBytecode));
        //_beneficiary.transfer(_value);
        FundTransfer(_beneficiary, _value);
    }
}