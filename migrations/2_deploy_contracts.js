var Owned = artifacts.require("./Owned.sol");
var Citizens = artifacts.require("./Citizens.sol");
var Token = artifacts.require("./Token.sol");
var Democracy = artifacts.require("./Democracy.sol");

module.exports = function(deployer) {
	deployer.deploy(Owned).then(function() {
		
		return deployer.deploy(Citizens, Owned.address);
	}).then(function() {
		
		return deployer.deploy(Token, Owned.address, Citizens.address, 1000000000, "Decentralized Autonomous City", "DAC");
	}).then(function() {

		return deployer.deploy(Democracy, Token.address, Owned.address, Citizens.address);
	});
};
