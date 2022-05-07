// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.0 <0.9.0;

interface ContributionInterface{
     function getContribution(address _address, uint256 _projectID) external view returns(uint256);
}