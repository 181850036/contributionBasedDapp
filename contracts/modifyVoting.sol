// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";
import "./interface.sol";

contract modifyVoting{
    uint256 agreeAmount = 0;
    uint256 disagreeAmount = 0;
    uint256 abstainAmount = 0;
    ContributionInterface contributionInterface;
    mapping (string => uint256 ) public contributionReceived; // 收到的贡献度
    string public target; // 记录投票内容
    string[] public optionList = ["Agree","DisAgree","Abstain"];
    uint private deadline; // 投票中止时间
    address public owner; // 构建者
    mapping (address => bool) public hasVoted;// 判断是否已经投过票 默认初始值为false
    uint256 public projectID; // 记录项目名称
    bool public alReadyModified = false; // 记录是否已领取贡献度
    address contriAddr;
    string public paramName;
    uint256 newVal;
    // 申明合约级事件，创建投票活动
    event CreateVoting(uint256 _projectID, string _paramName, string _target, uint _hoursAfter, address _contriAddr, address _owner);

    // 构造函数
    constructor(uint256 _projectID, string memory _paramName, uint256 _newVal, string memory _target, uint _hoursAfter, address _contriAddr, address _owner){
        projectID = _projectID;
        target = _target;
        deadline = block.timestamp + _hoursAfter * 1 hours;
        owner = _owner;
        contriAddr = _contriAddr;
        paramName = _paramName;
        newVal = _newVal;
        contributionInterface = ContributionInterface(_contriAddr);
        emit CreateVoting(_projectID, _paramName, _target, _hoursAfter, _contriAddr, _owner); // 触发合约级事件
    }

    // 限制-当前时间应当早于中止时间
    modifier notExpired(){
        require(
            block.timestamp <= deadline,
            "To Late, the vote is over."
        ); 
        _;
    }

    // 限定投票已经结束
    modifier expired(){
        require(
            block.timestamp > deadline,
            "The vote is not over yet."
        ); 
        _;
    }

    // 限定为持有者调用
    modifier onlyOwner(){
        require(
            msg.sender == owner,
            "Only owner can call this function"
        );
        _;
    }

    // 判断用户是否有权利投票
    modifier canVote(){
        require(
            hasVoted[msg.sender] == false,
            "You have voted and cannot vote again."
        );
        _;
        hasVoted[msg.sender] = true;
    }


    function voteForAgree() public payable notExpired canVote{
        agreeAmount += contributionInterface.getContribution(msg.sender, projectID);
    }
    function voteForDisagree() public payable notExpired canVote{
        disagreeAmount += contributionInterface.getContribution(msg.sender, projectID);
    }
    function voteForAbstain() public payable notExpired canVote{
        abstainAmount += contributionInterface.getContribution(msg.sender, projectID);
    }

    function getAgreed() view public returns(uint256) {
        return agreeAmount;
    }

    function getDisagreed() view public returns(uint256) {
        return disagreeAmount;
    }

    function getAbstained() view public returns(uint256) {
        return abstainAmount;
    }

    // 推迟结束时间
    function delayDeadline(uint _hours) public notExpired onlyOwner{
        deadline = deadline + _hours * 1 hours;
    }

    // 设置是否已领取
    function setAlreadyModified(bool _getOrNot) public {
        alReadyModified = _getOrNot;
    }

    // 获取是否已领取
    function getAlreadyModified() view public expired returns(bool) {
        return alReadyModified;
    } 


    // 获取投票内容
    function getTarget() view public returns(string memory){
        return target;
    }


    // 获取投票截止时间
    function getDeadline() view public returns(uint){
        return deadline;
    }

    // 返回项目名称
    function getProjectID() view public returns(uint256) {
        return projectID;
    }


    // 返回持有人
    function getOwner() view public returns(address){
        return owner;
    }

    function getParamName() view public returns(string memory){
        return paramName;
    }

    function getNewVal() view public returns(uint256){
        return newVal;
    }

    // 回收程序
    function destroy() public onlyOwner{
        selfdestruct(payable(msg.sender));
    }
}