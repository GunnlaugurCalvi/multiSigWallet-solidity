pragma solidity ^0.5.16;


contract MultiSigWallet {
    // Events 
    event Deposit(address indexed sender, uint, amount, uint balance);
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

    adress[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationRequired;

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;
        mapping(address => bool) isConfirmed;
        uint numConfirmation;
    }

    Transaction[] public transactions;
    constructor(address[] memory _owners, uint _numConfirmationRequired) public {
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
    }

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
        require(transactions[_txIndex].isConfirmed[msg.sender], "transaction already confirmed");
        _;
    }
 
    function submitTransaction(address _to, uint _value, bytes memory _data) 
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
            numConfirmation: 0
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

        transaction.isConfirmed[msg.sender] = true;
        transaction.numConfirmation += 1;

        // emit the event ConfirmTransaction
        emit ConfirmTransaction(msg,sender, _txIndex);
        

    }

    function executeTransaction(uint _txIndex) 
        public 
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.numConfirmation >= numConfirmationRequired, "cannot execute tx");

        transaction.executed = true;

        (bool success, ) = transaction.to.call.value(transaction.value)(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);

    }

    function revokeTransaction(uint _txIndex) 
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transactions.isConfirmed[msg.sender], "Sender has not confirmed this transactions");

        transaction.isConfirmed[msg.sender] = false;
        transaction.numConfirmation -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }
}