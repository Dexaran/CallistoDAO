pragma solidity >=0.8.0;

import "https://github.com/Dexaran/ERC223-token-standard/blob/development/utils/Address.sol";
import "https://github.com/Dexaran/ERC223-token-standard/blob/development/token/ERC223/IERC223Recipient.sol";

/*This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
Basic, standardized Token contract with no "premine". Defines the functions to
check token balances, send tokens, send tokens on behalf of a 3rd party and the
corresponding approval process. Tokens need to be created by a derived
contract (e.g. TokenCreation.sol).

Thank you ConsenSys, this contract originated from:
https://github.com/ConsenSys/Tokens/blob/master/Token_Contracts/contracts/Standard_Token.sol
Which is itself based on the Ethereum standardized contract APIs:
https://github.com/ethereum/wiki/wiki/Standardized_Contract_APIs
*/

// @title Standard Token Contract.

abstract contract TokenInterface {
    mapping (address => uint256) balances;

    // Total amount of tokens
    uint256 public totalSupply;

    // @param _owner The address from which the balance will be retrieved
    // @return The balance
    function balanceOf(address _owner) view virtual public returns (uint256 balance);

    // @notice Send `_amount` tokens to `_to` from `msg.sender`
    // @param _to The address of the recipient
    // @param _amount The amount of tokens to be transferred
    // @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) public virtual returns (bool success);

    // @notice Send `_amount` tokens to `_to` from `msg.sender`
    // @param _to The address of the recipient
    // @param _amount The amount of tokens to be transferred
    // @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount, bytes calldata _data) public virtual returns (bool success);

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event TransferData(bytes _data);
}


abstract contract Token is TokenInterface {

    function balanceOf(address _owner) public view override returns (uint256 balance) {
        return balances[_owner];
    }

/*
    function transfer(address _to, uint256 _amount) public virtual override returns (bool success) {
        if (balances[msg.sender] >= _amount && _amount > 0) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            emit Transfer(msg.sender, _to, _amount);
            return true;
        } else {
           revert("Not enough tokens to transfer");
        }
    }
*/

    
    /**
     * @dev Transfer the specified amount of tokens to the specified address.
     *      This function works the same with the previous one
     *      but doesn't contain `_data` param.
     *      Added due to backwards compatibility reasons.
     *
     * @param _to    Receiver address.
     * @param _amount Amount of tokens that will be transferred.
     */
    function transfer(address _to, uint _amount) public virtual override returns (bool success)
    {
        bytes memory _empty = hex"00000000";
        balances[msg.sender] = balances[msg.sender] - _amount;
        balances[_to] = balances[_to] + _amount;
        if(Address.isContract(_to)) {
            IERC223Recipient(_to).tokenReceived(msg.sender, _amount, _empty);
        }
        emit Transfer(msg.sender, _to, _amount);
        emit TransferData(_empty);
        return true;
    }

    function transfer(address _to, uint256 _amount, bytes calldata _data) public virtual override returns (bool success) {
        // Standard function transfer similar to ERC20 transfer with no _data .
        // Added due to backwards compatibility reasons .
        balances[msg.sender] = balances[msg.sender] - _amount;
        balances[_to] = balances[_to] + _amount;
        if(Address.isContract(_to)) {
            IERC223Recipient(_to).tokenReceived(msg.sender, _amount, _data);
        }
        emit Transfer(msg.sender, _to, _amount);
        emit TransferData(_data);
        return true;
    }
}


/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
Basic account, used by the DAO contract to separately manage both the rewards 
and the extraBalance accounts. 
*/

abstract contract ManagedAccountInterface {
    // The only address with permission to withdraw from this account
    address public owner;
    // If true, only the owner of the account can receive ether from it
    bool public payOwnerOnly;
    // The sum of ether (in wei) which has been sent to this contract
    uint256 public accumulatedInput;

    // @notice Sends `_amount` of wei to _recipient
    // @param _amount The amount of wei to send to `_recipient`
    // @param _recipient The address to receive `_amount` of wei
    // @return True if the send completed
    function payOut(address _recipient, uint256 _amount) virtual public returns (bool);

    event PayOut(address indexed _recipient, uint256 _amount);
}


contract ManagedAccount is ManagedAccountInterface{

    // The constructor sets the owner of the account
    constructor(address _owner, bool _payOwnerOnly) {
        owner = _owner;
        payOwnerOnly = _payOwnerOnly;
    }

    // When the contract receives a transaction without data this is called. 
    // It counts the amount of ether it receives and stores it in 
    // accumulatedInput.
    receive() payable external {
        accumulatedInput += msg.value;
    }

    function payOut(address _recipient, uint256 _amount) override public returns (bool) {
        if (msg.sender != owner || (payOwnerOnly && _recipient != owner))
            revert();

        _recipient.call{ value: _amount};
        emit PayOut(_recipient, _amount);
        return true;
    }
}
/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
 * Token Creation contract, used by the DAO to create its tokens and initialize
 * its ether. Feel free to modify the divisor method to implement different
 * Token Creation parameters
*/


abstract contract TokenCreationInterface {

    // End of token creation, in Unix time
    uint256 public closingTime;
    // Minimum fueling goal of the token creation, denominated in tokens to
    // be created
    uint256 public minTokensToCreate;
    // True if the DAO reached its minimum fueling goal, false otherwise
    bool public isFueled;
    // For DAO splits - if privateCreation is 0, then it is a public token
    // creation, otherwise only the address stored in privateCreation is
    // allowed to create tokens
    address public privateCreation;
    // hold extra ether which has been sent after the DAO token
    // creation rate has increased
    ManagedAccount public extraBalance;
    // tracks the amount of wei given from each contributor (used for refund)
    mapping (address => uint256) weiGiven;

    // @dev Constructor setting the minimum fueling goal and the
    // end of the Token Creation
    // @param _minTokensToCreate Minimum fueling goal in number of
    //        Tokens to be created
    // @param _closingTime Date (in Unix time) of the end of the Token Creation
    // @param _privateCreation Zero means that the creation is public.  A
    // non-zero address represents the only address that can create Tokens
    // (the address can also create Tokens on behalf of other accounts)
    // This is the constructor: it can not be overloaded so it is commented out
    //  function TokenCreation(
        //  uint256 _minTokensTocreate,
        //  uint256 _closingTime,
        //  address _privateCreation
    //  );

    // @notice Create Token with `_tokenHolder` as the initial owner of the Token
    // @param _tokenHolder The address of the Tokens's recipient
    // @return Whether the token creation was successful
    function createTokenProxy(address _tokenHolder) payable virtual public returns (bool success);

    // @notice Refund `msg.sender` in the case the Token Creation did
    // not reach its minimum fueling goal
    function refund() virtual public;

    // @return The divisor used to calculate the token creation rate during
    // the creation phase
    function divisor() virtual view public returns (uint256 _divisor);

    event FuelingToDate(uint256 value);
    event CreatedToken(address indexed to, uint256 amount);
    event Refund(address indexed to, uint256 value);
}


contract TokenCreation is TokenCreationInterface, Token {

    constructor(
        uint256 _minTokensToCreate,
        uint256 _closingTime,
        address _privateCreation) {

        closingTime = _closingTime;
        minTokensToCreate = _minTokensToCreate;
        privateCreation = _privateCreation;
        extraBalance = new ManagedAccount(address(this), true);
    }

    function createTokenProxy(address _tokenHolder) payable override public returns (bool success) {
        if (block.timestamp < closingTime && msg.value > 0
            && (privateCreation == address(0) || privateCreation == msg.sender)) {

            uint256 token = (msg.value * 20) / divisor();
            address(extraBalance).call{value: msg.value - token};
            balances[_tokenHolder] += token;
            totalSupply += token;
            weiGiven[_tokenHolder] += msg.value;
            emit CreatedToken(_tokenHolder, token);
            if (totalSupply >= minTokensToCreate && !isFueled) {
                isFueled = true;
                emit FuelingToDate(totalSupply);
            }
            return true;
        }
        revert();
    }

    function refund() override public {
        if (block.timestamp > closingTime && !isFueled) {
            // Get extraBalance - will only succeed when called for the first time
            if (address(extraBalance).balance >= extraBalance.accumulatedInput())
                extraBalance.payOut(address(this), extraBalance.accumulatedInput());

            // Execute refund
            msg.sender.call{value: weiGiven[msg.sender]};
            emit Refund(msg.sender, weiGiven[msg.sender]);
            totalSupply -= balances[msg.sender];
            balances[msg.sender] = 0;
            weiGiven[msg.sender] = 0;
        }
    }

    function divisor() override view public returns (uint256 _divisor) {
        // The number of (base unit) tokens per wei is calculated
        // as `msg.value` * 20 / `divisor`
        // The fueling period starts with a 1:1 ratio
        if (closingTime - 2 weeks > block.timestamp) {
            return 20;
        // Followed by 10 days with a daily creation rate increase of 5%
        } else if (closingTime - 4 days > block.timestamp) {
            return (20 + (block.timestamp - (closingTime - 2 weeks)) / (1 days));
        // The last 4 days there is a view creation rate ratio of 1:1.5
        } else {
            return 30;
        }
    }
}
/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
Standard smart contract for a Decentralized Autonomous Organization (DAO)
to automate organizational governance and decision-making.
*/


abstract contract DAOInterface {

    // The minimum debate period that a generic proposal can have
    uint256 constant minProposalDebatePeriod = 2 weeks;
    // The minimum debate period that a split proposal can have
    uint256 constant minSplitDebatePeriod = 1 weeks;
    // Period of days inside which it's possible to execute a DAO split
    uint256 constant splitExecutionPeriod = 27 days;
    // Period of time after which the minimum Quorum is halved
    uint256 constant quorumHalvingPeriod = 25 weeks;
    // Period after which a proposal is closed
    // (used in the case `executeProposal` fails because it throws)
    uint256 executeProposalPeriod = 10 days;
    // Denotes the maximum proposal deposit that can be given. It is given as
    // a fraction of total Ether spent plus balance of the DAO
    uint256 maxDepositDivisor = 100;

    // Proposals to spend the DAO's ether or to choose a new Curator
    Proposal[] public proposals;
    // The quorum needed for each proposal is partially calculated by
    // totalSupply / minQuorumDivisor
    uint256 public minQuorumDivisor;
    // The unix time of the last time quorum was reached on a proposal
    uint256  public lastTimeMinQuorumMet;

    // Address of the curator
    //address public curator;

    // Callisto DAO: multiple curators allowed.
    //mapping (address => bool) public curator;

    // Callisto DAO v2: curators are weighted against each other.
    //                  One curator can have more voting power on curatorOnly() type of proposals than other curators.
    mapping (address => uint256) public curatorWeight;


    // The whitelist: List of addresses the DAO is allowed to send ether to
    mapping (address => bool) public allowedRecipients;

    // Tracks the addresses that own Reward Tokens. Those addresses can only be
    // DAOs that have split from the original DAO. Conceptually, Reward Tokens
    // represent the proportion of the rewards that the DAO has the right to
    // receive. These Reward Tokens are generated when the DAO spends ether.
    mapping (address => uint) public rewardToken;
    // Total supply of rewardToken
    uint256 public totalRewardToken;

    // Total supply of rewardToken
    uint256 public totalCuratorWeights;

    // The account used to manage the rewards which are to be distributed to the
    // DAO Token Holders of this DAO
    ManagedAccount public rewardAccount;

    // The account used to manage the rewards which are to be distributed to
    // any DAO that holds Reward Tokens
    ManagedAccount public DAOrewardAccount;

    // Amount of rewards (in wei) already paid out to a certain DAO
    mapping (address => uint) public DAOpaidOut;

    // Amount of rewards (in wei) already paid out to a certain address
    mapping (address => uint) public paidOut;
    // Map of addresses blocked during a vote (not allowed to transfer DAO
    // tokens). The address points to the proposal ID.
    mapping (address => uint) public blocked;

    // The minimum deposit (in wei) required to submit any proposal that is not
    // requesting a new Curator (no deposit is required for splits)
    uint256 public proposalDeposit;

    // the accumulated sum of all current proposal deposits
    uint256 sumOfProposalDeposits;

    // A proposal with `newCurator == false` represents a transaction
    // to be issued by this DAO
    // A proposal with `newCurator == true` represents a modification of curators weight
    // a new curator can be assigned by increasing curatorWeight of an existing account to above zero.
    struct Proposal {
        // The address where the `amount` will go to if the proposal is accepted
        // or if `newCurator` is true, the proposed Curator of
        // the new DAO).
        address recipient;
        // The amount to transfer to `recipient` if the proposal is accepted.
        // If the proposal is a modification of curator weight then amount is
        // a new weight of the `recipient` curator.
        uint256 amount;
        // A plain text description of the proposal
        string description;
        // A unix timestamp, denoting the end of the voting period
        uint256 votingDeadline;
        // True if the proposal's votes have yet to be counted, otherwise False
        bool open;
        // True if quorum has been reached, the votes have been counted, and
        // the majority said yes
        bool proposalPassed;
        // A hash to check validity of a proposal
        bytes32 proposalHash;
        // Deposit in wei the creator added when submitting their proposal. It
        // is taken from the msg.value of a newProposal call.
        uint256 proposalDeposit;
        // True if this proposal is to assign a new Curator
        bool newCurator;
        // Number of Tokens in favor of the proposal
        uint256 yea;
        // Number of Tokens opposed to the proposal
        uint256 nay;
        // Number of Curators vetoing the proposal
        uint256 veto;
        // Simple mapping to check if a shareholder has voted for it
        mapping (address => bool) votedYes;
        // Simple mapping to check if a shareholder has voted against it
        mapping (address => bool) votedNo;
        // Simple mapping to check if a curator has vetoed a proposal
        mapping (address => bool) votedVeto;
        // Address of the shareholder who created the proposal
        address creator;
    }

    // Callisto DAO: new structure for accepting tokens as payments.
    /* Just a template! Further clarification required.
    struct PaymentMethod
    {
        bool    isAccepted;
        uint256 depositFee;
    }
    */

    // @dev Constructor setting the Curator and the address
    // for the contract able to create another DAO as well as the parameters
    // for the DAO Token Creation
    // @param _curator The Curator
    // @param _daoCreator The contract able to (re)create this DAO
    // @param _proposalDeposit The deposit to be paid for a regular proposal
    // @param _minTokensToCreate Minimum required wei-equivalent tokens
    //        to be created for a successful DAO Token Creation
    // @param _closingTime Date (in Unix time) of the end of the DAO Token Creation
    // @param _privateCreation If zero the DAO Token Creation is open to public, a
    // non-zero address means that the DAO Token Creation is only for the address
    // This is the constructor: it can not be overloaded so it is commented out
    //  function DAO(
        //  address _curator,
        //  DAO_Creator _daoCreator,
        //  uint256 _proposalDeposit,
        //  uint256 _minTokensToCreate,
        //  uint256 _closingTime,
        //  address _privateCreation
    //  );

    // @notice Create Token with `msg.sender` as the beneficiary
    // @return Whether the token creation was successful
    receive() virtual external payable;


    // @dev This function is used to send ether back
    // to the DAO, it can also be used to receive payments that should not be
    // counted as rewards (donations, grants, etc.)
    // @return Whether the DAO received the ether successfully
    function receiveEther() payable virtual public returns(bool);

    // @notice `msg.sender` creates a proposal to send `_amount` Wei to
    // `_recipient` with the transaction data `_transactionData`. If
    // `_newCurator` is true, then this is a proposal that splits the
    // DAO and sets `_recipient` as the new DAO's Curator.
    // @param _recipient Address of the recipient of the proposed transaction
    // @param _amount Amount of wei to be sent with the proposed transaction
    // @param _description String describing the proposal
    // @param _transactionData Data of the proposed transaction
    // @param _debatingPeriod Time used for debating a proposal, at least 2
    // weeks for a regular proposal, 10 days for new Curator proposal
    // @param _newCurator Bool defining whether this proposal is about
    // a new Curator or not
    // @return The proposal ID. Needed for voting on the proposal
    function newProposal(
        address _recipient,
        uint256 _amount,
        string memory _description,
        bytes memory _transactionData,
        uint256 _debatingPeriod
    ) payable public virtual returns (uint256 _proposalID)
    {
        // EMPTY
    }

    // @notice Check that the proposal with the ID `_proposalID` matches the
    // transaction which sends `_amount` with data `_transactionData`
    // to `_recipient`
    // @param _proposalID The proposal ID
    // @param _recipient The recipient of the proposed transaction
    // @param _amount The amount of wei to be sent in the proposed transaction
    // @param _transactionData The data of the proposed transaction
    // @return Whether the proposal ID matches the transaction data or not
    function checkProposalCode(
        uint256 _proposalID,
        address _recipient,
        uint256 _amount,
        bytes memory _transactionData
    ) view public virtual returns (bool _codeChecksOut);

    // @notice Vote on proposal `_proposalID` with `_supportsProposal`
    // @param _proposalID The proposal ID
    // @param _supportsProposal Yes/No - support of the proposal
    // @return The vote ID.
    function vote(
        uint256 _proposalID,
        bool _supportsProposal
    ) public virtual returns (uint256 _voteID)
    {
        // EMPTY
    }

    // @notice Checks whether proposal `_proposalID` with transaction data
    // `_transactionData` has been voted for or rejected, and executes the
    // transaction in the case it has been voted for.
    // @param _proposalID The proposal ID
    // @param _transactionData The data of the proposed transaction
    // @return Whether the proposed transaction has been executed or not
    function executeProposal(
        uint256 _proposalID,
        bytes memory _transactionData
    ) public virtual returns (bool _success);


    // @notice Add a new possible recipient `_recipient` to the whitelist so
    // that the DAO can send transactions to them (using proposals)
    // @param _recipient New recipient address
    // @dev Can only be called by the current Curator
    // @return Whether successful or not
    function changeAllowedRecipients(address _recipient, bool _allowed) external virtual returns (bool _success);


    // @notice Change the minimum deposit required to submit a proposal
    // @param _proposalDeposit The new proposal deposit
    // @dev Can only be called by this DAO (through proposals with the
    // recipient being this DAO itself)
    function changeProposalDeposit(uint256 _proposalDeposit) external virtual;

    // @notice Move rewards from the DAORewards managed account
    // @param _toMembers If true rewards are moved to the actual reward account
    //                   for the DAO. If not then it's moved to the DAO itself
    // @return Whether the call was successful
    function retrieveDAOReward(bool _toMembers) external virtual returns (bool _success);

    // @notice Get my portion of the reward that was sent to `rewardAccount`
    // @return Whether the call was successful
    function getMyReward() public virtual returns(bool _success);

    // @notice Withdraw `_account`'s portion of the reward from `rewardAccount`
    // to `_account`'s balance
    // @return Whether the call was successful
    function withdrawRewardFor(address _account) internal virtual returns (bool _success);

    // @notice Send `_amount` tokens to `_to` from `msg.sender`. Prior to this
    // getMyReward() is called.
    // @param _to The address of the recipient
    // @param _amount The amount of tokens to be transfered
    // @return Whether the transfer was successful or not
    function transferWithoutReward(address _to, uint256 _amount) public virtual returns (bool success);

    // @notice Doubles the 'minQuorumDivisor' in the case quorum has not been
    // achieved in 52 weeks
    // @return Whether the change was successful or not
    function halveMinQuorum() public virtual returns (bool _success);

    // @return total number of proposals ever created
    function numberOfProposals() public view virtual returns (uint256 _numberOfProposals);

    // @param _account The address of the account which is checked.
    // @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function isBlocked(address _account) internal virtual returns (bool);

    // @notice If the caller is blocked by a proposal whose voting deadline
    // has exprired then unblock him.
    // @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function unblockMe() public virtual returns (bool);

    event ProposalAdded(
        uint256 indexed proposalID,
        address recipient,
        uint256 amount,
        bool newCurator,
        string description
    );
    event Voted(uint256 indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint256 indexed proposalID, bool result, uint256 quorum);
    //event NewCurator(address indexed _newCurator);

    event CuratorModification(address indexed curator, uint256 new_weight);
    event AllowedRecipientChanged(address indexed _recipient, bool _allowed);
}

// The DAO contract itself
contract DAO is DAOInterface, Token, TokenCreation {

    bool public setupMode = true;
    address public creator = msg.sender;

    // Further clarification required.
    // mapping (address => PaymentMethod) public payment_methods;

    modifier onlySetupMode
    {
        require(setupMode, "This function is only available in setup mode.");
        require(msg.sender == creator, "This function can be called by the creator of the contract during Setup Mode only.");
        _;
    }

    modifier onlyCurators
    {
        require(isCurator(msg.sender), "This function is only available to curators of the DAO.");
        _;
    }

    function mint(address _receiver, uint256 _quantity) public 
    {

    }

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyTokenholders {
        if (balanceOf(msg.sender) == 0) revert();
            _;
    }

    function isCurator(address _who) public view returns (bool)
    {
        return curatorWeight[_who] > 0;
    }

    // Callisto DAO: curators will not be assigned upon deployment.
    //               Instead curators will be manually chosen by the deployer of the DAO after deployment.
    constructor(
        //address _curator,
        uint256 _proposalDeposit,
        uint256 _minTokensToCreate,
        uint256 _closingTime,
        address _privateCreation
    ) TokenCreation(_minTokensToCreate, _closingTime, _privateCreation) {

        //curator[_curator] = true;
        proposalDeposit = _proposalDeposit;
        rewardAccount = new ManagedAccount(address(this), false);
        DAOrewardAccount = new ManagedAccount(address(this), false);
        if (address(rewardAccount) == address(0))
            revert();
        if (address(DAOrewardAccount) == address(0))
            revert();
        lastTimeMinQuorumMet = block.timestamp;
        minQuorumDivisor = 5; // sets the minimal quorum to 20%

        //proposals.length = 1; // avoids a proposal with ID 0 because it is used
        proposals.push(); // Pushes empty proposal to ID 0

        allowedRecipients[address(this)] = true;
        allowedRecipients[msg.sender] = true;
    }

    receive() override external payable {
        receiveEther();
    }


    function receiveEther() payable public override returns (bool) {
        return true;
    }




    function newProposal(
        address _recipient,
        uint256 _amount,
        string memory _description,
        bytes memory _transactionData,
        uint256 _debatingPeriod
    ) payable public override returns (uint256 _proposalID) {

        // Sanity check
        if (!isRecipientAllowed(_recipient) || (_debatingPeriod <  minProposalDebatePeriod)) {
            revert();
        }

        if (_debatingPeriod > 8 weeks)
            revert();

        if (block.timestamp < closingTime || (msg.value < proposalDeposit)) 
        {
            revert();
        }

        // to prevent a 51% attacker to convert the ether into deposit
        if (msg.sender == address(this))
        {
            revert();
        }

        _proposalID = proposals.length + 1;
        Proposal storage p = proposals[_proposalID];
        p.recipient = _recipient;
        p.amount = _amount;
        p.description = _description;
        p.proposalHash = keccak256(abi.encodePacked(_recipient, _amount, _transactionData));
        p.votingDeadline = block.timestamp + _debatingPeriod;
        p.open = true;
        //p.proposalPassed = False; // that's default
        //if (_newCurator)                  // DEPRECATED EXPRESSION
        //    p.splitData.length++;
        p.creator = msg.sender;
        p.proposalDeposit = msg.value;

        sumOfProposalDeposits += msg.value;

        emit ProposalAdded(
            _proposalID,
            _recipient,
            _amount,
            false,
            _description
        );
    }


    function checkProposalCode(
        uint256 _proposalID,
        address _recipient,
        uint256 _amount,
        bytes memory _transactionData
    ) public view override returns (bool _codeChecksOut) {
        Proposal storage p = proposals[_proposalID];
        return p.proposalHash == keccak256(abi.encodePacked(_recipient, _amount, _transactionData));
    }

    function voteVeto(uint256 _proposalID) public
    {
        require(isCurator(msg.sender), "Callisto DAO: Only curator can VETO a proposal.");
        Proposal storage p = proposals[_proposalID];
        require(!p.votedVeto[msg.sender], "Callisto DAO: This address already VETOed a proposal.");
        require(!p.newCurator, "Callisto DAO: Can't VETO a modification of curator.");

        p.veto++;
        p.votedVeto[msg.sender] = true;
    }

    function checkVetoCriteria(uint256 _proposalID) public view returns (bool _passed)
    {
        Proposal storage p = proposals[_proposalID];
        if (p.veto != 0)
        {
            return false;
        }
        else
        {
            return true;
        }
    }


    function vote(
        uint256 _proposalID,
        bool _supportsProposal
    ) onlyTokenholders public override returns (uint256 _voteID) {

        Proposal storage p = proposals[_proposalID];
        require(!p.newCurator, "Callisto DAO: curator changes are voted through 'voteCurator' function.");

        if (p.votedYes[msg.sender]
            || p.votedNo[msg.sender]
            || block.timestamp >= p.votingDeadline) {

            revert();
        }

        if (_supportsProposal) {
            p.yea += balances[msg.sender];
            p.votedYes[msg.sender] = true;
        } else {
            p.nay += balances[msg.sender];
            p.votedNo[msg.sender] = true;
        }

        if (blocked[msg.sender] == 0) {
            blocked[msg.sender] = _proposalID;
        } else if (p.votingDeadline > proposals[blocked[msg.sender]].votingDeadline) {
            // this proposal's voting deadline is further into the future than
            // the proposal that blocks the sender so make it the blocker
            blocked[msg.sender] = _proposalID;
        }

        emit Voted(_proposalID, _supportsProposal, msg.sender);
    }


    function executeProposal(
        uint256 _proposalID,
        bytes memory _transactionData
    ) public override returns (bool _success) {

        Proposal storage p = proposals[_proposalID];

        uint256 quorum = p.yea + p.nay;

        // *****************************************************************
        // Funding proposal.
        // *****************************************************************

        if(!p.newCurator)
        {
                    
        // Callisto DAO: Implement VETO feature with corresponding VETO criteria check.
        // NOTE: VETO criteria is subject to change in future versions.
        if(!checkVetoCriteria(_proposalID))
        {
            closeProposal(_proposalID);
        }

        uint256 waitPeriod = p.newCurator
            ? splitExecutionPeriod
            : executeProposalPeriod;


        // If we are over deadline and waiting period, assert proposal is closed
        if (p.open && block.timestamp > p.votingDeadline + waitPeriod) {
            closeProposal(_proposalID);
            return true; // DEPRECATED EXPRESSION REWRITTEN
        }

        // Check if the proposal can be executed
        if (block.timestamp < p.votingDeadline  // has the voting deadline arrived?
            // Have the votes been counted?
            || !p.open
            // Does the transaction code match the proposal?
            || p.proposalHash != keccak256(abi.encodePacked(p.recipient, p.amount, _transactionData))) {

            revert();
        }

        // If the curator removed the recipient from the whitelist, close the proposal
        // in order to free the deposit and allow unblocking of voters
        if (!isRecipientAllowed(p.recipient)) {
            closeProposal(_proposalID);
            payable(p.creator).transfer(p.proposalDeposit);
            return true; // DEPRECATED EXPRESSION REWRITTEN
        }

        bool proposalCheck = true;

        if (p.amount > actualBalance())
            proposalCheck = false;

        if (quorum >= minQuorum(p.amount)) {
            //if (!p.creator.send(p.proposalDeposit))
            //    revert();

            payable(p.creator).transfer(p.proposalDeposit);

            lastTimeMinQuorumMet = block.timestamp;
            // set the minQuorum to 20% again, in the case it has been reached
            if (quorum > totalSupply / 5)
                minQuorumDivisor = 5;
        }

        // Execute result
        if (quorum >= minQuorum(p.amount) && p.yea > p.nay && proposalCheck) {
            //if (!p.recipient.call.value(p.amount)(_transactionData))
            //    revert();

            (bool __success, bytes memory data) = p.recipient.call{value:p.amount}(_transactionData);
            require(__success, "Callisto DAO: Subcall failure.");

            p.proposalPassed = true;
            _success = true;

            // only create reward tokens when ether is not sent to the DAO itself and
            // related addresses. Proxy addresses should be forbidden by the curator.
            if (p.recipient != address(this) && p.recipient != address(rewardAccount)
                && p.recipient != address(DAOrewardAccount)
                && p.recipient != address(extraBalance)
                // && p.recipient != address(curator)) 
                // Callisto DAO: check curator in a new way.
                && !isCurator(p.recipient))
                {

                rewardToken[address(this)] += p.amount;
                totalRewardToken += p.amount;
            }
        }
        }

        // *****************************************************************
        // Curator modification proposal.
        // *****************************************************************

        else
        {
            uint256 waitPeriod = executeProposalPeriod;
            // If we are over deadline and waiting period, assert proposal is closed
            if (p.open && block.timestamp > p.votingDeadline + waitPeriod) {
                closeProposal(_proposalID);
                return true; // DEPRECATED EXPRESSION REWRITTEN
            }
            
            // Check if the proposal can be executed
            if (block.timestamp < p.votingDeadline  // has the voting deadline arrived?
                // Have the votes been counted?
                || !p.open
                // Does the transaction code match the proposal?
                || p.proposalHash != keccak256(abi.encodePacked(p.recipient, p.amount, _transactionData))) {

                revert();
            }

            if(p.yea > totalCuratorWeights / 2)
            {
                // Curator modification passed.
                uint256 old_weight = curatorWeight[p.recipient];
                curatorWeight[p.recipient] = p.amount;
                _success = true;

                if(old_weight > p.amount)
                {
                    // The curators weight was decreased.
                    totalCuratorWeights -= (old_weight - p.amount);
                }
                else
                {
                    // The curators weight was increased.
                    totalCuratorWeights += (p.amount - old_weight);
                }
                emit CuratorModification(p.recipient, p.amount);
            }
            /*
            else 
            {
                // Curator modification have NOT passed.
                // closeProposal(_proposalID);  // Auto closes after previous IF
            }
            */
        }

        // Initiate event
        emit ProposalTallied(_proposalID, _success, quorum);
        closeProposal(_proposalID);
    }


    function closeProposal(uint256 _proposalID) internal {
        Proposal storage p = proposals[_proposalID];
        if (p.open)
            sumOfProposalDeposits -= p.proposalDeposit;
        p.open = false;
    }

    function retrieveDAOReward(bool _toMembers) external override returns (bool _success) 
    {
        DAO dao = DAO(payable(msg.sender));

        if ((rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
            totalRewardToken < DAOpaidOut[msg.sender])
            revert();

        uint256 reward =
            (rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
            totalRewardToken - DAOpaidOut[msg.sender];
        if(_toMembers) {
            if (!DAOrewardAccount.payOut(address(dao.rewardAccount()), reward))
                revert();
            }
        else {
            if (!DAOrewardAccount.payOut(address(dao), reward))
                revert();
        }
        DAOpaidOut[msg.sender] += reward;
        return true;
    }

    function getMyReward()  public override returns (bool _success) {
        return withdrawRewardFor(msg.sender);
    }


    function withdrawRewardFor(address _account)  internal override returns (bool _success) {
        if ((balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply < paidOut[_account])
            revert();

        uint256 reward =
            (balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply - paidOut[_account];
        if (!rewardAccount.payOut(_account, reward))
            revert();
        paidOut[_account] += reward;
        return true;
    }


    function transfer(address _to, uint256 _value) public override returns (bool success) {
        if (isFueled
            && block.timestamp > closingTime
            && !isBlocked(msg.sender)
            && transferPaidOut(msg.sender, _to, _value)
            && super.transfer(_to, _value)) {

            return true;
        } else {
            revert();
        }
    }


    function transfer(address _to, uint256 _value, bytes calldata _data) public override returns (bool success) {
        if (isFueled
            && block.timestamp > closingTime
            && !isBlocked(msg.sender)
            && transferPaidOut(msg.sender, _to, _value)
            && super.transfer(_to, _value)) {

            return true;
        } else {
            revert();
        }
    }


    function transferWithoutReward(address _to, uint256 _value) public override returns (bool success) {
        if (!getMyReward())
            revert();
        return transfer(_to, _value);
    }

    function transferPaidOut(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool success) {

        uint256 __transferPaidOut = paidOut[_from] * _value / balanceOf(_from);
        if (__transferPaidOut > paidOut[_from])
            revert();
        paidOut[_from] -= __transferPaidOut;
        paidOut[_to] += __transferPaidOut;
        return true;
    }


    function changeProposalDeposit(uint256 _proposalDeposit)  external override {
        if (msg.sender != address(this) || _proposalDeposit > (actualBalance() + rewardToken[address(this)])
            / maxDepositDivisor) {

            revert();
        }
        proposalDeposit = _proposalDeposit;
    }


    function changeAllowedRecipients(address _recipient, bool _allowed)  external override returns (bool _success) {
        //if (msg.sender != curator)
        //    revert();
        if (!isCurator(msg.sender))
            revert();
        allowedRecipients[_recipient] = _allowed;
        emit AllowedRecipientChanged(_recipient, _allowed);
        return true;
    }


    function isRecipientAllowed(address _recipient) internal view returns (bool _isAllowed) {
        if (allowedRecipients[_recipient]
            || (_recipient == address(extraBalance)
                // only allowed when at least the amount held in the
                // extraBalance account has been spent from the DAO
                && totalRewardToken > extraBalance.accumulatedInput()))
            return true;
        else
            return false;
    }

    function actualBalance() public view returns (uint256 _actualBalance) {
        return address(this).balance - sumOfProposalDeposits;
    }


    function minQuorum(uint256 _value) internal view returns (uint256 _minQuorum) {
        // minimum of 20% and maximum of 53.33%
        return totalSupply / minQuorumDivisor +
            (_value * totalSupply) / (3 * (actualBalance() + rewardToken[address(this)]));
    }


    function halveMinQuorum() public override returns (bool _success) {
        // this can only be called after `quorumHalvingPeriod` has passed or at anytime
        // by the curator with a delay of at least `minProposalDebatePeriod` between the calls
        // Callisto DAO: check curator in a new way.
        if ((lastTimeMinQuorumMet < (block.timestamp - quorumHalvingPeriod) || isCurator(msg.sender))
            && lastTimeMinQuorumMet < (block.timestamp - minProposalDebatePeriod)) {
            lastTimeMinQuorumMet = block.timestamp;
            minQuorumDivisor *= 2;
            return true;
        } else {
            return false;
        }
    }

    function numberOfProposals() public view override returns (uint256 _numberOfProposals) {
        // Don't count index 0. It's used by isBlocked() and exists from start
        return proposals.length - 1;
    }

    function isBlocked(address _account) internal override returns (bool) {
        if (blocked[_account] == 0)
            return false;
        Proposal storage p = proposals[blocked[_account]];
        if (block.timestamp > p.votingDeadline) {
            blocked[_account] = 0;
            return false;
        } else {
            return true;
        }
    }

    function unblockMe() public override returns (bool) {
        return isBlocked(msg.sender);
    }

    // Proposal to modify curators weight,
    // this can be also used to elect new curators (change their weight from 0 to higher values)
    function changeCuratorWeight(
        address _curator,
        string memory _description,
        bytes memory _transactionData,
        uint256 _debatingPeriod,
        uint256 _weight
        ) public onlyCurators {
        
        require(_weight != curatorWeight[_curator], "Callisto DAO: proposal suggests no changes.");

        uint256 _proposalID = proposals.length + 1;
        Proposal storage p = proposals[_proposalID];
        p.recipient = _curator;
        p.amount = _weight;
        p.description = _description;
        p.proposalHash = keccak256(abi.encodePacked(_curator, _weight, _transactionData));
        p.votingDeadline = block.timestamp + _debatingPeriod;
        p.open = true;
        //p.proposalPassed = False; // that's default
        //if (_curator)                  // DEPRECATED EXPRESSION
        //    p.splitData.length++;
        p.creator = msg.sender;
        p.proposalDeposit = 0;
        p.newCurator = true;

        emit ProposalAdded(
            _proposalID,
            _curator,
            _weight,
            true,
            _description
        );
    }

    function voteCurator(uint256 _proposalID, bool _supports) public onlyCurators
    {
        Proposal storage p = proposals[_proposalID];
        require(p.newCurator, "Callisto DAO: funding proposals are voted through 'vote()' function.");
        require(!p.votedYes[msg.sender], "Callisto DAO: msg.sender already voted on this proposal.");
        
        p.yea += curatorWeight[msg.sender];
        p.votedYes[msg.sender] = true;
    }

    function SETUP_addCurator(address _curator, uint256 _weight) external onlySetupMode
    {
        curatorWeight[_curator] = _weight;
    }


    /* Just a template for now. Multicurrency DAO is not yet implemented.
    // Further clarifications required.
    function addPaymentMethod(address _token, uint256 _proposalFeeMin) public onlyCurators
    {

    }
    */
}
