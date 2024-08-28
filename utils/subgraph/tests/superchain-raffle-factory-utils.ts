import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  OwnershipTransferred,
  SuperchainRaffleCreated
} from "../generated/SuperchainRaffleFactory/SuperchainRaffleFactory"

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

export function createSuperchainRaffleCreatedEvent(
  superchainRaffle: Address,
  uri: string
): SuperchainRaffleCreated {
  let superchainRaffleCreatedEvent = changetype<SuperchainRaffleCreated>(
    newMockEvent()
  )

  superchainRaffleCreatedEvent.parameters = new Array()

  superchainRaffleCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "superchainRaffle",
      ethereum.Value.fromAddress(superchainRaffle)
    )
  )
  superchainRaffleCreatedEvent.parameters.push(
    new ethereum.EventParam("uri", ethereum.Value.fromString(uri))
  )

  return superchainRaffleCreatedEvent
}
