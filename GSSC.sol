
pragma solidity >=0.4.22 <0.9.0;
//pragma experimental ABIEncoderV2;

contract GSSC{
/* This creates a contract to obtain the account state*/
    address owner;
    // mapping the address to the account balance
    mapping (address => uint256) public balances;
    // mapping the address to account locked balance
    mapping(address => uint) public lockedBalances;
    // mapping the address to account deposits
    mapping(address => uint) public deposits;
    // mapping the address to the shard number
    mapping(address => uint) public shardk;
   // the number of votes.
    uint public counter; 
    //the total number of the arbitrators is set as 10, and the threshold is set as 6.
    uint tarbitor = 6; 
    mapping(address => string ) public signature; 
    //the deadline time for the node function call 
    uint public epochtime; 
    uint public time;

   //the struct of arbitration nodes' behavior 
    struct Decisions{
        address arbitors;
        bool votes;
        uint number;
    }
    Decisions[] public decisions;

   //the struct of account state 
   struct TransferRecord {
    uint shards;
    address sender;
    uint shardr;
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
    function lockTokens(address sender, uint con) public {
        require(balances[sender] >= con, "Insufficient balance");
        balances[sender] -= con;
        lockedBalances[sender] += con;
    }
    //token unlocking
    function unlockTokens(address sender, uint con) public {
        require(lockedBalances[sender] >= con, "Insufficient locked balance");
        lockedBalances[sender] -= con;
        balances[sender] += con;
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
        lockTokens(sender, token);
        signature[sender] = sig;
    }

   //judgment of signature matching
    function isEqual(string memory a, string memory b) public pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

   //cross-shard transaction between both parties normally, forwarding the sender's token to the receiver
    function correctx(address sender0, address receiver0, uint token, string memory sigr) public payable {     
    require(lockedBalances[sender0]>= token, "Insufficient token"); 
    require(isEqual(signature[sender0], sigr), "correct receiver");
    unlockTokens(sender0, token);
    forwardTokens(sender0, receiver0, token);
    TransferRecord memory record = TransferRecord(shardk[sender0], sender0, shardk[receiver0], receiver0, token);
    //add record to the transferRecords
    transferRecords.push(record);
    }     


    //request for sender'address, collection of addresses and voting results from the arbitration nodes
    function makeDecision(address abr, bool vote, uint num) public  {
    require(callTime() < epochtime, "Time limit exceeded");
        if (vote == true) {
           Decisions memory newdecisions=Decisions(abr, vote, num);
           decisions.push(newdecisions);
    //the addresses of arbitors are collected in the array  
            counter++;
        } 
    }
    //record the number of correct votes
      function getCounter() public view returns (uint) {
        return counter;
    }
    //set the struct for collecting arbitration addresses to null
    function clearAddresses() public {
        delete decisions;
    }


  //ABR-1 (Proof of No-response)
  function abr_1(address sender1, address receiver1, address[] arbitor1, uint number1, uint token1, uint deposit1) public payable { 
    //the sender's balance must be greater than or equal to the token sent
    require(lockedBalances[sender1]>=token1, "No balance available");
    //the deposit of the sender and receiver needs to be greater than the predefined threshold 
    require(deposits[sender1] >= deposit1, "No deposit available");
    require(deposits[receiver1] >= deposit1, "No deposit available");   
    uint amount1;
    uint award1;
    //unlocking sender token stored in the contract
    unlockTokens(sender1, token1);
    for (uint i = 0; i < arbitor1.length; i++) { 
    //the determine the sender of the arbitration request to ensure that the same request is arbitrated
    require(number1 == decisions[i].number,  "The arbitration number from the address of sender");
            makeDecision(decisions[i].arbitors, decisions[i].votes, decisions[i].number);    
    }
    //the statistics on the number of arbitration votes
    uint counter1=getCounter();
    require(counter1 > 6, "No arbitration results made");
    //the correct and threshold compliant arbitration results
    if(counter1 > 6){   
    amount1 = deposits[receiver1];   
    //the average award of arbitrators
    award1= amount1/counter1;  
    require(award1 > 0, "Amount to split is too small");
   //the award forwarded to each participating arbitrator'account
    for ( i= 0; i < arbitor1.length; i++) {
    require(number1 == decisions[i].number,  "The arbitration number from the address of sender");
            forwardTokens(receiver1, decisions[i].arbitors, award1);            
            TransferRecord memory record1 = TransferRecord(shardk[receiver1], receiver1, shardk[decisions[i].arbitors],decisions[i].arbitors, award1);
            transferRecords.push(record1); 
    }
    deposits[receiver1] = 0;
    clearAddresses();
    }
    //the wrong arbitration results
    else {
    //the penalty for providing incorrect sender and arbitrators
    deposits[sender1] = 0;
   for (i = 0; i < arbitor1.length; i++) {
             deposits[decisions[i].arbitors]=0;
    }
    clearAddresses();
    }
} 

//ABR-2 (Proof of Deliberateness)
  function abr_2(address sender2, address receiver2, address[] arbitor2, uint number2, uint token2, uint deposit2) onlyOwner public payable {
    //the sender's balance must be greater than or equal to the token sent
    require(lockedBalances[sender2]>=token2, "No balance available");
    //the deposit of the sender and receiver needs to be greater than the predefined threshold 
    require(deposits[sender2] >= deposit2, "No deposit available");
    require(deposits[receiver2] >= deposit2, "No deposit available");
    uint amount2;
    uint award2;

    //unlocking sender token stored in the contract
    unlockTokens(sender2, token2);
    //the correct and threshold compliant arbitration results
    for (uint i = 0; i < arbitor2.length; i++) {
    require(number2 == decisions[i].number,  "The arbitration number from the address of sender");
        makeDecision(decisions[i].arbitors, decisions[i].votes, decisions[i].number);   
    }

    uint counter2=getCounter();
    require(counter2 > 6, "No arbitration made");
    if(counter2 > 6){   
    amount2 = deposits[receiver2];   
    award2 = amount2/counter2;   
    require(award2 > 0, "Amount to split is too small");
    //the award forwarded to each participating arbitrator'account
    for (i = 0; i <arbitor2.length; i++) {
    require(number2 == decisions[i].number,  "The arbitration number from the address of sender");
    forwardTokens(receiver2, decisions[i].arbitors, award2);            
    TransferRecord memory record2 = TransferRecord(shardk[receiver2], receiver2, shardk[decisions[i].arbitors],decisions[i].arbitors, award2);
    transferRecords.push(record2); 
    }
    deposits[receiver2] = 0;
    clearAddresses();
    }
    else {
   //the penalty for providing incorrect sender and arbitrators
    deposits[sender2] = 0;
    for (i = 0; i < arbitor2.length; i++) {
             deposits[decisions[i].arbitors]=0;
    }
    clearAddresses();
    }
}

//ABR-3 (Proof of Mis-matching)
 function abr_3(address sender3, address receiver3, address[] arbitor3, uint number3, uint token3, uint deposit3) onlyOwner public payable { 
    //the sender's balance must be greater than or equal to the token sent
    require(lockedBalances[sender3]>=token3, "No balance available");
    //the deposit of the sender and receiver needs to be greater than the predefined threshold 
    require(deposits[sender3] >= deposit3, "No deposit available");
    require(deposits[receiver3] >= deposit3, "No deposit available");
    uint amount3;
    uint award3;
    //unlocking sender token stored in the contract   
    unlockTokens(sender3, token3);
    //the correct and threshold compliant arbitration results
    for (uint i = 0; i < arbitor3.length; i++) {
    require(number3 == decisions[i].number,  "The arbitration number from the address of receiver");
        makeDecision(decisions[i].arbitors, decisions[i].votes, decisions[i].number);       
    }

    uint counter3=getCounter();
    require(counter3 > 6, "No arbitration made");
    if(counter3 > 6){   
    amount3 = deposits[sender3];   
    award3 = amount3/counter3;   
    require(award3 > 0, "Amount to split is too small");
    for (i = 0; i < arbitor3.length; i++) {
        require(number3 == decisions[i].number,  "The arbitration number from the address of receiver");
        forwardTokens(sender3, decisions[i].arbitors, award3);            
        TransferRecord memory record3 = TransferRecord(shardk[sender3], sender3, shardk[decisions[i].arbitors],decisions[i].arbitors, award3);
        transferRecords.push(record3); 

    }
    deposits[sender3] = 0;
    clearAddresses();
    }
    else {
    //the penalty for providing incorrect receiver and arbitrators   
    deposits[receiver3] = 0;
    for (i = 0; i < arbitor3.length; i++) {
        deposits[decisions[i].arbitors]=0;
    }
    clearAddresses();
    }
}

//ABR-4 (Proof of non-answer)
 function abr_4(address sender4, address receiver4, address[] arbitor4, uint number4, uint token4, uint deposit4) onlyOwner public payable {  
    //the sender's balance must be greater than or equal to the token sent
    require(lockedBalances[sender4]>=token4, "No balance available");
    //the deposit of the sender and receiver needs to be greater than the predefined threshold 
    require(deposits[sender4] >= deposit4, "No deposit available");
    require(deposits[receiver4] >= deposit4, "No deposit available");
    uint amount4;
    uint award4;

    //the correct and threshold compliant arbitration results
    for (uint i = 0; i < arbitor4.length; i++) {
       require(number4 == decisions[i].number,  "The arbitration number from the address of receiver");
      makeDecision(decisions[i].arbitors, decisions[i].votes, decisions[i].number);       
    }
    uint counter4=getCounter();
    require(counter4 > 6, "No arbitration made");
    if(counter4 > 6){  
    //the receiver obtains sender's token
    unlockTokens(sender4, token4);
    forwardTokens(sender4, receiver4, token4);
    TransferRecord memory record4 = TransferRecord(shardk[sender4], sender4, shardk[receiver4], receiver4, token4);
    transferRecords.push(record4);    
    amount4 = deposits[sender4];  
    award4 = amount4/counter4;  
    require(award4 > 0, "Amount to split is too small");
    for (i = 0; i < arbitor4.length; i++) {
        require(number4 == decisions[i].number,  "The arbitration number from the address of receiver");
        forwardTokens(sender4, decisions[i].arbitors, award4);            
        TransferRecord memory record5 = TransferRecord(shardk[sender4], sender4, shardk[decisions[i].arbitors],decisions[i].arbitors, award4);
        transferRecords.push(record5);

    }
    deposits[sender4] = 0;
    clearAddresses();
    }
    else {
    //the penalty for providing incorrect receiver and arbitrators
    unlockTokens(sender4, token4);
    deposits[receiver4] = 0;
    for (i = 0; i < arbitor4.length; i++) {
             deposits[decisions[i].arbitors]=0;   
    }
    clearAddresses();
    }
}
//  view account status change results
//  function getTransferRecords() public view returns (TransferRecord[]) {
//    return transferRecords;  
//   }

}
