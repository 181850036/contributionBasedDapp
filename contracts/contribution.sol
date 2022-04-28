// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";
import "./voting.sol";

contract contribution{

    mapping(string => project) private projects;
    string[] private projectsKeys;

    // 默认的信誉分增长速率
    ufixed constant DEFAULT_CREDIT_RATE=0.01;

    function createProject (string memory name, uint256 voteInvolvedRate, uint256 voteAdoptedRate,
        uint256 applyDuration, uint256 modifyDuration, uint256 codeReviewDuration,
        uint256 linesCommitPerContri, uint256 weiPerContri,
        uint256 linesBuyPerContri, uint256 contriThreshold, uint256 totalContri) public {
        require( !projects[name].isUsed );
        // 预防引用问题
        projects[name].isUsed = true;
        projects[name].name = name;
        projects[name].voteInvolvedRate = voteInvolvedRate;
        projects[name].voteAdoptedRate = voteAdoptedRate;
        projects[name].applyDuration = applyDuration;
        projects[name].modifyDuration = modifyDuration;
        projects[name].codeReviewDuration = codeReviewDuration;
        projects[name].linesCommitPerContri = linesCommitPerContri;
        projects[name].linesBuyPerContri = linesBuyPerContri;
        projects[name].weiPerContri = weiPerContri;
        projects[name].contriThreshold = contriThreshold;
        projects[name].totalContri = totalContri;
        projects[name].creator = msg.sender;

        projectsKeys.push(name);

    }
    function buyContribution(string memory projectName) public payable returns(uint){
        project storage pro = projects[projectName];
        uint256 contriToBuy = msg.value / pro.weiPerContri;
        projects[projectName].contributors[msg.sender].addr = msg.sender;
        projects[projectName].contributors[msg.sender].contribution += contriToBuy;
        projects[projectName].contributors[msg.sender].balance += contriToBuy;
        projects[projectName].totalContri += contriToBuy;
        if ( pro.contributors[msg.sender].credit == 0 ) {
            projects[projectName].contributors[msg.sender].credit = 100;
        }
        if ( block.timestamp - pro.contributors[msg.sender].lastInvestTime >= 30 * 24 * 60 ) {
            projects[projectName].contributors[msg.sender].lastInvestTime = block.timestamp;
            projects[projectName].contributors[msg.sender].bonusBalance += contriToBuy;
        }
        // 购买完需要增加信誉分
        addCreditByBuyContribution(projectName, msg.sender, msg.value);
        return contriToBuy;
    }
    function getContribution(address userAddr, string memory projectName) public view returns(uint) {
        return projects[projectName].contributors[userAddr].contribution;
    }
    function getLastInvestTime(address userAddr, string memory projectName) public view returns(uint) {
        return projects[projectName].contributors[userAddr].lastInvestTime;
    }
    function transfer(address payable _to) public {
        _to.transfer(address(this).balance);
    }
    // 解决/维护项目中的bug(任务)，获得贡献度
    function getReward(string memory projectName, uint256 changeLines, string memory target, uint hoursAfter, bytes32[] memory optionList) public payable returns(address){
        require(projects[projectName].isUsed);
        uint256 contriToReward = changeLines / projects[projectName].linesCommitPerContri;
        require(projects[projectName].totalContri != 0);
        if (projects[projectName].contributors[msg.sender].contribution / projects[projectName].totalContri >= projects[projectName].contriThreshold) {
            projects[projectName].contributors[msg.sender].contribution += contriToReward;
            projects[projectName].contributors[msg.sender].balance += contriToReward;
            projects[projectName].totalContri += contriToReward;
        }
        else {
            string memory types = "getReward";
            voting vote = new voting(projectName, target, hoursAfter, optionList, types);
            return address(vote);
        }
        addCreditByGe
        
        tReward(projectName,msg.sender,changeLines);
        return address(0);
    }
    // 填写问卷加入项目
    function sendQuestionnaire(string memory projectName, string memory target, uint hoursAfter, bytes32[] memory optionList) public payable returns(address) {
        require(projects[projectName].isUsed);
        string memory types = "sendQuestionnaire";
        voting vote = new voting(projectName, target, hoursAfter, optionList, types);
        return address(vote);
    }



    // --- 信誉分仲裁 ---

    modifier temp(string memory name) {
        _;
    }

    // 限制仲裁者执行
    modifier onlyArbitrator(){
        bool isArbitrator = false;
        // 遍历所有贡献者 判断当前sender是否是仲裁者
        for(uint i = 0;i < projectsKeys.length;i++) {
            if(projects[projectsKeys[i]].contributors[msg.sender].isArbitrator) {
                isArbitrator = true;
                break;
            }
        }
        require(isArbitrator, "Only arbitrator can call this function");
        _;
    }

    // 限制某些项必须存在
    modifier caVerify(string memory projectName,address _target) {
        require(projects[projectName].isUsed, "Project with this name not exist"); // 验证项目存在
        require(projects[projectName].contributors[_target].addr == _target, "No such account."); // 验证项目中包含此账户
        require(!projects[projectName].creditArbitrationMap[_target].ifExist,"Credit arbitration of this target already exist."); // 验证项目中包含此仲裁
        _;
    }

    function creditArbitrationVerify(string memory projectName,address _target) private view {
        require(projects[projectName].isUsed, "Project with this name not exist"); // 验证项目存在
        require(projects[projectName].contributors[_target].addr == _target, "No such account."); // 验证项目中包含此账户
        require(!projects[projectName].creditArbitrationMap[_target].ifExist,"Credit arbitration of this target already exist."); // 验证项目中包含此仲裁
    }

    // 发起信誉分仲裁
    function initiateArbitration(string memory projectName,address _target,uint256 duration,uint8 _severity,string memory _reason) public
    onlyArbitrator caVerify(projectName, _target){

        // creditArbitrationVerify(projectName, _target);

        require(_severity>=1 && _severity<=10, "The severity must between 1 and 10.");
        require(duration>=1, "The duration must longer than 1.");
        require(bytes(_reason).length > 0, "The reason can not be empty.");

        projects[projectName].creditArbitrationMap[_target].initiator = msg.sender;
        projects[projectName].creditArbitrationMap[_target].target = _target;
        projects[projectName].creditArbitrationMap[_target].startTime = block.timestamp;
        projects[projectName].creditArbitrationMap[_target].endTime = block.timestamp + duration * 1 hours;
        projects[projectName].creditArbitrationMap[_target].reason = _reason;
        projects[projectName].creditArbitrationMap[_target].severity = _severity;
        projects[projectName].creditArbitrationMap[_target].approve = 0;
        projects[projectName].creditArbitrationMap[_target].reject = 0;
        projects[projectName].creditArbitrationMap[_target].ifExist = true;

    }

    // 获取仲裁信息
    function getArbitrationInfo(string memory projectName,address _target) view public
    caVerify(projectName, _target) returns(address[2] memory, uint256[5] memory, string memory) {
        // creditArbitrationVerify(projectName, _target);

        creditArbitration storage ca = projects[projectName].creditArbitrationMap[_target];

        address[2] memory r1 = [ca.initiator, ca.target];
        uint256[5] memory r2 = [ca.startTime, ca.endTime, ca.severity, ca.approve, ca.reject];

        return (r1, r2, ca.reason);
    }

    // 进行仲裁投票
    function creditArbitrationVote(string memory projectName,address _target,bool ifApprove) public
    onlyArbitrator caVerify(projectName, _target) {
        // creditArbitrationVerify(projectName, _target);

        creditArbitration storage ca = projects[projectName].creditArbitrationMap[_target];

        require(!ca.hasArbitrated[msg.sender],"You can only arbitrate once.");  // 只能进行一次投票
        require(block.timestamp <= ca.endTime, "The arbitration is over.");  // 只能在结束前投票

        if(ifApprove) projects[projectName].creditArbitrationMap[_target].approve += 1;
        else projects[projectName].creditArbitrationMap[_target].reject += 1;

        projects[projectName].creditArbitrationMap[_target].hasArbitrated[msg.sender] = true;
    }

    function execute(string memory projectName,address _target) public
    onlyArbitrator caVerify(projectName, _target) {
        // creditArbitrationVerify(projectName, _target);

        creditArbitration storage ca = projects[projectName].creditArbitrationMap[_target];

        if(ca.approve > ca.reject) {
            // 信誉分申诉
            if(ca.severity == 0) {
                projects[projectName].contributors[_target].credit = 60;
            }
            // 信誉分仲裁
            else {
                uint256 c = projects[projectName].contributors[_target].credit;

                if(projects[projectName].contributors[_target].credit <= projects[projectName].creditArbitrationMap[_target].severity) {
                    projects[projectName].contributors[_target].credit = 0;
                }
                else {
                    projects[projectName].contributors[_target].credit -= projects[projectName].creditArbitrationMap[_target].severity;
                }

                // 信誉分小于50改变信誉等级
                if(c >= 50 && projects[projectName].contributors[_target].credit < 50) {
                    projects[projectName].contributors[_target].creditRating += 1;
                }
            }
        }

        projects[projectName].creditArbitrationMap[_target].ifExist = false;
    }

    // 申诉信誉分
    function creditAppeal(string memory projectName, string memory _reason) public
    caVerify(projectName, msg.sender) {
        require(!projects[projectName].creditArbitrationMap[msg.sender].ifExist,"You have arbitration bing processed, please wait until it finished.");

        // creditArbitrationVerify(projectName, msg.sender);

        require(projects[projectName].contributors[msg.sender].credit < 50, "Your credit is greater than 50, you do not have to appeal.");
        require(projects[projectName].contributors[msg.sender].creditRating <= 1, "You can not appeal for too many broken promises.");
        require(bytes(_reason).length > 0, "The reason can not be empty.");

        projects[projectName].creditArbitrationMap[msg.sender].initiator = msg.sender;
        projects[projectName].creditArbitrationMap[msg.sender].target = msg.sender;
        projects[projectName].creditArbitrationMap[msg.sender].startTime = block.timestamp;
        projects[projectName].creditArbitrationMap[msg.sender].endTime = block.timestamp + 48 hours;
        projects[projectName].creditArbitrationMap[msg.sender].reason = _reason;
        projects[projectName].creditArbitrationMap[msg.sender].severity = 0;
        projects[projectName].creditArbitrationMap[msg.sender].approve = 0;
        projects[projectName].creditArbitrationMap[msg.sender].reject = 0;
        projects[projectName].creditArbitrationMap[msg.sender].ifExist = true;

    }

    // --- 信誉分增长 --- 

    //验证用户是否加入了项目
    modifier joined(string memory projectName,address userAddr){
        require(projects[projectName].contributors[userAddr].addr == userAddr, "No such account."); // 验证项目中包含此账户
        _;
    }

    //在增加信誉分之前要保证用户的信誉分大于50
    modifier enoughCredit(string memory projectName,address userAddr){
        ufixed credit=projects[projectName].contributors[userAddr].credit;
        require(credit>=50,"only the credit is greater than 50 can be added");
        _;
    }



    //通过购买贡献度来增加信誉分 这个函数在buyContribution中调用
    function addCreditByBuyContribution(string memory projectName,address userAddr,unint256 value) public
    joined(projectName,userAddr) {
         //这里按照代码行数来增加 购买的贡献度可以转化为代码行数
        project pro=projects[projectName];
        uint256 time_diff=block.timestamp-pro.contributors[userAddr].joinTime;
        //用户加入项目一个月以上并且信誉分大于50才增加信誉分
        if(time_diff>30*24*60*60&&pro.contributors[userAddr].credit>=50){
             uint256 contriToBuy=value/pro.weiPerContri;  
             //等价的行数
             uint256 lineNum=contriToBuy*pro.linesBuyPerContri;
             // 通过等价的行数和设定的增长率算出来应该增长的信誉分
             ufixed add=lineNum*DEFAULT_CREDIT_RATE;
             ufixed max=creditIncreasingMax(projectName, userAddr);
             // 如果不超过增长的最大值就加当前值 如果超过就加最大值 以防增长过快
             if(add<max){
                 pro.contributors[userAddr].credit+=add;
             }else{
                 pro.contributors[userAddr].credit+=max;
             }
        }
        controlCredit(projectName,userAddr);
    }

    //通过为项目做出贡献来增加信誉分 这个函数在getReward中调用
    function addCreditByGetReward(string memory projectName,address userAddr,uint256 changeLines) public
    joined(projectName,userAddr){
        project pro=projects[projectName];
        uint256 time_diff=block.timestamp-pro.contributors[userAddr].joinTime;
        //用户加入项目一个月以上并且信誉分大于50才增加信誉分
        if(time_diff>30*24*60*60&&pro.contributors[userAddr].credit>=50){
             ufixed add=changeLines*DEFAULT_CREDIT_RATE;
             ufixed max=creditIncreasingMax(projectName, userAddr);
             // 如果不超过增长的最大值就加当前值 如果超过就加最大值 以防增长过快
             if(add<max){
                 pro.contributors[userAddr].credit+=add;
             }else{
                 pro.contributors[userAddr].credit+=max;
             }
        }
        controlCredit(projectName,userAddr);
    }

    //限制信誉分增长速度
    function controlCredit(string memory projectName,address userAddr) public
    joined(projectName,userAddr){
        project pro=projects[projectName];
        //加入的时间
        uint256 diff_time=block.timestamp-pro.contributors[userAddr].joinTime;
        ufixed credit=pro.contributors[userAddr].credit;
        //半年最多110分
        if(diff_time>=0&&diff_time<=365/2*24*3600){
            pro.contributors[userAddr].credit=min(credit,110);
        //三年最多150分
        }else if(diff_time>365/2*24*3600&&<3*365*24*3600){
            pro.contributors[userAddr].credit=min(credit,150);
        //十年最多180分
        }else if(diff_time>3*365*24*3600&&<10*365*24*3600){
            pro.contributors[userAddr].credit=min(credit,180);
        //最多200分
        }else if(diff_time>=10*365*24){
            pro.contributors[userAddr].credit=min(credit,200);
        }
    
    //返回两个数中比较小的值
    function min(ufixed n1,ufixed n2) public view returns(ufixed){
        if(n1>n2){
            return n2;
        }else{
            return n1;
        }
    }



    // 信誉分增长最大值
    function creditIncreasingMax(string memory projectName,address userAddr) public view returns(ufixed){
        uint8 creditIncreasingLevel = getCreditIncreasingLevel(userAddr,projectName);
        ufixed increasingMax;
        ufixed increasingSpeedController=50;
        for(uint i=0;i<creditIncreasingLevel;i++){
            if(i+1==creditIncreasingLevel){
                increasingMax=increasingSpeedController/projects[projectName].contributors[userAddr].credit;
                break;
            }
            increasingSpeedController-=i*10;
        }
        if(increasingMax<0.1)
            increasingMax=0.1;
        return increasingMax;
    }

    function getCreditIncreasingLevel(address userAddr, string memory projectName) public view returns(uint) {
        return projects[projectName].contributors[userAddr].creditIncreasingLevel;
    }

}