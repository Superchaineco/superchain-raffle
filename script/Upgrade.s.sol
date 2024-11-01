import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {Script, console} from "forge-std/Script.sol";
import {ProposeUpgradeResponse, Defender, Options} from "openzeppelin-foundry-upgrades/Defender.sol";




contract Upgrade is Script {
    function setUp() public {}

    function run() public {
     address proxy = vm.envAddress("PROXY_ADDRESS");
        Options memory opts;
        opts.referenceContract = "SuperchainRafflev0.1.sol:SuperchainRaffle";
        ProposeUpgradeResponse memory response = Defender.proposeUpgrade(
            proxy,
            "SuperchainRaffle.sol",
            opts
        );
        console.log("Proposal id", response.proposalId);
        console.log("Url", response.url);
    }
}
