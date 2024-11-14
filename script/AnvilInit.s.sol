// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Create2} from "../src/Create2.sol";
import {Counter} from "../src/Counter.sol";
import {Test20} from "../src/tokens/Test20.sol";
import {NFT} from "../src/tokens/NFT.sol";

// check whether existed on a pre-known address?

contract AnvilInitScript is Script {
    Create2 public create2Deployer;
    Counter public counter;

    // require nonce = 0
    address mustRunnerAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    bytes32 salt = "123456";

    function setUp() public {}

    function run() public {
        uint256 runnerPrivateKey = vm.envUint("SCRIPT_RUNNER_PRIVATE_KEY");
        address runnerAddress = vm.addr(runnerPrivateKey);
        uint256 nonce = getNonce(runnerAddress);
        require(nonce == 0, "Init runner nonce should be 0, aborting deployment.");
        require(runnerAddress == mustRunnerAddress, "Unmatched deployer");

        vm.startBroadcast(runnerPrivateKey);

        create2Deployer = new Create2();

        // deploy Counter
        bytes memory initCode = abi.encodePacked(type(Counter).creationCode);
        address computedCounterAddress = create2Deployer.computeAddress(salt, keccak256(initCode));
        address deployedAddress = create2Deployer.deploy(salt, initCode);
        require(computedCounterAddress == deployedAddress, "create2 counter computed-address invalid");
        Counter(deployedAddress).increment();
        uint256 num = Counter(deployedAddress).number();
        require(num == 1, "counter number != 1");

        // deploy test20 by create2
        initCode = abi.encodePacked(
            type(Test20).creationCode, abi.encode("Local USDT", "USDT", uint8(6), uint256(10000000000), runnerAddress)
        );
        address test20Address = create2Deployer.deploy(salt, initCode);

        // todo: refactor
        // uint256 bal = Test20(test20Address).balanceOf(runnerAddress);
        // string memory name = Test20(test20Address).name();
        // console.log("test20: runnerAddress blance: ", bal, ", name: ", name);
        // bal = Test20(test20Address).balanceOf(address(create2Deployer));
        // console.log("test20: create2 deployer blance of test20: ", bal);

        // deploy nft by create2
        initCode = abi.encodePacked(
            type(NFT).creationCode, abi.encode("Hero NFT", "Hero", "blank://hero-url", runnerAddress, 1000 gwei, 10000)
        );

        address nftAddress = create2Deployer.deploy(salt, initCode);
        uint256 mintValue = NFT(nftAddress).mint_price();
        uint256 token_id = NFT(nftAddress).mintTo{value: mintValue}(runnerAddress);
        require(token_id == 1, "init mint hero token != 1");

        // try write final result
        console.log("## Anvil Create Init Result Begin");
        console.log("CREATE2_FACTORY:", address(create2Deployer));
        console.log("CREATE2_COUNTER_ADDRESS:", deployedAddress);
        console.log("CREATE2_TEST20_ADDRESS:", test20Address);
        console.log("CREATE2_HERO_ADDRESS:", nftAddress);
        console.log("## Anvil Create Init Result End");

        vm.stopBroadcast();
    }

    // Helper function to get the nonce of an address
    function getNonce(address addr) internal view returns (uint256) {
        return addr == address(0) ? 0 : vm.getNonce(addr);
    }
}
