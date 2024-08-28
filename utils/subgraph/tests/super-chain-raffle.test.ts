import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { Claim } from "../generated/schema"
import { Claim as ClaimEvent } from "../generated/SuperChainRaffle/SuperChainRaffle"
import { handleClaim } from "../src/super-chain-raffle"
import { createClaimEvent } from "./super-chain-raffle-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let user = Address.fromString("0x0000000000000000000000000000000000000001")
    let amountEth = BigInt.fromI32(234)
    let amountOp = BigInt.fromI32(234)
    let newClaimEvent = createClaimEvent(user, amountEth, amountOp)
    handleClaim(newClaimEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("Claim created and stored", () => {
    assert.entityCount("Claim", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "Claim",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "user",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "Claim",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "amountEth",
      "234"
    )
    assert.fieldEquals(
      "Claim",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "amountOp",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
