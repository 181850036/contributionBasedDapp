// const dataType = artifacts.require("dataType");
const contribution = artifacts.require("contribution");

module.exports = function(deployer) {
  // deployer.deploy(ConvertLib);
  // deployer.link(ConvertLib, MetaCoin);
  // deployer.deploy(MetaCoin);
  // deployer.deploy(dataType);
  // deployer.link(dataType, contribution);
  deployer.deploy(contribution);
};