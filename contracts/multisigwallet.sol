pragma solidity ^0.8.20;


contract MultiSigWallet {
    // Events 
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationRequired;

    struct Transaction {
        address payable to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // Mapping to track confirmations for each transaction
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    // modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "transaction already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "transaction already confirmed");
        _;
    }
 
     constructor(address[] memory _owners, uint _numConfirmationRequired) payable {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationRequired > 0 && _numConfirmationRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationRequired = _numConfirmationRequired;
    }

    function submitTransaction(address payable _to, uint _value, bytes memory _data) 
        public
        onlyOwner
    {
        // transactions are indexed based on the array of transactions
        uint txIndex = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));
        
        // emit the event SubmitTransaction
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }


    function confirmTransaction(uint _txIndex) 
        public 
        onlyOwner 
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(!isConfirmed[_txIndex][msg.sender], "Transaction already confirmed");
        isConfirmed[_txIndex][msg.sender] = true;
        transaction.numConfirmations += 1;

        // emit the event ConfirmTransaction
        emit ConfirmTransaction(msg.sender, _txIndex);
        

    }

    function executeTransaction(uint _txIndex) 
        public 
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.numConfirmations >= numConfirmationRequired, "cannot execute tx");

        transaction.executed = true;

        transaction.to.transfer(transaction.value);
        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeTransaction(uint _txIndex) 
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender], "Sender has not confirmed this transaction");

        isConfirmed[_txIndex][msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }


    //helpers
    function getTransaction(uint _txIndex) 
        public
        view
        returns(address to, uint value, bytes memory data, bool executed, uint numConfirmations)
    {
        Transaction storage transaction = transactions[_txIndex];

        to = transaction.to;
        value = transaction.value;
        data = transaction.data;
        executed = transaction.executed;
        numConfirmations = transaction.numConfirmations;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }
}