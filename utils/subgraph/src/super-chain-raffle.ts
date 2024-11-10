import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Claim as ClaimEvent,
  Paused as PausedEvent,
  RoundWinners as RoundWinnersEvent,
  TicketsPurchased as TicketsPurchasedEvent,
  Unpaused as UnpausedEvent,
  RaffleFunded as RaffleFundedEvent,
  RaffleStarted as RaffleStartedEvent,
  URIChanged as URIChangedEvent,
  RaffleFundMoved as RaffleFundMovedEvent,
} from "../generated/SuperChainRaffle/SuperChainRaffle";
import {
  Claim,
  Paused,
  Unpaused,
  Raffle,
  Round,
  User,
  UserRoundTickets,
  RoundWinner,
} from "../generated/schema";

export function handleRaffleFunded(event: RaffleFundedEvent): void {
  let round = Round.load(event.params.round.toString());
  if (!round) {
    round = new Round(event.params.round.toString());
    round.raffle = event.address;
    round.roundNumber = event.params.round;
    round.ticketsSold = new BigInt(0);
  }
  round.prizeOp = event.params.opAmount;
  round.prizeEth = event.params.ethAmount;
  round.save();
}

export function handleRaffleStarted(event: RaffleStartedEvent): void {
  let raffle = Raffle.load(event.address);
  if (!raffle) {
    raffle = new Raffle(event.address);
  }
  raffle.initTimestamp = event.params.timestamp;
  raffle.save();
}

export function handleURIChanged(event: URIChangedEvent): void {
  let raffle = Raffle.load(event.address);
  if (!raffle) {
    raffle = new Raffle(event.address);
    raffle.initTimestamp = new BigInt(0);
  }
  raffle.uri = event.params.uri;
  raffle.save();
}

export function handleClaim(event: ClaimEvent): void {
  let entity = new Claim(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  let user = User.load(event.params.user);
  if (!user) {
    user = new User(event.params.user)
    user.opPrizes = event.params.amountOP
    user.ethPrizes = event.params.amountETH
  } else {
    user.opPrizes = user.opPrizes.plus(event.params.amountOP);
    user.ethPrizes = user.ethPrizes.plus(event.params.amountETH);
  }
  user.save()
  entity.user = event.params.user;
  entity.amountEth = event.params.amountOP;
  entity.amountOp = event.params.amountETH;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}


export function handlePaused(event: PausedEvent): void {
  let entity = new Paused(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.account = event.params.account;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleRoundWinners(event: RoundWinnersEvent): void {
  let round = Round.load(event.params.round.toString());
  if (!round) return;

  let winners = event.params.winners;
  for (let i = 0; i < winners.length; i++) {
    let winner = winners[i];

    let user = User.load(winner.user);
    if (user) {
      let winnerId = event.transaction.hash.toHex().concat(i.toString());
      if (winnerId.length % 2 !== 0) {
        winnerId = "0".concat(winnerId);
      }
      let roundWinner = new RoundWinner(Bytes.fromHexString(winnerId));
      roundWinner.round = round.id;
      roundWinner.user = user.id;
      roundWinner.ticketNumber = winner.ticketNumber;



      roundWinner.ethAmount = winner.ethAmount;
      roundWinner.opAmount = winner.opAmount;


      roundWinner.save();

      user.save();
    }
  }
}

export function handleTicketsPurchased(event: TicketsPurchasedEvent): void {
  let round = Round.load(event.params.round.toString());
  if (!round) {
    round = new Round(event.params.round.toString());
    round.roundNumber = event.params.round;
    round.raffle = event.address;
    round.ticketsSold = new BigInt(0);
    round.prizeOp = new BigInt(0);
    round.prizeEth = new BigInt(0);
  }
  let startingTicketNumber = round.ticketsSold;
  round.ticketsSold = round.ticketsSold.plus(
    event.params.numberOfTickets,
  );
  round.save();
  let user = User.load(event.params.user);
  if (!user) {
    user = new User(event.params.user);
    user.opPrizes = new BigInt(0);
    user.ethPrizes = new BigInt(0);
    user.save()
  }
  let userRoundTicketsId = event.params.user.concatI32(
    event.params.round.toI32(),
  );
  let userRoundTickets = UserRoundTickets.load(userRoundTicketsId);

  if (!userRoundTickets) {
    userRoundTickets = new UserRoundTickets(userRoundTicketsId);
    userRoundTickets.user = user.id;
    userRoundTickets.round = round.id;
    userRoundTickets.numberOfTickets = event.params.numberOfTickets;
    userRoundTickets.ticketNumbers = [];
  } else {
    userRoundTickets.numberOfTickets = userRoundTickets.numberOfTickets.plus(
      event.params.numberOfTickets,
    );
  }
  for (let i = 0; i < event.params.numberOfTickets.toI32(); i++) {
    let tickets = userRoundTickets.ticketNumbers;
    tickets.push(startingTicketNumber.plus(BigInt.fromI32(i + 1)));
    userRoundTickets.ticketNumbers = tickets;
  }


  userRoundTickets.save();
}

export function handleUnpaused(event: UnpausedEvent): void {
  let entity = new Unpaused(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.account = event.params.account;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}


export function handleRaffleFundMoved(event: RaffleFundMovedEvent): void {
  let roundFrom = Round.load(event.params.roundFrom.toString());
  let roundTo = Round.load(event.params.roundTo.toString());
  if (!roundFrom || !roundTo) return;
  roundTo.prizeOp = roundTo.prizeOp.plus(roundFrom.prizeOp);
  roundTo.prizeEth = roundTo.prizeEth.plus(roundFrom.prizeEth);
  roundFrom.prizeOp = new BigInt(0);
  roundFrom.prizeEth = new BigInt(0);
}
