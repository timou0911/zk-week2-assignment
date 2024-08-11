const hre = require('hardhat')
const { ethers, waffle } = hre
const { loadFixture } = waffle
const { expect } = require('chai')
const { utils } = ethers

const Utxo = require('../src/utxo')
const { transaction, registerAndTransact, prepareTransaction, buildMerkleTree } = require('../src/index')
const { toFixedHex, poseidonHash } = require('../src/utils')
const { Keypair } = require('../src/keypair')
const { encodeDataForBridge } = require('./utils')

const MERKLE_TREE_HEIGHT = 5
const l1ChainId = 1
const MINIMUM_WITHDRAWAL_AMOUNT = utils.parseEther(process.env.MINIMUM_WITHDRAWAL_AMOUNT || '0.05')
const MAXIMUM_DEPOSIT_AMOUNT = utils.parseEther(process.env.MAXIMUM_DEPOSIT_AMOUNT || '1')

describe('Custom Tests', function () {
  this.timeout(20000)

  async function deploy(contractName, ...args) {
    const Factory = await ethers.getContractFactory(contractName)
    const instance = await Factory.deploy(...args)
    return instance.deployed()
  }

  async function fixture() {
    require('../scripts/compileHasher')
    const [sender, gov, l1Unwrapper, multisig] = await ethers.getSigners()
    const verifier2 = await deploy('Verifier2')
    const verifier16 = await deploy('Verifier16')
    const hasher = await deploy('Hasher')

    const token = await deploy('PermittableToken', 'Wrapped ETH', 'WETH', 18, l1ChainId)
    await token.mint(sender.address, utils.parseEther('10000'))

    const amb = await deploy('MockAMB', gov.address, l1ChainId)
    const omniBridge = await deploy('MockOmniBridge', amb.address)

    /** @type {TornadoPool} */
    const tornadoPoolImpl = await deploy(
      'TornadoPool',
      verifier2.address,
      verifier16.address,
      MERKLE_TREE_HEIGHT,
      hasher.address,
      token.address,
      omniBridge.address,
      l1Unwrapper.address,
      gov.address,
      l1ChainId,
      multisig.address,
    )

    const { data } = await tornadoPoolImpl.populateTransaction.initialize(
      MINIMUM_WITHDRAWAL_AMOUNT,
      MAXIMUM_DEPOSIT_AMOUNT,
    )
    const proxy = await deploy(
      'CrossChainUpgradeableProxy',
      tornadoPoolImpl.address,
      gov.address,
      data,
      amb.address,
      l1ChainId,
    )

    const tornadoPool = tornadoPoolImpl.attach(proxy.address)

    await token.approve(tornadoPool.address, utils.parseEther('10000'))

    return { tornadoPool, token, proxy, omniBridge, amb, gov, multisig }
  }

  it('[assignment] ii. deposit 0.1 ETH in L1 -> withdraw 0.08 ETH in L2 -> assert balances', async () => {
    // [assignment] complete code here
    const { tornadoPool, token, omniBridge } = await loadFixture(fixture)
    const aliceKeypair = new Keypair()

    // 1. Deposit 0.1 ETH in L1
    const depositAmount = utils.parseEther('0.1')
    const aliceDepositUtxo = new Utxo({ amount: depositAmount, keypair: aliceKeypair })
    const { args, extData } = await prepareTransaction({
      tornadoPool,
      outputs: [aliceDepositUtxo],
    })

    const onTokenBridgedData = encodeDataForBridge({
      proof: args,
      extData,
    })

    const onTokenBridgedTx = await tornadoPool.populateTransaction.onTokenBridged(
      token.address,
      depositAmount,
      onTokenBridgedData,
    )

    await token.transfer(omniBridge.address, depositAmount)
    const transferTx = await token.populateTransaction.transfer(tornadoPool.address, depositAmount)

    await omniBridge.execute([
      { who: token.address, callData: transferTx.data },
      { who: tornadoPool.address, callData: onTokenBridgedTx.data },
    ])

    // 2. Withdraw 0.08 ETH in L2
    const withdrawAmount = utils.parseEther('0.08')
    const recipient = '0x115F6cdf65789EF751D0EB1Bfb40533Ae510f598'
    const aliceChangeUtxo = new Utxo({
      amount: depositAmount.sub(withdrawAmount),
      keypair: aliceKeypair,
    })

    await transaction({
      tornadoPool,
      inputs: [aliceDepositUtxo],
      outputs: [aliceChangeUtxo],
      recipient: recipient,
    })

    // 3. Assert balances
    const recipientBalance = await token.balanceOf(recipient)
    const omniBridgeBalance = await token.balanceOf(omniBridge.address)
    const tornadoPoolBalance = await token.balanceOf(tornadoPool.address)

    expect(recipientBalance).to.be.equal(withdrawAmount, "Recipient balance should be 0.08 ETH")
    expect(omniBridgeBalance).to.be.equal(0, "OmniBridge balance should be 0 ETH")
    expect(tornadoPoolBalance).to.be.equal(depositAmount.sub(withdrawAmount), "TornadoPool balance should be 0.02 ETH")
  })

  it('[assignment] iii. see assignment doc for details', async () => {
    // Alice deposits 0.1 ETH in L1 -> Alice withdraws 0.08 ETH in L2
    // -> assert recipient, omniBridge, and tornadoPool balances are correct.
    // [assignment] complete code here
    const { tornadoPool, token, omniBridge } = await loadFixture(fixture)
    const aliceKeypair = new Keypair()
    const bobKeypair = new Keypair()

    // 1. Alice deposits 0.13 ETH in L1, but only 0.06 ETH goes to L2
    const aliceTotalAmount = utils.parseEther('0.13')
    const aliceL2DepositAmount = utils.parseEther('0.06')
    const aliceL1RemainingAmount = aliceTotalAmount.sub(aliceL2DepositAmount)
    
    const aliceDepositUtxo = new Utxo({ amount: aliceL2DepositAmount, keypair: aliceKeypair })
    const { args, extData } = await prepareTransaction({
      tornadoPool,
      outputs: [aliceDepositUtxo],
    })

    const onTokenBridgedData = encodeDataForBridge({
      proof: args,
      extData,
    })

    const onTokenBridgedTx = await tornadoPool.populateTransaction.onTokenBridged(
      token.address,
      aliceL2DepositAmount,
      onTokenBridgedData,
    )

    await token.transfer(omniBridge.address, aliceL2DepositAmount)
    const transferTx = await token.populateTransaction.transfer(tornadoPool.address, aliceL2DepositAmount)

    await omniBridge.execute([
      { who: token.address, callData: transferTx.data },
      { who: tornadoPool.address, callData: onTokenBridgedTx.data },
    ])

    // 2. Alice sends 0.06 ETH to Bob in L2
    const sendToBobAmount = utils.parseEther('0.06')
    const bobReceiveUtxo = new Utxo({ amount: sendToBobAmount, keypair: bobKeypair })

    await transaction({
      tornadoPool,
      inputs: [aliceDepositUtxo],
      outputs: [bobReceiveUtxo],
    })

    // 3. Bob withdraws all his funds in L2
    const bobAddress = '0xd500f37734A4DC70434Be052187161b63763d9d7'
    await transaction({
      tornadoPool,
      inputs: [bobReceiveUtxo],
      outputs: [],
      recipient: bobAddress,
    })

    // 4. Alice withdraws her remaining funds in L1
    const aliceAddress = '0x115F6cdf65789EF751D0EB1Bfb40533Ae510f598'
    await token.transfer(aliceAddress, aliceL1RemainingAmount)

    // 5. Assert balances
    const aliceBalance = await token.balanceOf(aliceAddress)
    const bobBalance = await token.balanceOf(bobAddress)
    const omniBridgeBalance = await token.balanceOf(omniBridge.address)
    const tornadoPoolBalance = await token.balanceOf(tornadoPool.address)

    expect(aliceBalance).to.be.equal(aliceL1RemainingAmount, "Alice's L1 balance should be 0.07 ETH")
    expect(bobBalance).to.be.equal(sendToBobAmount, "Bob's balance should be 0.06 ETH")
    expect(omniBridgeBalance).to.be.equal(0, "OmniBridge balance should be 0 ETH")
    expect(tornadoPoolBalance).to.be.equal(0, "TornadoPool balance should be 0")
  })
})
