// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {MockRandomizerWrapper} from "../src/Mocks.sol";
import {MockSuperchainModule} from "../src/Mocks.sol";
import {MockERC20} from "../src/Mocks.sol";

contract TestRaffle is Test {
    SuperchainRaffle raffle;
    MockRandomizerWrapper mockRandomizerWrapper;
    MockSuperchainModule mockSuperchainModule;
    MockERC20 _opToken;
    address testUser = vm.addr(1);
    address testUser2 = vm.addr(2);
    address testUser3 = vm.addr(3);
    address testUser4 = vm.addr(4);
    address testUser5 = vm.addr(5);
    address testUser6 = vm.addr(6);
    address testUser7 = vm.addr(7);
    address testUser8 = vm.addr(8);
    address testUser9 = vm.addr(9);
    address testUser10 = vm.addr(10);
    address testUser11 = vm.addr(11);
    address testUser12 = vm.addr(12);
    address testUser13 = vm.addr(13);
    address testUser14 = vm.addr(14);
    address testUser15 = vm.addr(15);
    address[] testUsers;

    function setUp() public {
        uint256[] memory _numberOfWinners = new uint256[](2);
        _numberOfWinners[0] = 1;
        _numberOfWinners[1] = 10;

        testUsers = new address[](15);
        testUsers[0] = testUser;
        testUsers[1] = testUser2;
        testUsers[2] = testUser3;
        testUsers[3] = testUser4;
        testUsers[4] = testUser5;
        testUsers[5] = testUser6;
        testUsers[6] = testUser7;
        testUsers[7] = testUser8;
        testUsers[8] = testUser9;
        testUsers[9] = testUser10;
        testUsers[10] = testUser11;
        testUsers[11] = testUser12;
        testUsers[12] = testUser13;
        testUsers[13] = testUser14;
        testUsers[14] = testUser15;

        uint256[][] memory _payoutPercentage = new uint256[][](2);
        uint256[] memory a = new uint256[](1);
        a[0] = 10000;
        uint256[] memory c = new uint256[](10);
        c[0] = 7500;
        c[1] = 500;
        c[2] = 500;
        c[3] = 500;
        c[4] = 500;
        c[5] = 100;
        c[6] = 100;
        c[7] = 100;
        c[8] = 100;
        c[9] = 100;
        _payoutPercentage[0] = a;
        _payoutPercentage[1] = c;

        // Definir el beneficiario
        address _beneficiary = address(this);

        mockSuperchainModule = new MockSuperchainModule();
        _opToken = new MockERC20();
        raffle = new SuperchainRaffle(
            _numberOfWinners,
            _payoutPercentage,
            _beneficiary,
            address(_opToken),
            address(mockSuperchainModule),
            0
        );
        mockRandomizerWrapper = new MockRandomizerWrapper(
            address(raffle),
            address(this),
            address(this)
        );

        raffle.setRandomizerWrapper(address(mockRandomizerWrapper), true);
        raffle.setStartTime(block.timestamp);
        _opToken.mint(address(this), 100000000000000 * 10 ** 18);
        _opToken.approve(address(raffle), 100000000000000 * 10 ** 18);
    }

    function testFundRaffle() public {
        uint256 roundsToFund = 3;
        uint256 ethAmount = 9 ether; // Fondos para ETH
        uint256 opAmount = 9 * 10 ** 18; // Fondos para OP tokens
        // Pre-fondear la rifa
        raffle.fundRaffle{value: ethAmount}(roundsToFund, opAmount);

        // Verificar que los fondos se han distribuido correctamente
        for (uint256 i = 1; i <= roundsToFund; i++) {
            (uint256 opPrize, uint256 ethPrize) = raffle.roundPrizes(i);
            assertEq(
                ethPrize,
                ethAmount / roundsToFund,
                "ETH amount incorrect"
            );
            assertEq(opPrize, opAmount / roundsToFund, "OP amount incorrect");
        }
    }

    function testFreeTickets() public {
        vm.startPrank(testUser);
        raffle.enterRaffle(1, msg.sender);

        assertEq(
            raffle.getUserTicketsPerRound(testUser, raffle.roundsSinceStart()),
            1,
            "Free ticket not added"
        );
        assertEq(
            raffle.freeTicketsRemaining(msg.sender),
            0,
            "Free tickets remaining not updated"
        );
        assertEq(
            raffle.ticketsSoldPerRound(raffle.roundsSinceStart()),
            1,
            "Tickets sold not updated"
        );
        console.log(
            "Tickets sold",
            raffle.ticketsSoldPerRound(raffle.roundsSinceStart()),
            raffle.roundsSinceStart()
        );
        vm.expectRevert();
        raffle.enterRaffle(1, msg.sender);

        vm.stopPrank();
    }

    function testIndividualClaim() public {
        testFundRaffle();
        testFreeTickets();
        vm.warp(block.timestamp + 1 weeks + 1 days);
        assertEq(raffle.ticketsSoldPerRound(1), 1, "Tickets sold not updated");
        raffle.raffle();
        vm.startPrank(testUser);
        raffle.claim();
        assertEq(
            _opToken.balanceOf(address(testUser)),
            (3 * 10 ** 18),
            "OP tokens transferred"
        );
        assertEq(address(testUser).balance, 3 ether, "ETH transferred");
        raffle.claim();
        assertEq(
            _opToken.balanceOf(address(testUser)),
            (3 * 10 ** 18),
            "OP tokens transferred"
        );
        assertEq(address(testUser).balance, 3 ether, "ETH transferred");
        vm.stopPrank();
    }

    function testMultiPartyRaffle() public {
        testFundRaffle();
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];
            vm.prank(testUserN);
            raffle.enterRaffle(1, msg.sender); // Asumimos que cada usuario compra 1 boleto
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();
        uint256 winnerTicket = mockRandomizerWrapper.getWinningTicketsByRound(
            raffle.roundsSinceStart() - 1
        )[0];
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];

            vm.startPrank(testUserN);
            raffle.claim();
            if (i != winnerTicket - 1) {
                assertEq(
                    _opToken.balanceOf(address(testUserN)),
                    0,
                    "OP tokens transferred"
                );
                assertEq(address(testUserN).balance, 0, "ETH transferred");
            }

            vm.stopPrank();
        }

        uint256 winnersLength = mockRandomizerWrapper
            .getWinningTicketsByRound(raffle.roundsSinceStart() - 1)
            .length;
        address winner = raffle.ticketPerAddressPerRound(
            raffle.roundsSinceStart() - 1,
            winnerTicket
        );

        assertEq(winnersLength, 1, "Incorrect number of winners");
        assertEq(
            _opToken.balanceOf(winner),
            (3 * 10 ** 18),
            "OP tokens transferred incorrectly"
        );
        assertEq(winner.balance, 3 ether, "ETH transferred incorrectly");
    }
    function verifyTotalPrizeDistribution(
        uint256 round
    ) public view returns (bool) {
        uint256[] memory winningTickets = mockRandomizerWrapper
            .getWinningTicketsByRound(round);
        uint256 totalETHPrizeForRound = 3 ether; // El total de ETH a distribuir.
        uint256 calculatedTotal = 0;

        for (uint256 i = 0; i < winningTickets.length; i++) {
            uint256 winnerIndex = winningTickets[i] - 1; // Asumiendo que los tickets están indexados desde 1.
            address winner = raffle.ticketPerAddressPerRound(
                round,
                winnerIndex
            );
            uint256 prizeAmount = _calculatePrizeForTicket(
                i,
                totalETHPrizeForRound
            );

            calculatedTotal += prizeAmount;
        }

        // Comparar el total calculado con el total de premios para la ronda
        return calculatedTotal == totalETHPrizeForRound;
    }

    function _calculatePrizeForTicket(
        uint256 index,
        uint256 totalPrize
    ) internal view returns (uint256) {
        uint256[10] memory prizeDistribution = [
            uint256(7500),
            uint256(500),
            uint256(500),
            uint256(500),
            uint256(500),
            uint256(100),
            uint256(100),
            uint256(100),
            uint256(100),
            uint256(100)
        ]; // Esto debe estar definido o ser accesible
        return (totalPrize * prizeDistribution[index]) / 10000;
    }

    function testMultiPartyRaffleMoreThan10() public {
        testFundRaffle();
        // Asegurarse de que cada uno de los 15 usuarios compre un boleto.
        for (uint i = 0; i < 15; i++) {
            address testUserN = testUsers[i];
            vm.prank(testUserN);
            raffle.enterRaffle(1, msg.sender);
            vm.stopPrank();
        }

        // Avanzar el tiempo para que se pueda realizar la rifa.
        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();

        // Obtener los boletos ganadores.
        uint256[] memory winningTickets = mockRandomizerWrapper
            .getWinningTicketsByRound(raffle.roundsSinceStart() - 1);

        // Comprobaciones de los reclamos y asegurarse de que los no ganadores no reciban premios.
        for (uint i = 0; i < 15; i++) {
            address testUserN = testUsers[i];
            bool isWinner = false;

            // Comprobar si este usuario es uno de los ganadores.
            for (uint j = 0; j < winningTickets.length; j++) {
                if (i == winningTickets[j] - 1) {
                    // Los tickets están indexados desde 1.
                    isWinner = true;
                    break;
                }
            }

            vm.startPrank(testUserN);
            raffle.claim();

            if (!isWinner) {
                assertEq(
                    _opToken.balanceOf(testUserN),
                    0,
                    "OP tokens should not be transferred"
                );
                assertEq(
                    address(testUserN).balance,
                    0,
                    "ETH should not be transferred"
                );
            } else {
                uint256 userBalance = _opToken.balanceOf(testUserN);

                _opToken.approve(address(this), userBalance);

                _opToken.burn(userBalance);

                (bool sent, ) = address(0).call{value: testUserN.balance}("");
                require(sent, "ETH transfer failed");
            }

            vm.stopPrank();
        }

        // Verificar la cantidad correcta de ganadores y validar la transferencia de premios.
        assertEq(winningTickets.length, 10, "Incorrect number of winners");

        uint256 totalETHPrize = 3 ether; // El total de ETH a distribuir.

        bool distribution = verifyTotalPrizeDistribution(
            raffle.roundsSinceStart() - 1
        );
        assertTrue(distribution, "Incorrect prize distribution");
    }

    function testMultiRound() public {
        testMultiPartyRaffleMoreThan10();
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];
            vm.prank(testUserN);
            raffle.enterRaffle(1, msg.sender);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();
        uint256 winnerTicket = mockRandomizerWrapper.getWinningTicketsByRound(
            raffle.roundsSinceStart() - 1
        )[0];
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];

            vm.startPrank(testUserN);
            raffle.claim();
            if (i != winnerTicket - 1) {
                assertEq(
                    _opToken.balanceOf(address(testUserN)),
                    0,
                    "OP tokens transferred"
                );
                assertEq(address(testUserN).balance, 0, "ETH transferred");
            }

            vm.stopPrank();
        }

        uint256 winnersLength = mockRandomizerWrapper
            .getWinningTicketsByRound(raffle.roundsSinceStart() - 1)
            .length;
        address winner = raffle.ticketPerAddressPerRound(
            raffle.roundsSinceStart() - 1,
            winnerTicket
        );

        assertEq(winnersLength, 1, "Incorrect number of winners");
        assertEq(
            _opToken.balanceOf(winner),
            (3 * 10 ** 18),
            "OP tokens transferred incorrectly"
        );
        assertEq(winner.balance, 3 ether, "ETH transferred incorrectly");
    }
}
