import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {RandomizerWrapper} from "../src/RandomizerWrapper.sol";
import {Defender, ApprovalProcessResponse} from "openzeppelin-foundry-upgrades/Defender.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";

contract DeployUpgradeable is Script {
    uint256[] _numberOfWinners = new uint256[](2);
    uint256[][] _payoutPercentage = new uint256[][](2);
    function setUp() public {
        uint256[] memory a = new uint256[](1);
        a[0] = 10000;
        uint256[] memory b = new uint256[](10);
        b[0] = 7500;
        b[1] = 500;
        b[2] = 500;
        b[3] = 500;
        b[4] = 500;
        b[5] = 100;
        b[6] = 100;
        b[7] = 100;
        b[8] = 100;

        _payoutPercentage[0] = a;
        _payoutPercentage[1] = b;

        _numberOfWinners[0] = 1;
        _numberOfWinners[1] = 10;
    }

    function run() public returns (address) {
        vm.startBroadcast();
        address beneficiary = msg.sender;
        address superChainModule = 0x1Ee397850c3CA629d965453B3cF102E9A8806Ded;
        ERC20 _opToken = ERC20(0x4200000000000000000000000000000000000042);
        RandomizerWrapper randomizerWrapper = new RandomizerWrapper(
            beneficiary,
            0x600EB8D9Cf9aB34302c8A089B0eb3cad988e7303,
            beneficiary
        );
        vm.stopBroadcast();
        ApprovalProcessResponse memory upgradeApprovalProcess = Defender
            .getUpgradeApprovalProcess();
        if (upgradeApprovalProcess.via == address(0)) {
            revert(
                string.concat(
                    "Upgrade approval process with id ",
                    upgradeApprovalProcess.approvalProcessId,
                    " has no assigned address"
                )
            );
        }
        Options memory opts;
        opts.defender.useDefenderDeploy = true;

        address raffleProxy = Upgrades.deployUUPSProxy(
            "SuperchainRaffle.sol",
            abi.encodeCall(
                SuperchainRaffle.initialize,
                (
                    _numberOfWinners,
                    _payoutPercentage,
                    beneficiary,
                    address(_opToken),
                    superChainModule,
                    address(randomizerWrapper),
                    msg.sender
                )
            ),
            opts
        );

        console.logString(
            string.concat("Raffle contract: ", vm.toString((raffleProxy)))
        );
        console.logString(
            string.concat("Op token: ", vm.toString((address(_opToken))))
        );
        console.logString(
            string.concat(
                "RandomizerWrapper contract: ",
                vm.toString((address(randomizerWrapper)))
            )
        );
        console.logString(
            string.concat(
                "encodeCall",
                vm.toString(
                    (
                        abi.encodeCall(
                            SuperchainRaffle.initialize,
                            (
                                _numberOfWinners,
                                _payoutPercentage,
                                beneficiary,
                                address(_opToken),
                                superChainModule,
                                address(randomizerWrapper),
                                msg.sender
                            )
                        )
                    )
                )
            )
        );
        return raffleProxy;
    }
}
