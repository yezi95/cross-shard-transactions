
pragma solidity >=0.4.22 <0.9.0;
//pragma experimental ABIEncoderV2;

contract GSSC{
/* This creates a contract to obtain the account state*/
    address owner;
    // mapping the address to account balance
    mapping (address => uint256) public balances;
    // mapping the address to account lockedbalance
    mapping(address => uint) public lockedBalances;
    // mapping the address to account deposites
    mapping(address => uint) public deposits;
    // mapping the address to shard number
    mapping(address => uint) public shardk;
    //the total number of the arbitors is set as 10（the number of sharding）, and the threshold is set as 6.
    uint n_arbitor=10;
    uint t_arbitor = 6; 
    uint n_deposit =2;
    // mapping the address ro the signature
    mapping(address => string ) public signature; 
    //the deadline time for node function call 
    uint public epochtime; 
    uint public time;

   //the struct of arbitration nodes' behavior 
    struct Decisions{
        address arbitors; //仲裁节点
        bool votes;   //仲裁结果
        uint number;  //仲裁情形分类(number=1,2,3,4)
    }
    Decisions[] public decisions;

   //the struct of account state 
   struct TransferRecord {
    address sender;
    address recipient;
    uint256 amount;
   }
   TransferRecord[] public transferRecords;
 
    modifier onlyOwner() {
        //the function modifier that determines if the caller of this function is the owner.
        require(msg.sender == owner);
        _;
    }
    
    //initialize network configuration
    constructor(uint _epochtime) public {
       //Setting epoch time
        epochtime = _epochtime;
        //initialize the token balance of the node to 100
        balances[msg.sender] = 100; 
        //initialize the deposit balance of the node to 10
        deposits[msg.sender] = 10; 
        // initialize the locked token balance of the node to 0
        lockedBalances[msg.sender] =0;
    }

    //getting the current time
    function getTime() internal returns(uint){
        time = now;
        return(time);
    }
    //output the current time
    function callTime() public returns(uint){
        uint tim = getTime();
        return(tim);
    }   
    //periodic updates of epoch time
    function updateTimeNode(uint newEpochtime) public {
        epochtime = newEpochtime;
    }  

    //obtain the current address account balance
    function getBalance(address add) constant public returns(uint){
        return add.balance;
    }
 
    //payment deposit
    function Deposit(uint shard, address sender, uint deposit) public payable {
        require(getBalance(sender) > deposit, "Deposit amount must be greater than 0"); 
        deposits[sender] += deposit;
        shardk[sender]=shard;
    }

    //token locking
    function lockTokens(uint shard, address sender, uint con) public {
        require(balances[sender] >= con, "Insufficient balance");
        balances[sender] -= con;
        lockedBalances[sender] += con;
        shardk[sender]=shard;
    }
    //token unlocking
    function unlockTokens(uint shard, address sender, uint con) public {
        require(lockedBalances[sender] >= con, "Insufficient locked balance");
        lockedBalances[sender] -= con;
        balances[sender] += con;
        shardk[sender]=shard;
    }
    
    //token sending
    function transfer(address sender, address receiver, uint amount) public {
        require(getBalance(sender) >= amount, "Insufficient balance");
        balances[sender] -= amount;
        balances[receiver] += amount;
    }
    function forwardTokens(address sender, address receiver, uint amount) public {  
        transfer(sender,  receiver, amount);
    }

    //cross-shard transaction sending node pays token and submits signature
    function Balance(address sender, uint token, string memory sig) public payable {     
        require(getBalance(sender) > token, "Balance amount must be greater than token"); 
        balances[sender] += token;
        lockTokens(shardk[sender], sender, token);
        signature[sender] = sig;
    }

   //judgment of signature matching
    function isEqual(address sender, string memory b) public view returns (bool) {
        return keccak256(bytes(signature[sender])) == keccak256(bytes(b));
    }

   //cross-shard transaction between both parties normally, forwarding the sender's token to the receiver
    function correctx(address sender0, address receiver0, uint token, string memory sigr) public payable {     
    require(lockedBalances[sender0]>= token, "Insufficient token"); 
    require(isEqual(sender0, sigr), "Incorrect receiver");
    unlockTokens(shardk[sender0], sender0, token);
    forwardTokens(sender0, receiver0, token);
    TransferRecord memory record = TransferRecord(sender0, receiver0, token);
    //add record to the transferRecords
    transferRecords.push(record);
    }     

    //collection of addresses and voting results from the arbitration nodes
    function makeDecision(address abr, bool vote, uint num) public  {
    require(callTime() < epochtime, "Time limit exceeded");
        if (vote == true) {
           Decisions memory newdecisions=Decisions(abr, vote, num);
           decisions.push(newdecisions);
        } 
    }

    //set the struct for collecting arbitration addresses to null
    function clearAddresses() public {
        delete decisions;
    }

  //ABR (Cross-shard arbitration)
  function abr(address sender1, address receiver1, uint number1, uint token1) public payable { 
    //the sender's balance must be greater than or equal to the token sent
    require(lockedBalances[sender1]>=token1, "No balance available");
    //the deposit of the sender and receiver needs to be greater than the predefined threshold 
    require(deposits[sender1] >= n_deposit, "No deposit available");
    require(deposits[receiver1] >= n_deposit, "No deposit available");   
    uint amount1;
    uint award1;
    uint counter1=0;
    //the no-response or dishonest arbitration from sender(ABR-1)
    if (number1 == 1) {
        for (uint i = 0; i < n_arbitor; i++) { 
   //the determine the arbitration request to ensure that the same request is arbitrated
   // the statistics on the number of arbitration votes
      if(number1 == decisions[i].number){
                 counter1++; 
      }
    }   
    require(counter1 >= t_arbitor, "No arbitration results made");
    //the correct and threshold compliant arbitration results
    if(counter1 >= t_arbitor){  
    //unlocking sender token stored in the contract
    unlockTokens(shardk[sender1], sender1, token1);
    //withdraw receiver deposits 
    amount1 = deposits[receiver1];   
    //the average award of arbitrators
    award1= amount1/counter1;  
    require(award1 > 0, "Amount to split is too small");
   //the award forwarded to each participating arbitrator'account
    for (i= 0; i < n_arbitor; i++) {
    require(number1 == decisions[i].number,  "The arbitration from the sender");
    forwardTokens(receiver1, decisions[i].arbitors, award1);
    TransferRecord memory record1 = TransferRecord(receiver1, decisions[i].arbitors, award1);
    transferRecords.push(record1); 
    }
    deposits[receiver1] = 0;
    clearAddresses();
    }
    //the wrong arbitration results
    else {
    unlockTokens(shardk[sender1], sender1, token1);
    deposits[sender1] = 0;
    for (i = 0; i < n_arbitor; i++) {
    require(number1 == decisions[i].number,  "The arbitration from the sender");
    deposits[decisions[i].arbitors]=0;
    }
    clearAddresses();
    }
    }
     //the dishonest arbitration from sender(ABR-2)
    else if (number1 == 2) {
    for (i = 0; i < n_arbitor; i++) { 
      if(number1 == decisions[i].number){
                 counter1++; 
      }
    }   
    require(counter1 >= t_arbitor, "No arbitration results made");
    //the correct and threshold compliant arbitration results
    if(counter1 >= t_arbitor){  
    //unlocking sender token stored in the contract
    unlockTokens(shardk[sender1], sender1, token1);
    //withdraw receiver deposits 
    amount1 = deposits[receiver1];   
    //the average award of arbitrators
    award1= amount1/counter1;  
    require(award1 > 0, "Amount to split is too small");
   //the award forwarded to each participating arbitrator'account
    for (i= 0; i < n_arbitor; i++) {
    require(number1 == decisions[i].number,  "The arbitration from the sender");
    forwardTokens(receiver1, decisions[i].arbitors, award1);
    TransferRecord memory record2 = TransferRecord(receiver1, decisions[i].arbitors, award1);
    transferRecords.push(record2); 
    }
    deposits[receiver1] = 0;
    clearAddresses();
    }
    //the wrong arbitration results
    else {
    //the penalty for providing incorrect sender and arbitrators
    unlockTokens(shardk[sender1], sender1, token1);
    deposits[sender1] = 0;
   for (i = 0; i < n_arbitor; i++) {
    require(number1 == decisions[i].number,  "The arbitration from the sender");
    deposits[decisions[i].arbitors]=0;
    }
    clearAddresses();
    }
    }
    // the dishonest arbitration from receiver(ABR-3)
    else if (number1 == 3){
        for (i = 0; i < n_arbitor; i++) { 
    //the determine the arbitration request to ensure that the same request is arbitrated
    //the statistics on the number of arbitration votes
      if(number1 == decisions[i].number){
                 counter1++; 
      }  
    require(counter1 >= t_arbitor, "No arbitration made");
    if(counter1 >= t_arbitor){
    //unlocking sender token stored in the contract
    unlockTokens(shardk[sender1], sender1, token1);
    //withdraw sender deposits    
    amount1 = deposits[sender1];   
    award1 = amount1/counter1;   
    require(award1 > 0, "Amount to split is too small");
    for (i = 0; i < n_arbitor; i++) {
        require(number1 == decisions[i].number,  "The arbitration number from the address of receiver");
        forwardTokens(sender1, decisions[i].arbitors, award1);
        TransferRecord memory record3 = TransferRecord(sender1, decisions[i].arbitors, award1);
        transferRecords.push(record3); 
    }
    deposits[sender1] = 0;
    clearAddresses();
    }
    else {
    //the penalty for providing incorrect receiver and arbitrators   
    deposits[receiver1] = 0;
    for (i = 0; i < n_arbitor; i++) {
    require(number1 == decisions[i].number,  "The arbitration number from the address of receiver");    
        deposits[decisions[i].arbitors]=0;
    }
    clearAddresses();
    }
    }
    //the no-response arbitration from receiver(ABR-3)
    } else if (number1 == 4){
    for (i = 0; i < n_arbitor; i++) { 
    //the determine the arbitration request to ensure that the same request is arbitrated
    //the statistics on the number of arbitration votes
    if(number1 == decisions[i].number){
                 counter1++; 
    } 
    }
    require(counter1 >= t_arbitor, "No arbitration made");
    if(counter1 >= t_arbitor){  
    //the receiver obtains sender's token
    forwardTokens(sender1, receiver1, token1);
    TransferRecord memory record4 = TransferRecord(sender1, receiver1, award1);
    transferRecords.push(record4);    
    amount1 = deposits[sender1];  
    award1 = amount1/counter1;  
    require(award1 > 0, "Amount to split is too small");
    for (i = 0; i <n_arbitor; i++) {
        require(number1 == decisions[i].number,  "The arbitration number from the address of receiver");
        forwardTokens(sender1, decisions[i].arbitors, award1);            
        TransferRecord memory record5 = TransferRecord(sender1, decisions[i].arbitors, award1);
        transferRecords.push(record5);
    }
    deposits[sender1] = 0;
    clearAddresses();
    }
    else {
    //the penalty for providing incorrect receiver and arbitrators
    unlockTokens(shardk[sender1], sender1, token1);
    deposits[receiver1] = 0;
    for (i = 0; i < n_arbitor; i++) {
        require(number1 == decisions[i].number,  "The arbitration number from the address of receiver");  
        deposits[decisions[i].arbitors]=0;   
    }
    clearAddresses();
    } 
    }
    else { 
        revert("Out of arbitration scope");
    }
   } 
//  view account status change results
//  function getTransferRecords() public view returns (TransferRecord[]) {
//    return transferRecords;  
//   }
}

