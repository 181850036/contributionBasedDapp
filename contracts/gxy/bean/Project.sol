pragma solidity ^0.4.0;

import "./"

contract Project {
    string name;
    address creator;
    projectVisibleInfo visibleInfo; // 项目可见信息
    mapping(address => contributor) contributors;
    uint256 voteInvolvedRate;        // 投票最低参与率
    uint256 voteAdoptedRate;         // 投票最低通过率
    uint256 applyDuration;           // 申请时投票时长
    uint256 modifyDuration;          // 项目参数修改投票时长
    uint256 codeReviewDuration;      // 评审代码时投票时间
    uint256 linesCommitPerContri;    // 每获取一贡献度需要贡献的代码行数
    uint256 weiPerContri;          // 每获取一贡献度需要贡献的金额
    uint256 linesBuyPerContri;       // 每一贡献度能够换取的代码权限的行数
    bool isUsed;
}
