import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {RandomizerWrapper} from "../src/RandomizerWrapper.sol";
import {Script, console} from "forge-std/Script.sol";

contract PostDeployUpgradeable is Script {
    uint256[] _freeTicketsPerLevel = new uint256[](10);
    function setUp() public {
        for (uint256 i = 0; i < 10; i++) {
            _freeTicketsPerLevel[i] = i + 1;
        }
    }

    function run() public {
        vm.startBroadcast();
        SuperchainRaffle raffle = SuperchainRaffle(0x30B6f7C268fa02b96284A7A2b3Af38E006b5e2A2);
        RandomizerWrapper randomizerWrapper = RandomizerWrapper(payable(address(0x9Ad670Be0ed061b1E09399e8fdC10b110000B8f9)));
        raffle.setURI(
            "https://raffle.superchain.eco/api/raffle?file=raffle-weekly-se"
        );
        raffle.setFreeTicketsPerLevel(_freeTicketsPerLevel);
        randomizerWrapper.setWhitelistedRaffle(address(raffle), true);
        vm.stopBroadcast();
    }
}
