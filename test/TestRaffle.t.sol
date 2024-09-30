// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {MockRandomizerWrapper} from "../src/Mocks.sol";
import {MockSuperchainModule} from "../src/Mocks.sol";
import {MockERC20} from "../src/Mocks.sol";
import {ISuperchainRaffle} from "../src/interfaces/ISuperchainRaffle.sol";

contract TestRaffle is Test {
    SuperchainRaffle raffle;
    MockRandomizerWrapper mockRandomizerWrapper;
    MockSuperchainModule mockSuperchainModule;
    MockERC20 _opToken;

    uint256[] _freeTicketsPerLevel = new uint256[](10);
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
    uint256[][] payoutPercentage;
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
        for (uint256 i = 0; i < 10; i++) {
            _freeTicketsPerLevel[i] = 1;
        }

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
        payoutPercentage = _payoutPercentage;

        ISuperchainRaffle.RandomValueThreshold[]
            memory _randomValueThresholds = new ISuperchainRaffle.RandomValueThreshold[](
                2
            );
        _randomValueThresholds[0] = ISuperchainRaffle.RandomValueThreshold(
            10,
            1
        );
        _randomValueThresholds[1] = ISuperchainRaffle.RandomValueThreshold(
            100,
            10
        );
        // Definir el beneficiario
        address _beneficiary = address(this);

        mockRandomizerWrapper = new MockRandomizerWrapper(
            address(raffle),
            address(this),
            address(this)
        );
        mockSuperchainModule = new MockSuperchainModule();
        _opToken = new MockERC20();
        raffle = new SuperchainRaffle(
            _numberOfWinners,
            _payoutPercentage,
            _beneficiary,
            address(_opToken),
            address(mockSuperchainModule),
            address(mockRandomizerWrapper)
        );
        raffle.setRandomValueThresholds(_randomValueThresholds);

        raffle.setFreeTicketsPerLevel(_freeTicketsPerLevel);
        mockRandomizerWrapper.setWhitelistedRaffle(address(raffle), true);

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
            (uint256 ethPrize, uint256 opPrize) = raffle.getRoundPrizes(i);
            assertEq(
                ethPrize,
                ethAmount / roundsToFund,
                "ETH amount incorrect"
            );
            assertEq(opPrize, opAmount / roundsToFund, "OP amount incorrect");
        }
        assertEq(
            _opToken.balanceOf(address(raffle)),
            opAmount,
            "OP balance incorrect"
        );
        assertEq(address(raffle).balance, ethAmount, "ETH balance incorrect");
    }

    function testEnterRaffle() public {
        vm.startPrank(testUser);
        raffle.enterRaffle(1);
        assertEq(
            raffle.getUserTicketsPerRound(testUser, raffle.roundsSinceStart()),
            1,
            "Ticket not added"
        );
        vm.stopPrank();
    }

    function testFreeTickets() public {
        vm.startPrank(testUser);
        raffle.enterRaffle(1);

        assertEq(
            raffle.getUserTicketsPerRound(testUser, raffle.roundsSinceStart()),
            1,
            "Free ticket not added"
        );
        assertEq(
            raffle.freeTicketsRemaining(testUser),
            0,
            "Free tickets remaining not updated"
        );
        assertEq(
            raffle.getTicketsSoldPerRound(raffle.roundsSinceStart()),
            1,
            "Tickets sold not updated"
        );
        vm.expectRevert();
        raffle.enterRaffle(1);

        vm.stopPrank();
    }

    function testIndividualClaim() public {
        testFundRaffle();
        testFreeTickets();
        vm.warp(block.timestamp + 1 weeks + 1 days);
        assertEq(
            raffle.getTicketsSoldPerRound(1),
            1,
            "Tickets sold not updated"
        );
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
    function testMultipleUsersClaims() public {
        testFundRaffle();
        for (uint i = 0; i < 15; i++) {
            address testUserN = testUsers[i];
            vm.prank(testUserN);
            raffle.enterRaffle(1);
            vm.stopPrank();
        }
        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();
        uint256[] memory winningNumbers = raffle.getWinningNumbers(
            raffle.roundsSinceStart() - 1
        );
        for (uint i = 0; i < winningNumbers.length; i++) {
            address winnerN = raffle.getTicketOwner(
                winningNumbers[i],
                raffle.roundsSinceStart() - 1
            );
            vm.startPrank(winnerN);
            raffle.claim();
            assertEq(
                _opToken.balanceOf(winnerN),
                ((3 * 10 ** 18) * payoutPercentage[1][i]) / 10_000,
                "OP tokens transferred"
            );
            assertEq(
                winnerN.balance,
                (3 ether * payoutPercentage[1][i]) / 10_000,
                "ETH transferred"
            );
            vm.stopPrank();
        }
    }

    function testRaffleWithNoTicketsSold() public {
        testFundRaffle();
        vm.warp(block.timestamp + 3 weeks + 1 days);
        raffle.raffle();
        // Verificar que no se hayan generado números ganadores
        for (uint256 i = 1; i <= 3; i++) {
            (uint256 ethPrize, uint256 opPrize) = raffle.getRoundPrizes(
                raffle.roundsSinceStart()
            );
            assertEq(ethPrize, 9 ether, "ETH prize incorrect");
            assertEq(opPrize, (9 * 10 ** 18), "OP prize incorrect");
            assertEq(
                raffle.getWinningNumbers(i).length,
                0,
                "Winning numbers should be empty"
            );
        }
    }

    function testRaffleWithNoPrizes() public {
        // No se fondeará la rifa
        vm.startPrank(testUser);
        raffle.enterRaffle(1);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();
        // Verificar que no se hayan generado números ganadores
        for (uint256 i = 1; i <= 3; i++) {
            assertEq(
                raffle.getWinningNumbers(i).length,
                0,
                "Winning numbers should be empty"
            );
        }
    }

    function testMultiPartyRaffle() public {
        testFundRaffle();
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];
            vm.prank(testUserN);
            raffle.enterRaffle(1);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();
        uint256[] memory winningNumbers = raffle.getWinningNumbers(
            raffle.roundsSinceStart() - 1
        );
        uint256 winnerTicket = winningNumbers[0];
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];

            vm.startPrank(testUserN);
            raffle.claim();
            if (i != winnerTicket) {
                assertEq(
                    _opToken.balanceOf(address(testUserN)),
                    0,
                    "OP tokens transferred"
                );
                assertEq(address(testUserN).balance, 0, "ETH transferred");
            }

            vm.stopPrank();
        }

        uint256 winnersLength = winningNumbers.length;
        address winner = raffle.getTicketOwner(
            winnerTicket,
            raffle.roundsSinceStart() - 1
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
        uint256[] memory winningTickets = raffle.getWinningNumbers(round);

        uint256 totalETHPrizeForRound = 3 ether; // El total de ETH a distribuir.
        uint256 calculatedTotal = 0;

        for (uint256 i = 0; i < winningTickets.length; i++) {
            uint256 winnerIndex = winningTickets[i];
            address winner = raffle.getTicketOwner(winnerIndex, round);
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
            raffle.enterRaffle(1);
            vm.stopPrank();
        }

        // Avanzar el tiempo para que se pueda realizar la rifa.
        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();

        // Obtener los boletos ganadores.
        uint256[] memory winningTickets = raffle.getWinningNumbers(
            raffle.roundsSinceStart() - 1
        );

        // Comprobaciones de los reclamos y asegurarse de que los no ganadores no reciban premios.
        for (uint i = 0; i < 15; i++) {
            address testUserN = testUsers[i];
            bool isWinner = false;

            // Comprobar si este usuario es uno de los ganadores.
            for (uint j = 0; j < winningTickets.length; j++) {
                if (i == winningTickets[j]) {
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
            raffle.enterRaffle(1);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1 weeks + 1 days);
        raffle.raffle();
        uint256 winnerTicket = raffle.getWinningNumbers(
            raffle.roundsSinceStart() - 1
        )[0];
        for (uint i = 0; i < 10; i++) {
            address testUserN = testUsers[i];

            vm.startPrank(testUserN);
            raffle.claim();
            if (i != winnerTicket) {
                assertEq(
                    _opToken.balanceOf(address(testUserN)),
                    0,
                    "OP tokens transferred"
                );
                assertEq(address(testUserN).balance, 0, "ETH transferred");
            }

            vm.stopPrank();
        }

        uint256 winnersLength = raffle
            .getWinningNumbers(raffle.roundsSinceStart() - 1)
            .length;
        address winner = raffle.getTicketOwner(
            winnerTicket,
            raffle.roundsSinceStart() - 1
        );

        assertEq(winnersLength, 1, "Incorrect number of winners");
        assertEq(
            _opToken.balanceOf(winner),
            (3 * 10 ** 18),
            "OP tokens transferred incorrectly"
        );
        assertEq(winner.balance, 3 ether, "ETH transferred incorrectly");
    }
    function testRaffleWithUnfundedOrUnparticipatedRounds() public {
        // **Paso 1:** Fundear rondas 1 y 3, pero no la ronda 2
        uint256 ethAmount = 6 ether; // 3 ether por cada ronda fondeada
        uint256 opAmount = 6 * 10 ** 18; // 3 tokens OP por cada ronda fondeada

        // Fondear ronda 1
        raffle.fundRaffle{value: 3 ether}(1, 3 * 10 ** 18);

        // Ronda 1
        vm.startPrank(testUser);
        raffle.enterRaffle(1);
        vm.stopPrank();

        // **Nota:** No fondeamos la ronda 2

        // Avanzar el tiempo a la ronda 2
        vm.warp(block.timestamp + 1 weeks);

        // Ronda 2
        vm.startPrank(testUser2);
        raffle.enterRaffle(1);
        vm.stopPrank();

        // Avanzar el tiempo a la ronda 3
        vm.warp(block.timestamp + 1 weeks);

        // Fondear ronda 3
        raffle.fundRaffle{value: 3 ether}(1, 3 * 10 ** 18);

        // **Nota:** No hay participantes en la ronda 3

        // Avanzar el tiempo al final de la ronda 3
        vm.warp(block.timestamp + 1 weeks);

        // **Paso 3:** Ejecutar la función raffle
        raffle.raffle();

        // **Paso 4:** Verificar los resultados

        // **Ronda 1:** fondeada y con participación - deberia tener ganadores
        uint256[] memory winningNumbersRound1 = raffle.getWinningNumbers(1);
        assertEq(
            winningNumbersRound1.length,
            1,
            "Ronda 1 deberia tener 1 ganador"
        );

        // **Ronda 2:** no fondeada pero con participación - no deberia generar ganadores
        uint256[] memory winningNumbersRound2 = raffle.getWinningNumbers(2);
        assertEq(
            winningNumbersRound2.length,
            0,
            "Ronda 2 no deberia tener ganadores"
        );

        // **Ronda 3:** fondeada pero sin participación - no deberia generar ganadores
        uint256[] memory winningNumbersRound3 = raffle.getWinningNumbers(3);
        assertEq(
            winningNumbersRound3.length,
            0,
            "Ronda 3 no deberia tener ganadores"
        );

        // **Paso 5:** Verificar que el ganador de la ronda 1 pueda reclamar su premio
        address winnerRound1 = raffle.getTicketOwner(
            winningNumbersRound1[0],
            1
        );

        vm.startPrank(winnerRound1);
        raffle.claim();
        uint256 expectedOPPrize = 3 * 10 ** 18; // Premio OP esperado
        uint256 expectedETHPrize = 3 ether; // Premio ETH esperado
        assertEq(
            _opToken.balanceOf(winnerRound1),
            expectedOPPrize,
            "El ganador de la ronda 1 deberia recibir tokens OP"
        );
        assertEq(
            winnerRound1.balance,
            expectedETHPrize,
            "El ganador de la ronda 1 deberia recibir ETH"
        );
        vm.stopPrank();

        // **Paso 6:** Verificar que el participante de la ronda 2 no pueda reclamar premio
        vm.startPrank(testUser2);
        raffle.claim();
        assertEq(
            _opToken.balanceOf(testUser2),
            0,
            "El participante de la ronda 2 no deberia recibir tokens OP"
        );
        assertEq(
            testUser2.balance,
            0,
            "El participante de la ronda 2 no deberia recibir ETH"
        );
        vm.stopPrank();
    }

    function testSetWinningLogic() public {
        uint256[] memory newNumberOfWinners = new uint256[](2);
        newNumberOfWinners[0] = 2;
        newNumberOfWinners[1] = 5;

        uint256[][] memory newPayoutPercentage = new uint256[][](2);
        uint256[] memory payout1 = new uint256[](2);
        payout1[0] = 6000;
        payout1[1] = 4000;
        uint256[] memory payout2 = new uint256[](5);
        payout2[0] = 3000;
        payout2[1] = 2500;
        payout2[2] = 2000;
        payout2[3] = 1500;
        payout2[4] = 1000;
        newPayoutPercentage[0] = payout1;
        newPayoutPercentage[1] = payout2;

        raffle.setWinningLogic(newNumberOfWinners, newPayoutPercentage);

        // Verificar que la lógica de ganada se ha actualizado correctamente
        (uint256[] memory winners, uint256[][] memory payouts) = raffle
            .getWinningLogic();
        assertEq(
            winners.length,
            newNumberOfWinners.length,
            "Numero de ganadores incorrecto"
        );
        for (uint256 i = 0; i < winners.length; i++) {
            assertEq(
                winners[i],
                newNumberOfWinners[i],
                "Numero de ganadores incorrecto en el indice"
            );
            for (uint256 j = 0; j < payouts[i].length; j++) {
                assertEq(
                    payouts[i][j],
                    newPayoutPercentage[i][j],
                    "Porcentaje de pago incorrecto en el indice"
                );
            }
        }
    }

    function testSetFreeTicketsPerLevel() public {
        uint256[] memory newFreeTicketsPerLevel = new uint256[](5);
        newFreeTicketsPerLevel[0] = 2;
        newFreeTicketsPerLevel[1] = 4;
        newFreeTicketsPerLevel[2] = 6;
        newFreeTicketsPerLevel[3] = 8;
        newFreeTicketsPerLevel[4] = 10;

        raffle.setFreeTicketsPerLevel(newFreeTicketsPerLevel);

        // Verificar que la cantidad de tickets gratuitos se ha actualizado correctamente
        uint256[] memory updatedFreeTicketsPerLevel = raffle
            .getFreeTicketsPerLevel();
        assertEq(
            updatedFreeTicketsPerLevel.length,
            newFreeTicketsPerLevel.length,
            "Longitud de tickets gratuitos incorrecta"
        );
        for (uint256 i = 0; i < updatedFreeTicketsPerLevel.length; i++) {
            assertEq(
                updatedFreeTicketsPerLevel[i],
                newFreeTicketsPerLevel[i],
                "Cantidad de tickets gratuitos incorrecta en el ndice"
            );
        }
    }

    function testRandomizerCallbackNotExecuted() public {
        vm.roll(10000000);
        uint256 roundsToFund = 1;
        uint256 ethAmount = 3 ether;
        uint256 opAmount = 3 * 10 ** 18;
        raffle.fundRaffle{value: ethAmount}(roundsToFund, opAmount);

        vm.startPrank(testUser);
        raffle.enterRaffle(1);
        vm.stopPrank();
        vm.startPrank(testUser2);
        raffle.enterRaffle(1);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks + 1 days);

        raffle.raffle();

        uint256[] memory winningNumbers = raffle.getWinningNumbers(raffle.roundsSinceStart() - 1);
        console.log("winningNumbers", winningNumbers.length);
        console.log("roundsSinceStart", raffle.roundsSinceStart());
        console.log("block.number", block.number);
        assertEq(winningNumbers.length, 0, "No se deberian haber generado numeros ganadores");

    }
}