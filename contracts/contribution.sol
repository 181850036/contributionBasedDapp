// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

import "./dataType.sol";

contract contribution{

    mapping(string => project) private projects;

    function createProject (string memory name, uint256 voteInvolvedRate, uint256 voteAdoptedRate, 
        uint256 applyDuration, uint256 modifyDuration, uint256 codeReviewDuration,
        uint256 linesCommitPerContri, uint256 weiPerContri, 
        uint256 linesBuyPerContri) public {
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
        projects[name].creator = msg.sender;
                            
    }
    function buyContribution(string memory projectName) public payable returns(uint){
        project storage pro = projects[projectName];
        uint256 contriToBuy = msg.value / pro.weiPerContri;
        projects[projectName].contributors[msg.sender].addr = msg.sender;
        projects[projectName].contributors[msg.sender].contribution += contriToBuy;
        projects[projectName].contributors[msg.sender].balance += contriToBuy;
        if ( pro.contributors[msg.sender].credit == 0 ) {
            projects[projectName].contributors[msg.sender].credit = 100;
        }
        if ( block.timestamp - pro.contributors[msg.sender].lastInvestTime >= 30 * 24 * 60 ) {
            projects[projectName].contributors[msg.sender].lastInvestTime = block.timestamp;
            projects[projectName].contributors[msg.sender].bonusBalance += contriToBuy;
        }
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
}