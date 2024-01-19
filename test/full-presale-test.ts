import { expect, } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers"
import { Presale, PresaleFactory, PresaleList, Token } from "../typechain-types"
import { approveTokenFor, createPresale, deployPresaleFactory, deployPresaleList, deployToken, initSaleData, toWei } from "../utils";


describe("Full Presale Test", function () {
  let token: Token;
  let presale: Presale;
  let presaleFactory: PresaleFactory;
  let presaleListing: PresaleList;

  const presaleData = initSaleData[0];

  const initNewPresaleWithToken = async (creator: Signer) => {
    // deploy token
    token = await deployToken(creator);

    // approve token for presale factory
    await approveTokenFor(creator, token.target.toString(), presaleFactory.target.toString(), presaleData)

    // deploy presale
    presale = await createPresale(creator, presaleData, token.target.toString(), presaleFactory);
  }

  this.beforeAll(async function () {
    const [creator] = await ethers.getSigners();
    // deploy presale List 
    presaleListing = await deployPresaleList(creator);

    // deploy presale factory
    presaleFactory = await deployPresaleFactory(creator, presaleListing.target.toString());

    await presaleListing.addWhitelist(presaleFactory.target.toString());
  });

  this.beforeEach(async function () {
    const [creator] = await ethers.getSigners();

    // init new presale with token
    await initNewPresaleWithToken(creator);
  })

  const contributorBalance = async (address: string) => {
    return await presale.contributorBalance(address);
  }

  it("Users should be able to wait for sale start, buytokens, wait for sale end,finalize sale, claim tokens", async function () {
    const [creator, user1, user2, user3, user4] = await ethers.getSigners();

    await time.increase(20);

    const user1Con = await presale.connect(user1).buyTokens({ value: toWei(0.05) })
    await user1Con.wait();
    const user2Con = await presale.connect(user2).buyTokens({ value: toWei(0.05) })
    await user2Con.wait();
    const user3Con = await presale.connect(user3).buyTokens({ value: toWei(0.05) })
    await user3Con.wait();

    const user1Balance = await contributorBalance(user1.address);
    expect(user1Balance).to.equal(toWei(0.05));
    const user2Balance = await contributorBalance(user2.address);
    expect(user2Balance).to.equal(toWei(0.05));
    const user3Balance = await contributorBalance(user3.address);
    expect(user3Balance).to.equal(toWei(0.05));

    await time.increase(500);

    const finalize = await presale.connect(creator).finishSale();
    await finalize.wait();

    const user1Claim = await presale.connect(user1).claimTokens();
    await user1Claim.wait();

    const user2Claim = await presale.connect(user2).claimTokens();
    await user2Claim.wait();

    const user3Claim = await presale.connect(user3).claimTokens();
    await user3Claim.wait();

    const user1TokenBalance = await token.balanceOf(user1.address);
    expect(user1TokenBalance).to.equal(toWei(50));

    const user2TokenBalance = await token.balanceOf(user2.address);
    expect(user2TokenBalance).to.equal(toWei(50));

    const user3TokenBalance = await token.balanceOf(user3.address);
    expect(user3TokenBalance).to.equal(toWei(50));


    // can get the user contributions
    await initNewPresaleWithToken(user1);

    await time.increase(20);

    const user2Cont2 = await presale.connect(user2).buyTokens({ value: toWei(0.05) });
    await user2Cont2.wait();


    const getUser2Contribution = await presaleListing.getPresaleContributions(user2.address);
    expect(getUser2Contribution.length).to.equal(2);
  })

})