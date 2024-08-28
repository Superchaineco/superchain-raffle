import {
  OwnershipTransferred as OwnershipTransferredEvent,
  SuperchainRaffleCreated as SuperchainRaffleCreatedEvent
} from "../generated/SuperchainRaffleFactory/SuperchainRaffleFactory"
import {
  OwnershipTransferred,
  SuperchainRaffleCreated
} from "../generated/schema"

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSuperchainRaffleCreated(
  event: SuperchainRaffleCreatedEvent
): void {
  let entity = new SuperchainRaffleCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.superchainRaffle = event.params.superchainRaffle
  entity.uri = event.params.uri

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
