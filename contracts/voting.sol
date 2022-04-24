// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";

contract voting{
    mapping (address => contributor) public contributorInfo; // 项目内贡献者详细信息
    mapping (bytes32 => uint ) public contributionReceived; // 收到的贡献度
    string public target; // 记录投票内容
    bytes32[] public optionList; // 投票选项
    uint private deadline; // 投票中止时间
    address owner; // 构建者
    mapping (address => bool) public hasVoted;// 判断是否已经投过票 默认初始值为false

    // 申明合约级事件，创建投票活动
    event CreateVoting(string _projectName);

    // 构造函数
    constructor(string memory _projectName, string memory _target, uint _hoursAfter, bytes32[] memory _optionList){
        target = _target;
        deadline = block.timestamp + _hoursAfter * 1 hours;
        optionList = _optionList;
        owner = msg.sender;
        emit CreateVoting(_projectName); // 触发合约级事件
    }

    // 限制-当前时间应当早于中止时间
    modifier notExpired(){
        require(
            block.timestamp <= deadline,
            "To Late, the vote is over."
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
    function voteForTarget(bytes32 _option) public notExpired canVote{
        uint _index = indexOfOption(_option);
        require( _index != optionList.length );
        contributionReceived[_option] += contributorInfo[msg.sender].contribution;
    }

    // 获取目标所收到的所有贡献度
    function totalContributionFor(bytes32 _option) view public returns(uint){
        return contributionReceived[_option];
    } 

    // 获取投票选项中目标投票的下标
    function indexOfOption(bytes32 _option) view public returns(uint){
        for(uint i = 0; i < optionList.length; i++){
            if(optionList[i] == _option){
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
    function getAllOptions() view public returns(bytes32[] memory){
        return optionList;
    }

    // 获取投票截止时间
    function getDeadline() view public returns(uint){
        return deadline;
    }

    // 回收程序
    function destroy() public onlyOwner{
        selfdestruct(payable(msg.sender));
    }

    function voted() view public returns(bool){
        return hasVoted[msg.sender];
    }
}