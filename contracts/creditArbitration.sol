pragma solidity ^0.4.0;

import "./dataType.sol";

// 信誉分仲裁合约
contract creditArbitration {

    mapping (address => contributor) contributorInfo;

    address initiator;         // 发起人
    address target;            // 仲裁目标
    uint256 startTime;         // 开始时间
    uint256 endTime;           // 结束时间
    uint8 severity;            // 严重程度(1-10)
    uint256 approve;           // 赞成数
    uint256 reject;            // 反对数
    mapping (address => bool) hasArbitrated;     // 已经投票的仲裁者
    bool ifExecuted;           // 是否已经执行仲裁

    constructor(address memory _target,uint256 memory duration,uint8 memory _severity){
        initiator = msg.sender;
        target = _target;
        startTime = block.timestamp;
        endTime = block.timestamp + duration * 1 hours;
        severity = _severity;
        approve = 0;
        reject = 0;
        ifExecuted = false;
    }

    // 限制只有未投过票的仲裁者能投票
    modifier onlyArbitrator(){
        contributor c = contributorInfo[msg.sender];
        require(c.isArbitrator, "Only arbitrator can call this function");
        _;
    }

    // 限制
    modifier canArbitrate() {
        require(!hasArbitrated[msg.sender], "You can only arbitrate once.");
        _;
        hasArbitrated[msg.sender] = true;
    }

    // 限制投票时间应早于
    modifier notOvertime() {
        require(block.timestamp <= endTime, "The arbitration is over.");
        _;
    }

    // 尚未进行仲裁
    modifier notExecuted {
        require(block.timestamp > endTime, "Waiting for the end of arbitration.");
        require(!ifExecuted, "Have executed.");
        _;
        ifExecuted = true;
    }

    // 获取仲裁信息
    function getArbitrationInfo() view public returns(string) {
        string result = "{" ;
        result += "'initiator':" + initiator + ",";
        result += "'target':" + target + ",";
        result += "'startTime':" + startTime + ",";
        result += "'endTime':" + endTime + ",";
        result += "'severity':" + severity + ",";
        result += "'approve':" + approve + ",";
        result += "'reject':" + reject + "}";
        return result;
    }

    // 进行仲裁投票
    function vote(bool ifApprove) public onlyArbitrator canArbitrate notOvertime {
        if(ifApprove) {
            approve += 1;
        }
        else {
            reject += 1;
        }
    }

    // 执行仲裁
    function execute() public onlyArbitrator ifExecuted {
        if(approve > reject) {
            // 执行仲裁 TODO
        }
    }


}
