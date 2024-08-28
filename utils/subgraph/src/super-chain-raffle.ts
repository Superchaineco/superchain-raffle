import {
  Claim as ClaimEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  Paused as PausedEvent,
  RoundWinners as RoundWinnersEvent,
  TicketsPurchased as TicketsPurchasedEvent,
  Unpaused as UnpausedEvent,
} from "../generated/SuperChainRaffle/SuperChainRaffle"
import {
  Claim,
  OwnershipTransferred,
  Paused,
  RoundWinners,
  TicketsPurchased,
  Unpaused,
} from "../generated/schema"

export function handleClaim(event: ClaimEvent): void {
  let entity = new Claim(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.user = event.params.user
  entity.amountEth = event.params.amountEth
  entity.amountOp = event.params.amountOp

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent,
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePaused(event: PausedEvent): void {
  let entity = new Paused(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.account = event.params.account

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRoundWinners(event: RoundWinnersEvent): void {
  let entity = new RoundWinners(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.round = event.params.round
  entity.ticketsSold = event.params.ticketsSold
  entity.winningTickets = event.params.winningTickets

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTicketsPurchased(event: TicketsPurchasedEvent): void {
  let entity = new TicketsPurchased(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.buyer = event.params.buyer
  entity.startingTicketNumber = event.params.startingTicketNumber
  entity.numberOfTicketsBought = event.params.numberOfTicketsBought
  entity.round = event.params.round

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUnpaused(event: UnpausedEvent): void {
  let entity = new Unpaused(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.account = event.params.account

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
