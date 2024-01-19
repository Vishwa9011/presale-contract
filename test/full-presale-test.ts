import { ethers } from "hardhat";
import { Presale, PresaleFactory, PresaleList, Token } from "../typechain-types"
import { getBlock, getPresaleAddressFromTx, toWei, tokensToDeposit, wait } from "./utils";
import { initSaleData } from "./data";
import { expect, } from "chai";
import { time } from "@nomicfoundation/hardhat-network-helpers"
import { Signer } from "ethers";



describe("Full Presale Test", function () {
  let token: Token;
  let presale: Presale;
  let presaleFactory: PresaleFactory;
  let presaleListing: PresaleList;

  const createPresale = async (creator: Signer) => {
    console.log("token", token.target);
    const timestampNow = await time.latest();
    const pool: Presale.PoolStruct = {
      saleRate: toWei(presaleData.saleRate),
      listingRate: toWei(presaleData.listingRate),
      softCap: toWei(presaleData.softCap),
      hardCap: toWei(presaleData.hardCap),
      minBuy: toWei(presaleData.minBuy),
      maxBuy: toWei(presaleData.maxBuy),
      liquidityPercent: presaleData.liquidityPercent,
      startTime: timestampNow + 10,
      endTime: timestampNow + 450,
      lockPeriod: presaleData.lockTime
    }

    const presaleInfo: Presale.PresaleInfoStruct = {
      burnToken: false,
      tokenDecimals: 18,
      isWhitelist: false,
      tokenAddress: token.target,
      weth: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
      pinkLock: "0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5",
      teamWallet: "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B",
      launchpadOwner: "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B",
      uniswapv2Router: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
      uniswapv2Factory: "0x6725F303b657a9451d8BA641348b6761A6CC7a17",
    }

    const createPresaleContract = await presaleFactory.connect(creator).createPresale(presaleInfo, pool, presaleData.links, { value: toWei(0.001) });
    const presaleAddress = await getPresaleAddressFromTx(createPresaleContract.hash, presaleFactory);
    const presaleCont = await ethers.getContractAt("Presale", presaleAddress, creator);
    presale = presaleCont
  }

  const deployTokenAndApproveFactory = async (creator: Signer) => {
    // deploy token
    const tokenFactory = await ethers.getContractFactory("Token")
    const tokenCont = await tokenFactory.connect(creator).deploy();
    await tokenCont.waitForDeployment();

    // approve token to presale contract
    const tokensToDepositForPresale = tokensToDeposit(presaleData);
    const approve = await tokenCont.approve(presaleFactory.target, toWei(tokensToDepositForPresale))
    await approve.wait();

    const allowance = await tokenCont.allowance((await creator.getAddress()), presaleFactory.target);
    expect(allowance).to.equal(toWei(tokensToDepositForPresale));
    token = tokenCont;
  }

  const presaleData = initSaleData[0];
  this.beforeEach(async () => {
    // deploy presale list
    const presaleListCont = await ethers.deployContract("PresaleList");
    await presaleListCont.waitForDeployment();
    presaleListing = presaleListCont;

    // deploy factory
    const factoryCont = await ethers.deployContract("PresaleFactory", [presaleListing.target, toWei(0.001)]);
    await factoryCont.waitForDeployment();
    presaleFactory = factoryCont;

    //add factory contract to whitelist in presale list
    const addWhitelistFactory = await presaleListCont.addWhitelist(presaleFactory.target);
    await addWhitelistFactory.wait();

    const [creator] = await ethers.getSigners();

    // deploy token and approve factory
    await deployTokenAndApproveFactory(creator);
    // create presale
    await createPresale(creator);
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
    await deployTokenAndApproveFactory(user1)
    await createPresale(user1);

    await time.increase(20);

    const user2Cont2 = await presale.connect(user2).buyTokens({ value: toWei(0.05) });
    await user2Cont2.wait();


    const getUser2Contribution = await presaleListing.getPresaleContributions(user2.address);
    console.log('getUser2Contribution: ', getUser2Contribution);
    expect(getUser2Contribution.length).to.equal(2);

  })

})