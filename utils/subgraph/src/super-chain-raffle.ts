import { BigInt } from "@graphprotocol/graph-ts";
import {
  Claim as ClaimEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  Paused as PausedEvent,
  RoundWinners as RoundWinnersEvent,
  TicketsPurchased as TicketsPurchasedEvent,
  Unpaused as UnpausedEvent,
  RaffleFunded as RaffleFundedEvent,
  RaffleStarted as RaffleStartedEvent,
} from "../generated/SuperChainRaffle/SuperChainRaffle";
import {
  Claim,
  OwnershipTransferred,
  Paused,
  RoundWinners,
  TicketsPurchased,
  Unpaused,
  Raffle,
  Round,
  User,
  UserRoundTickets,
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
  raffle.initTimestamp = event.block.timestamp;
  raffle.save();
}

export function handleClaim(event: ClaimEvent): void {
  let entity = new Claim(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.user = event.params.user;
  entity.amountEth = event.params.amountEth;
  entity.amountOp = event.params.amountOp;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent,
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;

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
  let entity = new RoundWinners(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.round = event.params.round;
  entity.ticketsSold = event.params.ticketsSold;
  entity.winningTickets = event.params.winningTickets;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleTicketsPurchased(event: TicketsPurchasedEvent): void {
  let entity = new TicketsPurchased(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  );
  entity.buyer = event.params.buyer;
  entity.startingTicketNumber = event.params.startingTicketNumber;
  entity.numberOfTicketsBought = event.params.numberOfTicketsBought;
  entity.round = event.params.round;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
  let round = Round.load(event.params.round.toString());
  if (!round) {
    round = new Round(event.params.round.toString());
    round.roundNumber = event.params.round;
    round.raffle = event.address;
  }
  round.ticketsSold = round.ticketsSold.plus(
    event.params.numberOfTicketsBought,
  );
  round.save();
  let user = User.load(event.params.buyer);
  if (!user) {
    user = new User(event.params.buyer);
    user.save();
  }
  let userRoundTicketsId = event.params.buyer.concatI32(
    event.params.round.toI32(),
  );
  let userRoundTickets = UserRoundTickets.load(userRoundTicketsId);

  if (!userRoundTickets) {
    userRoundTickets = new UserRoundTickets(userRoundTicketsId);
    userRoundTickets.user = user.id;
    userRoundTickets.round = round.id;
    userRoundTickets.numberOfTickets = event.params.numberOfTicketsBought;
    userRoundTickets.ticketNumbers = [];
  } else {
    userRoundTickets.numberOfTickets = userRoundTickets.numberOfTickets.plus(
      event.params.numberOfTicketsBought,
    );
  }
  let startingTicketNumber = event.params.startingTicketNumber;
  for (let i = 0 ; i < event.params.numberOfTicketsBought.toI32(); i++) {
    let tickets = userRoundTickets.ticketNumbers;
    tickets.push(startingTicketNumber.plus(BigInt.fromI32(i)));
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
