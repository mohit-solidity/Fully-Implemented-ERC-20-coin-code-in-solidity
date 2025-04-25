// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract createCoin {
    uint8 public constant decimals = 18;
    uint256 public supply;
    uint public fee;
    uint256 private constant stakingReward = 11574074074;
    uint public feeCollected = 0;
    uint public constant conversionRate = 1000;
    uint public constant decimalConvert = 10**uint8(decimals);
    string public name;
    string public symbol;
    address public owner;
    bool private locked = false;
    bool private paused;
    mapping(address=>uint) private balance;
    mapping(address=>bool) private mods;
    mapping(address=>uint) private EndTime;
    mapping(address=>bool) private isStaked;
    mapping(address=>uint256) public stakedAmount;
    mapping(address=>uint256) public startStakedTime;
    mapping(address=>mapping(address=>uint)) private Allowance;
    event Transfer(address indexed from,address indexed to,uint amount);
    event Approval(address indexed from,address indexed spender,uint amount);
    event AddMod(address indexed _address);
    event RemoveMod(address indexed _address);
    event TokensBought(address indexed to,uint ETHER,uint tokens);
    event tokenSell(address indexed from,address indexed to,uint256 amount);
    event Withdraw(address indexed from,uint amount);
    event Paused(address indexed from);
    event Staked(address indexed from,uint amount,uint256 time);
    event UnStaked(address indexed from,uint amount,uint256 reward);
    event UnPaused(address indexed from);
    event ChangeFee(uint256 amount);
    event OwnerChanged(address indexed from,address indexed to);
    event Mint(address indexed from,address indexed to,uint256 amount);
    constructor(string memory _name,string memory _symbol,uint _fee,uint256 _supply){
        name = _name;
        symbol = _symbol;
        supply = _supply*decimalConvert;
        fee = _fee;
        owner = msg.sender;
        balance[owner] = supply;
        emit Transfer(address(0), owner, supply);
    }
    modifier onlyOwner() {
        require(msg.sender==owner,"Not Authorised");
        _;
    }
    modifier onlyMods() {
        require(mods[msg.sender],"Not Authorised");
        _;
    }
    modifier noReenterancy() {
        require(!locked,"Kindly Wait");
        locked = true;
        _;
        locked = false;
    }
    modifier whenPaused() {
        require(!paused,"Contract Is Not Paused");
        _;
    }
    modifier whenNotPaused() {
        require(paused,"Contract Is Paused");
        _;
    }
    function balanceOf(address _address) public view returns(uint){
        return balance[_address];
    }
    function allowance(address _owner,address spender) public view returns(uint){
        return Allowance[_owner][spender];
    }
    function totalSupply() public view returns(uint256){
        return supply;
    }
    function transferOwnership(address _address) public onlyOwner returns(bool){
        require(_address!=address(0),"Invalid Address");
        owner = _address;
        emit OwnerChanged(msg.sender,_address);
        return true;
    }
    function emergencyPause() public onlyOwner onlyMods returns(bool){
        require(!paused,"Already Paused");
        paused = true;
        emit Paused(msg.sender);
        return true;
    }
    function unpause() public onlyOwner whenPaused returns(bool){
        paused = false;
        emit UnPaused(msg.sender);
        return true;
    }
    function changeFee(uint256 changedFee) public onlyOwner{
        fee = changedFee;
        emit ChangeFee(changedFee);
    }
    function buyTokens()public payable whenNotPaused returns(bool){
        require(msg.value!=0 ether,"Amount Must Be Greater Than 0");
        uint256 feeUser = (msg.value*fee)/100;
        uint amountToSend = msg.value-feeUser;
        uint ethIntoTokens = amountToSend*conversionRate*(decimalConvert);
        balance[msg.sender] += ethIntoTokens;
        balance[owner] -= ethIntoTokens;
        feeCollected += feeUser;
        emit TokensBought(msg.sender, msg.value, ethIntoTokens);
        return true;
    }
    function withdraw(uint amount) public noReenterancy returns(bool){
        require(balance[msg.sender]!=0,"Balance Is Empty");
        require(balance[msg.sender]>=amount,"Insufficient Balance");
        uint tokenToETH = (amount*1 ether)/(conversionRate*(decimalConvert));
        uint feeUser = tokenToETH*fee/100;
        feeCollected += feeUser;
        uint amountToSend = tokenToETH - feeUser;
        require(address(this).balance>amountToSend,"Not Enough ETH TO Send");
        (bool success,) = payable(msg.sender).call{value : amountToSend}("");
        require(success,"Transaction Failed");
        balance[msg.sender] -= amount;
        balance[owner] += amount;
        emit tokenSell(msg.sender, owner, amount);
        emit Withdraw(msg.sender,amount);
        return true;
    }
    function withdrawFee() public onlyOwner returns(bool){
        require(feeCollected>0 ether,"Not Enough Fee");
        (bool success, ) = payable(msg.sender).call{value : feeCollected}("");
        require(success,"Transaction Failed");
        feeCollected = 0;
        emit Withdraw(msg.sender,feeCollected);
        return true;
    }
    function addMods(address _address) public onlyOwner{
        require(!mods[_address],"This Address Is Already Mod");
        mods[_address] = true;
        emit AddMod(_address);
    }
    function deleteMods(address _address) public onlyOwner{
        require(mods[_address],"This Address Is Not A Mod");
        mods[_address] = false;
        emit RemoveMod(_address);
    }
    function transfer(address to,uint amount) public whenNotPaused returns(bool){
        require(to!=address(0),"Invalid Address");
        require(amount>0,"Please Enter Greater Than 0");
        require(amount<=balance[msg.sender],"Not Enough Balance");
        balance[msg.sender]-= amount;
        balance[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    function transferFrom(address from,address to,uint amount) public whenNotPaused returns(bool){
        require(Allowance[from][msg.sender]>=amount,"Allowance Exceeded");
        require(balance[from]>=amount,"No Tokens Left");
        balance[from] -= amount;
        balance[to] += amount;
        Allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
    function approve(address spender,uint256 amount) public whenNotPaused returns(bool){
        Allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function burn(uint256 amount) public whenNotPaused returns(bool){
        require(amount<=balance[msg.sender],"Not Enough Balance");
        balance[msg.sender] -= amount;
        supply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }
    function mint(address to,uint256 amount) public onlyOwner returns(bool){
        require(to!=address(0),"Invalid Address");
        balance[to] += amount;
        supply += amount;
        emit Mint(address(0), to, amount);
        return true;
    }
    function stake(uint amount,uint timeInDays) public whenNotPaused returns(bool){
        require(amount>0,"Please Enter Greater Than 0");
        require(amount<=balance[msg.sender],"Not Enough Balance");
        startStakedTime[msg.sender] = block.timestamp;
        EndTime[msg.sender] = block.timestamp + (timeInDays*1 days);
        isStaked[msg.sender] = true;
        balance[msg.sender] -= amount;
        stakedAmount[msg.sender] += amount;
        emit Transfer(msg.sender, owner, amount);
        emit Staked(msg.sender, amount, block.timestamp);
        return true; 
    }
    function unstake() public noReenterancy whenNotPaused returns(bool){
        require(isStaked[msg.sender],"Not Staked");
        require(block.timestamp>=EndTime[msg.sender],"Staking Is In Process");
        uint duration = block.timestamp - startStakedTime[msg.sender];
        uint reward = stakedAmount[msg.sender]*duration*stakingReward/1e18;
        balance[msg.sender] += stakedAmount[msg.sender] + reward;
        emit UnStaked(msg.sender, stakedAmount[msg.sender] + reward, reward);
        stakedAmount[msg.sender] = 0;
        startStakedTime[msg.sender] =0;
        EndTime[msg.sender] = 0;
        isStaked[msg.sender] = false;
        return true;
    }
    function getStakingDetails(address user) public view returns (uint256 staked,uint256 startTime,uint256 endTime,bool isCurrentlyStaked) {
    return (stakedAmount[user],startStakedTime[user],EndTime[user],isStaked[user]);
    }
    receive() external payable {
        revert("Use buyTokens()");
     }
}
