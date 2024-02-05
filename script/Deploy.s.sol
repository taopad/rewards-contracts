// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@forge-std/Script.sol";

import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        console.log(address(new UniversalRewardsDistributor()));
        vm.stopBroadcast();
    }
}
