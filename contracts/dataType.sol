// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

enum requirementImportance { P0, P1, P2 } //需求重要性参数

interface ContributionInterface{
     function getContribution(address _address, uint256 _projectID) external view returns(uint256);
}

struct project {
    uint256 id;
    string name;
    address creator;
    projectVisibleInfo visibleInfo; // 项目可见信息
    mapping(address => contributor) contributors;
    address [] allContributors;       //项目所有的贡献者
    uint256 voteInvolvedRate;        // 投票最低参与率
    uint256 voteAdoptedRate;         // 投票最低通过率
    uint256 applyDuration;           // 申请时投票时长
    uint256 modifyDuration;          // 项目参数修改投票时长
    uint256 codeReviewDuration;      // 评审代码时投票时间
    uint256 linesCommitPerContri;    // 每获取一贡献度需要贡献的代码行数
    uint256 weiPerContri;          // 每获取一贡献度需要贡献的金额
    uint256 linesBuyPerContri;       // 每一贡献度能够换取的代码权限的行数
    uint256 contriThreshold;    // 免除代码审核的贡献度阈值
    uint256 totalContri;    // 项目初始总贡献度
    bool isUsed;
    mapping (address => creditArbitration) creditArbitrationMap; //信誉分仲裁列表 (每个账户地址对应一个，即一个账户只能同时进行一项仲裁)
}

struct projectVisibleInfo {
    string briefIntro;
    string[] techStack;
    bytes32 url; 
}

struct contributor {
    address addr;
    uint256 contribution;     // 总贡献度
    uint256 balance;          // 未执行贡献度
    uint256 bonusBalance;     // 可以参与分红的贡献度
    uint256 credit;           // 信誉分
    uint256 creditRating;       // 信用等级 初始为0，信誉分每低于50一次加1，第二次低于50(信誉等级大于1)就无法再参与项目
    bool isArbitrator;        // 是否是仲裁者
    uint256 lastInvestTime;   // 用户某一个月第一次充值的时间，后面的充值会和这个值比较，如果不足一个月则不计入分红。
    uint256 creditIncreasingLevel;  // 信用提升速率等级，低于110为1，110-150为2，150-180为3，180-200(max)为4
    bool isIn;
    uint256 joinTime;         // 用户加入项目的时间
    uint256[2][] contributionWithTimestamp;  //每次提交增加的贡献度和时间戳，用于计算一周内的贡献度
    uint256 week_contri;      //用户一周的贡献度
}

struct creditArbitration {
    address initiator;         // 发起人
    address target;            // 仲裁目标
    uint256 startTime;         // 开始时间
    uint256 endTime;           // 结束时间
    string reason;             // 原因
    uint256 severity;            // 严重程度(1-10) 当此项==0表示这一项仲裁是恢复信誉分仲裁
    uint256 approve;           // 赞成数
    uint256 reject;            // 反对数
    mapping (address => bool) hasArbitrated;     // 已经投票的仲裁者
    bool ifExist;
}