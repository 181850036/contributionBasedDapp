// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";

interface ContributionInterface{
     function getContribution(address _address, uint256 _projectID) external view returns(uint256);
}

contract rewardVoting{
    ContributionInterface contributionInterface;
    mapping (string => uint256 ) public contributionReceived; // 收到的贡献度
    string public target; // 记录投票内容
    string[] public optionList = ["Agree","DisAgree","Abstain"];
    string public types; // 记录投票类型
    uint private deadline; // 投票中止时间
    address public owner; // 构建者
    mapping (address => bool) public hasVoted;// 判断是否已经投过票 默认初始值为false
    uint256 public projectID; // 记录项目名称
    uint256 public changeLines; // 记录修改行数
    bool public alreadyGet = false; // 记录是否已领取贡献度

    // 申明合约级事件，创建投票活动
    event CreateVoting(uint256 _projectID, uint256 _changeLines, string _target, uint _hoursAfter, string _types);

    // 构造函数
    constructor(uint256 _projectID, uint256 _changeLines, string memory _target, uint _hoursAfter, string memory _types){
        projectID = _projectID;
        changeLines = _changeLines;
        target = _target;
        deadline = block.timestamp + _hoursAfter * 1 hours;
        types = _types;
        owner = msg.sender;
        emit CreateVoting(_projectID, _changeLines, _target, _hoursAfter, _types); // 触发合约级事件
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

    // 向目标选项投票
    function voteForTarget(string memory _option) public notExpired canVote{
        uint _index = indexOfOption(_option);
        require( _index != optionList.length );
        contributionReceived[_option] += contributionInterface.getContribution(msg.sender, projectID);
    }

    // 推迟结束时间
    function delayDeadline(uint _hours) public notExpired onlyOwner{
        deadline = deadline + _hours * 1 hours;
    }

    // 设置是否已领取
    function setAlreadyGet(bool _getOrNot) public {
        alreadyGet = _getOrNot;
    }

    // 获取是否已领取
    function getAlreadyGet() view public expired returns(bool) {
        return alreadyGet;
    } 

    // 获取目标所收到的所有贡献度
    function totalContributionFor(string memory _option) view public returns(uint){
        return contributionReceived[_option];
    } 

    // 获取投票选项中目标投票的下标
    function indexOfOption(string memory _option) view public returns(uint){
        for(uint i = 0; i < optionList.length; i++){
            if(keccak256(abi.encodePacked(optionList[i])) == keccak256(abi.encodePacked(_option))){
                return i;
            }
        }
        return uint(optionList.length);
    }

    // 获取投票内容
    function getTarget() view public returns(string memory){
        return target;
    }

    // 按次获取所有投票选项
    function getAllOptions() view public returns(string[] memory){
        return optionList;
    }

    // 获取投票类别
    function getType() view public returns(string memory){
        return types;
    }

    // 获取投票截止时间
    function getDeadline() view public returns(uint){
        return deadline;
    }

    // 返回项目名称
    function getProjectID() view public returns(uint256) {
        return projectID;
    }

    // 返回修改行数
    function getChangeLines() view public returns(uint256){
        return changeLines;
    }

    // 返回持有人
    function getOwner() view public returns(address){
        return owner;
    }

    // 回收程序
    function destroy() public onlyOwner{
        selfdestruct(payable(msg.sender));
    }
}