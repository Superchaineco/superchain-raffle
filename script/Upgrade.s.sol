import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {Script, console} from "forge-std/Script.sol";
import {ProposeUpgradeResponse, Defender, Options} from "openzeppelin-foundry-upgrades/Defender.sol";




contract Upgrade is Script {
    function setUp() public {}

    function run() public {
        address proxy = vm.envAddress("PROXY_ADDRESS");
        vm.startBroadcast();
        SuperchainRaffle raffle = new SuperchainRaffle();
        vm.stopBroadcast();
        upgrade(proxy, address(raffle));
        console.log("Upgraded");
        console.log("Proxy address", proxy);
        console.log("New implementation address", address(raffle));
    }

    function upgrade(address proxyAddress, address newImplementation) public {
        vm.startBroadcast();
        SuperchainRaffle proxy = SuperchainRaffle(proxyAddress);
        proxy.upgradeToAndCall(newImplementation, "");
        vm.stopBroadcast();
    }
}
