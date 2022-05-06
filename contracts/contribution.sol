// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";
import "./rewardVoting.sol";
import "./entryVoting.sol";
//import "./voting.sol";

contract contribution{

    mapping(uint256 => project) private projects;
    uint256[] private projectsKeys;
    uint256 projectID = 0;

    // 默认的信誉分增长速率
    uint256 constant DEFAULT_CREDIT_RATE=1;
    // 默认每周项目贡献前百分之1的贡献度与信誉分比率
    uint256 constant DEFAULT_CREDIT_WEEK_RATE=1;

    function createProject (string memory name, uint256 voteInvolvedRate, uint256 voteAdoptedRate,
        uint256 applyDuration, uint256 modifyDuration, uint256 codeReviewDuration,
        uint256 linesCommitPerContri, uint256 weiPerContri,
        uint256 linesBuyPerContri, uint256 contriThreshold ) public returns(uint256) {
        uint256 id = projectID;
        projects[id].id = id;
        // 预防引用问题
        projects[id].isUsed = true;
        projects[id].name = name;
        projects[id].voteInvolvedRate = voteInvolvedRate;
        projects[id].voteAdoptedRate = voteAdoptedRate;
        projects[id].applyDuration = applyDuration;
        projects[id].modifyDuration = modifyDuration;
        projects[id].codeReviewDuration = codeReviewDuration;
        projects[id].linesCommitPerContri = linesCommitPerContri;
        projects[id].linesBuyPerContri = linesBuyPerContri;
        projects[id].weiPerContri = weiPerContri;
        projects[id].contriThreshold = contriThreshold;
        // projects[id].totalContri = totalContri;
        projects[id].creator = msg.sender;
        projectsKeys.push(id);
        projectID ++;
        // 初始化创建者
        projects[id].contributors[msg.sender].addr = msg.sender;
        projects[id].contributors[msg.sender].joinTime = block.timestamp;
        projects[id].contributors[msg.sender].credit = 100;
        projects[id].contributors[msg.sender].isIn = true;
        return id;
    }

    // 购买贡献度
    function buyContribution(uint256 id) public payable returns(uint){
        project storage pro = projects[id];
        uint256 contriToBuy = msg.value / pro.weiPerContri;
        if (!projects[id].contributors[msg.sender].isIn)
        {
            projects[id].contributors[msg.sender].isIn = true;
            projects[id].contributors[msg.sender].joinTime = block.timestamp;
            projects[id].contributors[msg.sender].credit = 100;
            projects[id].contributors[msg.sender].addr = msg.sender;
        }
        projects[id].contributors[msg.sender].contribution += contriToBuy;
        projects[id].contributors[msg.sender].balance += contriToBuy;
        projects[id].totalContri += contriToBuy;
        if ( block.timestamp - pro.contributors[msg.sender].lastInvestTime >= 30 * 24 * 60 ) {
            projects[id].contributors[msg.sender].lastInvestTime = block.timestamp;
            projects[id].contributors[msg.sender].bonusBalance += contriToBuy;
        }
         // 购买完需要增加信誉分
        addCreditByBuyContribution(id, msg.sender, msg.value);

        //更新项目的用户列表
        if(!existContributors(projects[id].allContributors,msg.sender)){
            projects[id].allContributors.push(msg.sender);
        }
        return contriToBuy;
    }

    function transfer(address payable _to) public {
        _to.transfer(address(this).balance);
    }

    // 解决/维护项目提交代码，大股东直接获得贡献度，小股东发起审核投票
    function commitChange(uint256 id, uint256 changeLines) public payable returns(address){
        require(projects[id].isUsed);
        require(projects[id].totalContri != 0);
        require(projects[id].contributors[msg.sender].isIn);
        uint256 contriToReward = changeLines / projects[id].linesCommitPerContri;
        // 大股东直接获得贡献度
        if (projects[id].contributors[msg.sender].contribution / projects[id].totalContri * 100 >= projects[id].contriThreshold) {
            projects[id].contributors[msg.sender].contribution += contriToReward;
            projects[id].contributors[msg.sender].balance += contriToReward;
            projects[id].contributors[msg.sender].bonusBalance += contriToReward;
            projects[id].totalContri += contriToReward;
            return address(0);
        }
        // 小股东发起审核投票，返回投票地址给提交者
        else {
            string memory target = "Vote for rewarding contribution";
            string memory types = "getReward";
            uint256 hoursAfter = projects[id].modifyDuration;
            rewardVoting vote = new rewardVoting(id, changeLines, target, hoursAfter, types, address(this),address(msg.sender));
            return address(vote); 
        }
    }

    // 根据审核投票结果领取贡献度奖励
    function getReward(address voteAdd) public payable {
        rewardVoting vote = rewardVoting(voteAdd);
        require(vote.getOwner() == msg.sender);   // 判断发起方是否为合约拥有者（代码提交者）
        require(!vote.getAlreadyGet());   // 判断是否已领取贡献度
        uint256 id = vote.getProjectID();
        uint agree = vote.totalContributionFor("Agree");
        uint disagree = vote.totalContributionFor("Disagree");
        uint abstain = vote.totalContributionFor("Abstain");
        uint all = agree + disagree +abstain;
        uint256 changeLines = vote.getChangeLines();
        uint256 contriToReward = changeLines / projects[id].linesCommitPerContri;
        require(all != 0);
        if(agree / all * 100> projects[id].voteInvolvedRate && agree / all * 100 > projects[id].voteAdoptedRate) {
            projects[id].contributors[msg.sender].contribution += contriToReward;
            projects[id].contributors[msg.sender].balance += contriToReward;
            projects[id].contributors[msg.sender].bonusBalance += contriToReward;
            projects[id].totalContri += contriToReward;
            vote.setAlreadyGet(true);
            addCreditByGetReward(id,msg.sender,changeLines);
            //每次贡献度需要增加时，把时间戳也带上，后续可以计算某个用户一周内的贡献度
            uint256 [2] memory element=[contriToReward,block.timestamp];
            projects[id].contributors[msg.sender].contributionWithTimestamp.push(element);
        }
    }


    // 外部用户填写问卷加入项目，发起投票审核
    function sendQuestionnaire(uint256 id) public payable returns(address) {
        require(projects[id].isUsed);
        string memory target = "Vote for entry";
        string memory types = "permitEntry";
        uint256 hoursAfter = projects[id].applyDuration;
        entryVoting vote = new entryVoting(id, target, hoursAfter, types, address(this));
        return address(vote);
    }

    // 根据审核投票结果决定是否准入
    function permitEntry(address voteAdd) public payable {
        entryVoting vote = entryVoting(voteAdd);
        require(vote.getOwner() == msg.sender);   // 判断发起方是否为合约拥有者（问卷提交者）
        require(!vote.getAlreadyPermit());   // 判断是否已批准进入
        uint256 id = vote.getProjectID();
        uint agree = vote.totalContributionFor("Agree");
        uint disagree = vote.totalContributionFor("Disagree");
        uint abstain = vote.totalContributionFor("Abstain");
        uint all = agree + disagree +abstain;
        require(all != 0);
        if(agree / all * 100 > projects[id].voteInvolvedRate && agree / all * 100 > projects[id].voteAdoptedRate) {
            projects[id].contributors[msg.sender].addr = msg.sender;
            projects[id].contributors[msg.sender].contribution = 0;
            projects[id].contributors[msg.sender].balance = 0;
            projects[id].contributors[msg.sender].joinTime = block.timestamp;
            projects[id].contributors[msg.sender].credit = 100;
            vote.setAlreadyPermit(true);
            //更新项目的用户列表
            projects[id].allContributors.push(msg.sender);
        }
    }

    function getContribution(address _address, uint256 _projectID) public view returns(uint256){
        return projects[_projectID].contributors[_address].contribution;
    }

    // 信誉分增长最大值
    function creditIncreasingMax(uint256 id,address userAddr) public view returns(uint256){
        uint8 creditIncreasingLevel = getCreditIncreasingLevel(userAddr,id);
        uint256 increasingMax;
        uint256 increasingSpeedController=5000;
        for(uint i=0;i<creditIncreasingLevel;i++){
            if(i+1==creditIncreasingLevel){
                increasingMax=increasingSpeedController/projects[id].contributors[userAddr].credit;
                break;
            }
            increasingSpeedController-=i*1000;
        }
        if(increasingMax<10)
            increasingMax=10;
        return increasingMax;
    }


    function getCreditIncreasingLevel(address userAddr, uint256 id) public view returns(uint) {
        return projects[id].contributors[userAddr].creditIncreasingLevel;
    }




//     // --- 信誉分仲裁 ---

//     modifier temp(string memory name) {
//         _;
//     }

//     // 限制仲裁者执行
//     modifier onlyArbitrator(){
//         bool isArbitrator = false;
//         // 遍历所有贡献者 判断当前sender是否是仲裁者
//         for(uint i = 0;i < projectsKeys.length;i++) {
//             if(projects[projectsKeys[i]].contributors[msg.sender].isArbitrator) {
//                 isArbitrator = true;
//                 break;
//             }
//         }
//         require(isArbitrator, "Only arbitrator can call this function");
//         _;
//     }

//     // 限制某些项必须存在
//     modifier caVerify(uint256 id,address _target) {
//         require(projects[id].isUsed, "Project with this ID not exist"); // 验证项目存在
//         require(projects[id].contributors[_target].addr == _target, "No such account."); // 验证项目中包含此账户
//         require(!projects[id].creditArbitrationMap[_target].ifExist,"Credit arbitration of this target already exist."); // 验证项目中包含此仲裁
//         _;
//     }

//     function creditArbitrationVerify(uint256 id,address _target) private view {
//         require(projects[id].isUsed, "Project with this ID not exist"); // 验证项目存在
//         require(projects[id].contributors[_target].addr == _target, "No such account."); // 验证项目中包含此账户
//         require(!projects[id].creditArbitrationMap[_target].ifExist,"Credit arbitration of this target already exist."); // 验证项目中包含此仲裁
//     }

//     // 发起信誉分仲裁
//     function initiateArbitration(uint256 id,address _target,uint256 duration,uint8 _severity,string memory _reason) public
//     onlyArbitrator caVerify(id, _target){

//         // creditArbitrationVerify(projectName, _target);

//         require(_severity>=1 && _severity<=10, "The severity must between 1 and 10.");
//         require(duration>=1, "The duration must longer than 1.");
//         require(bytes(_reason).length > 0, "The reason can not be empty.");

//         projects[id].creditArbitrationMap[_target].initiator = msg.sender;
//         projects[id].creditArbitrationMap[_target].target = _target;
//         projects[id].creditArbitrationMap[_target].startTime = block.timestamp;
//         projects[id].creditArbitrationMap[_target].endTime = block.timestamp + duration * 1 hours;
//         projects[id].creditArbitrationMap[_target].reason = _reason;
//         projects[id].creditArbitrationMap[_target].severity = _severity;
//         projects[id].creditArbitrationMap[_target].approve = 0;
//         projects[id].creditArbitrationMap[_target].reject = 0;
//         projects[id].creditArbitrationMap[_target].ifExist = true;

//     }

//     // 获取仲裁信息
//     function getArbitrationInfo(uint256 id,address _target) view public
//     caVerify(id, _target) returns(address[2] memory, uint256[5] memory, string memory) {
//         // creditArbitrationVerify(projectName, _target);

//         creditArbitration storage ca = projects[id].creditArbitrationMap[_target];

//         address[2] memory r1 = [ca.initiator, ca.target];
//         uint256[5] memory r2 = [ca.startTime, ca.endTime, ca.severity, ca.approve, ca.reject];

//         return (r1, r2, ca.reason);
//     }

//     // 进行仲裁投票
//     function creditArbitrationVote(uint256 id,address _target,bool ifApprove) public
//     onlyArbitrator caVerify(id, _target) {
//         // creditArbitrationVerify(projectName, _target);

//         creditArbitration storage ca = projects[id].creditArbitrationMap[_target];

//         require(!ca.hasArbitrated[msg.sender],"You can only arbitrate once.");  // 只能进行一次投票
//         require(block.timestamp <= ca.endTime, "The arbitration is over.");  // 只能在结束前投票

//         if(ifApprove) projects[id].creditArbitrationMap[_target].approve += 1;
//         else projects[id].creditArbitrationMap[_target].reject += 1;

//         projects[id].creditArbitrationMap[_target].hasArbitrated[msg.sender] = true;
//     }

//     function execute(uint256 id,address _target) public
//     onlyArbitrator caVerify(id, _target) {
//         // creditArbitrationVerify(projectName, _target);

//         creditArbitration storage ca = projects[id].creditArbitrationMap[_target];

//         if(ca.approve > ca.reject) {
//             // 信誉分申诉
//             if(ca.severity == 0) {
//                 projects[id].contributors[_target].credit = 60;
//             }
//             // 信誉分仲裁
//             else {
//                 uint256 c = projects[id].contributors[_target].credit;

//                 if(projects[id].contributors[_target].credit <= projects[id].creditArbitrationMap[_target].severity) {
//                     projects[id].contributors[_target].credit = 0;
//                 }
//                 else {
//                     projects[id].contributors[_target].credit -= projects[id].creditArbitrationMap[_target].severity;
//                 }

//                 // 信誉分小于50改变信誉等级
//                 if(c >= 50 && projects[id].contributors[_target].credit < 50) {
//                     projects[id].contributors[_target].creditRating += 1;
//                 }
//             }
//         }

//         projects[id].creditArbitrationMap[_target].ifExist = false;
//     }

//     // 申诉信誉分
//     function creditAppeal(uint256 id, string memory _reason) public
//     caVerify(id, msg.sender) {
//         require(!projects[id].creditArbitrationMap[msg.sender].ifExist,"You have arbitration bing processed, please wait until it finished.");

//         // creditArbitrationVerify(projectName, msg.sender);

//         require(projects[id].contributors[msg.sender].credit < 50, "Your credit is greater than 50, you do not have to appeal.");
//         require(projects[id].contributors[msg.sender].creditRating <= 1, "You can not appeal for too many broken promises.");
//         require(bytes(_reason).length > 0, "The reason can not be empty.");

//         projects[id].creditArbitrationMap[msg.sender].initiator = msg.sender;
//         projects[id].creditArbitrationMap[msg.sender].target = msg.sender;
//         projects[id].creditArbitrationMap[msg.sender].startTime = block.timestamp;
//         projects[id].creditArbitrationMap[msg.sender].endTime = block.timestamp + 48 hours;
//         projects[id].creditArbitrationMap[msg.sender].reason = _reason;
//         projects[id].creditArbitrationMap[msg.sender].severity = 0;
//         projects[id].creditArbitrationMap[msg.sender].approve = 0;
//         projects[id].creditArbitrationMap[msg.sender].reject = 0;
//         projects[id].creditArbitrationMap[msg.sender].ifExist = true;

//     }

 // --- 信誉分增长 --- 

    //验证用户是否加入了项目
    modifier joined(uint256 id,address userAddr){
        require(projects[id].contributors[userAddr].addr == userAddr, "No such account."); // 验证项目中包含此账户
        _;
    }

    //在增加信誉分之前要保证用户的信誉分大于50
    modifier enoughCredit(uint256 id,address userAddr){
        uint256 credit=projects[id].contributors[userAddr].credit;
        require(credit>=50,"only the credit is greater than 50 can be added");
        _;
    }



    //通过购买贡献度来增加信誉分 这个函数在buyContribution中调用
    function addCreditByBuyContribution(uint256 id,address userAddr,uint256 value) public
    joined(id,userAddr) {
         //这里按照代码行数来增加 购买的贡献度可以转化为代码行数
        project storage pro=projects[id];
        uint256 time_diff=block.timestamp-pro.contributors[userAddr].joinTime;
        //用户加入项目一个月以上并且信誉分大于50才增加信誉分
        if(time_diff>30*24*60*60&&pro.contributors[userAddr].credit>=50){
             uint256 contriToBuy=value/pro.weiPerContri;  
             //等价的行数
             uint256 lineNum=contriToBuy*pro.linesBuyPerContri;
             // 通过等价的行数和设定的增长率算出来应该增长的信誉分
             uint256 add=lineNum*DEFAULT_CREDIT_RATE;
             uint256 max=creditIncreasingMax(id, userAddr);
             // 如果不超过增长的最大值就加当前值 如果超过就加最大值 以防增长过快
             if(add<max){
                 pro.contributors[userAddr].credit+=add;
             }else{
                 pro.contributors[userAddr].credit+=max;
             }
        }
        controlCredit(id,userAddr);
    }

    //通过为项目做出贡献来增加信誉分 这个函数在getReward中调用
    function addCreditByGetReward(uint256 id,address userAddr,uint256 changeLines) public
    joined(id,userAddr){
        project storage pro=projects[id];
        uint256 time_diff=block.timestamp-pro.contributors[userAddr].joinTime;
        //用户加入项目一个月以上并且信誉分大于50才增加信誉分
        if(time_diff>30*24*60*60&&pro.contributors[userAddr].credit>=50){
            uint256 add=changeLines*DEFAULT_CREDIT_RATE;
            uint256 max=creditIncreasingMax(id, userAddr);
             // 如果不超过增长的最大值就加当前值 如果超过就加最大值 以防增长过快
             if(add<max){
                 pro.contributors[userAddr].credit+=add;
             }else{
                 pro.contributors[userAddr].credit+=max;
             }
        }
        controlCredit(id,userAddr);
    }

    //增加一个用户在某个项目内的信誉分 由用户来调用  如果在某个项目周贡献周排名前百分之一 就增加相应的信誉分
    function addCreditBySubmit(uint256 id) public {
       
        project pro=projects[id];
        //如果用户在项目中，检查一周内贡献度排名
        require(existContributors(pro.allContributors, msg.sender),"you are not in this project");
      
        //项目的所有贡献者
        contributor[] sort;
        for(uint j=0;j<pro.allContributors.length;j++){
            sort.push(pro.contributors[pro.allContributors[j]]);
        }
        uint256 time_now=block.timestamp; //现在的时间
        for(uint k=0;k<sort.length;k++){
            uint256[2][] contri_time=sort[k].contributionWithTimestamp;
            sort[k].week_contri=0;   //清零每周的贡献
            for(uint p=0;p=contri_time.length;p++){
                uint256[2] one=contri_time[p];
                //如果是这一周内的贡献度就计入
                if(time_now-one[1]<7*24*3600){
                    sort[k].week_contri+=one[0];
                }
                     
            }
        }
        //现在的contributor中的所有贡献者每个里面都有一周内的贡献度,排序
        quickSort(sort, 0, sort.length-1);
        //小于100人给第一名加分 佛则看前百分之一
        if(sort.length<=100){
            if(msg.sender==sort[0].addr){
                uint256 add=sort[0].week_contri/DEFAULT_CREDIT_WEEK_RATE;
                pro.contributors[msg.sender].credit+=add;
                 controlCredit(id,msg.sender);
            }
        }else{
            for(uint q=0;q<sort.length/100;q++){
                if(msg.sender==sort[q].addr){
                uint256 add=sort[q].week_contri/DEFAULT_CREDIT_WEEK_RATE;
                pro.contributors[msg.sender].credit+=add;
                 controlCredit(id,msg.sender);
                }
            }
        }        
    }

    //对贡献者list进行一个快速排序
    function quickSort(contributor[] arr, uint left, uint right) internal {
        uint i = left;
        uint j = right;
        if (i == j) return;
        uint pivot = arr[left + (right - left) / 2].week_contri;
        while (i <= j) {
            while (arr[i].week_contri < pivot) i++;
            while (pivot < arr[j].week_contri) j--;
            if (i <= j) {
                (arr[i], arr[j]) = (arr[j], arr[i]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }


    //限制信誉分增长速度
    function controlCredit(uint256 id,address userAddr) public
    joined(id,userAddr){
        project storage pro=projects[id];
        //加入的时间
        uint256 diff_time=block.timestamp-pro.contributors[userAddr].joinTime;
        uint256 credit=pro.contributors[userAddr].credit;
        //半年最多11000分
        if(diff_time>=0&&diff_time<=365/2*24*3600){
            pro.contributors[userAddr].credit=min(credit,11000);
        //三年最多15000分
        }else if(diff_time>365/2*24*3600&&diff_time<3*365*24*3600){
            pro.contributors[userAddr].credit=min(credit,15000);
        //十年最多18000分
        }else if(diff_time>3*365*24*3600&&diff_time<10*365*24*3600){
            pro.contributors[userAddr].credit=min(credit,18000);
        //最多20000分
        }else if(diff_time>=10*365*24){
            pro.contributors[userAddr].credit=min(credit,20000);
        }
    }
    
    //返回两个数中比较小的值
    function min(uint256 n1,uint256 n2) public pure returns(uint256){
        if(n1>n2){
            return n2;
        }else{
            return n1;
        }
    }

    //判断是否存在
    function existContributors(address[] memory all, address a) public pure returns(bool) {
        for(uint i=0;i<all.length;i++){
            if(a==all[i]){
                return true;
            }
        }
        return false;
    }
    //============================================



//     // 信誉分增长最大值
//     function creditIncreasingMax(uint256 id,address userAddr) public view returns(ufixed){
//         uint8 creditIncreasingLevel = getCreditIncreasingLevel(userAddr,id);
//         ufixed increasingMax;
//         ufixed increasingSpeedController=50;
//         for(uint i=0;i<creditIncreasingLevel;i++){
//             if(i+1==creditIncreasingLevel){
//                 increasingMax=increasingSpeedController/projects[id].contributors[userAddr].credit;
//                 break;
//             }
//             increasingSpeedController-=i*10;
//         }
//         if(increasingMax<0.1)
//             increasingMax=0.1;
//         return increasingMax;
//     }

//     function getCreditIncreasingLevel(address userAddr, uint256 id) public view returns(uint) {
//         return projects[id].contributors[userAddr].creditIncreasingLevel;
//     }


}