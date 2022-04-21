// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";

contract voting{
    mapping (address => contributor) public contributorInfo; // 项目内贡献者详细信息
    mapping (bytes32 => uint ) public contributionReceived; // 收到的贡献度
    string public target; // 记录投票内容
    bytes32[] public optionList; // 投票选项
    uint private _deadline; // 投票中止时间

    // 构造函数
    constructor(string memory _target, uint _hoursAfter, bytes32[] memory _optionList){
        target = _target;
        _deadline = block.timestamp + _hoursAfter * 1 hours;
        optionList = _optionList;
    }

    // 限制当前时间应当早于中止时间
    modifier notExpired(){
        require(block.timestamp <= _deadline); 
        _;
    }

    // 查询目标所收到的所有贡献度
    function totalContributionFor(bytes32 _option) view public returns(uint){
        return contributionReceived[_option];
    } 

    // 向目标选项投票
    function voteForTarget(bytes32 _option) public notExpired {
        uint _index = indexOfOption(_option);
        require( _index != optionList.length );
        contributionReceived[_option] += contributorInfo[msg.sender].contribution;
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
    function allOptions() view public returns(bytes32[] memory){
        return optionList;
    }
}