pragma solidity ^0.4.0;

contract Contributor {
    uint256 private contribution;     // 总贡献度
    uint256 private balance;          // 为执行贡献度
    uint256 private bonusBalance;     // 可以参与分红的贡献度
    uint256 private credit;           // 信誉分
    bool private isArbitrator;         // 是否是仲裁者
    uint256 private lastInvestTime;   // 用户某一个月第一次充值的时间，后面的充值会和这个值比较，如果不足一个月则不计入分红。

    constructor() {
        contribution = 0;
        balance = 0;
        bonusBalance = 0;
        credit = 0;
        isArbitrator = false;
    }
}
