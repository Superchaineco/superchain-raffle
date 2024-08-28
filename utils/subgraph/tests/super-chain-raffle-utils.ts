import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  Claim,
  OwnershipTransferred,
  Paused,
  RoundWinners,
  TicketsPurchased,
  Unpaused
} from "../generated/SuperChainRaffle/SuperChainRaffle"

export function createClaimEvent(
  user: Address,
  amountEth: BigInt,
  amountOp: BigInt
): Claim {
  let claimEvent = changetype<Claim>(newMockEvent())

  claimEvent.parameters = new Array()

  claimEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  claimEvent.parameters.push(
    new ethereum.EventParam(
      "amountEth",
      ethereum.Value.fromUnsignedBigInt(amountEth)
    )
  )
  claimEvent.parameters.push(
    new ethereum.EventParam(
      "amountOp",
      ethereum.Value.fromUnsignedBigInt(amountOp)
    )
  )

  return claimEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent = changetype<OwnershipTransferred>(
    newMockEvent()
  )

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createPausedEvent(account: Address): Paused {
  let pausedEvent = changetype<Paused>(newMockEvent())

  pausedEvent.parameters = new Array()

  pausedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )

  return pausedEvent
}

export function createRoundWinnersEvent(
  round: BigInt,
  ticketsSold: BigInt,
  winningTickets: Array<BigInt>
): RoundWinners {
  let roundWinnersEvent = changetype<RoundWinners>(newMockEvent())

  roundWinnersEvent.parameters = new Array()

  roundWinnersEvent.parameters.push(
    new ethereum.EventParam("round", ethereum.Value.fromUnsignedBigInt(round))
  )
  roundWinnersEvent.parameters.push(
    new ethereum.EventParam(
      "ticketsSold",
      ethereum.Value.fromUnsignedBigInt(ticketsSold)
    )
  )
  roundWinnersEvent.parameters.push(
    new ethereum.EventParam(
      "winningTickets",
      ethereum.Value.fromUnsignedBigIntArray(winningTickets)
    )
  )

  return roundWinnersEvent
}

export function createTicketsPurchasedEvent(
  buyer: Address,
  startingTicketNumber: BigInt,
  numberOfTicketsBought: BigInt,
  round: BigInt
): TicketsPurchased {
  let ticketsPurchasedEvent = changetype<TicketsPurchased>(newMockEvent())

  ticketsPurchasedEvent.parameters = new Array()

  ticketsPurchasedEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  ticketsPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "startingTicketNumber",
      ethereum.Value.fromUnsignedBigInt(startingTicketNumber)
    )
  )
  ticketsPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "numberOfTicketsBought",
      ethereum.Value.fromUnsignedBigInt(numberOfTicketsBought)
    )
  )
  ticketsPurchasedEvent.parameters.push(
    new ethereum.EventParam("round", ethereum.Value.fromUnsignedBigInt(round))
  )

  return ticketsPurchasedEvent
}

export function createUnpausedEvent(account: Address): Unpaused {
  let unpausedEvent = changetype<Unpaused>(newMockEvent())

  unpausedEvent.parameters = new Array()

  unpausedEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )

  return unpausedEvent
}
