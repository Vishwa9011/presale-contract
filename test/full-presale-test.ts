import { ethers } from "hardhat";
import { Presale, PresaleFactory, PresaleList, Token } from "../typechain-types"
import { getBlock, toWei, tokensToDeposit, wait } from "./utils";
import { initSaleData } from "./data";
import { expect } from "chai";


describe("Full Presale Test", function () {
  let token: Token;
  let presale: Presale;
  let presaleFactory: PresaleFactory;
  let presaleListing: PresaleList;

  const presaleData = initSaleData[0];
  this.beforeEach(async () => {
    // deploy presale list
    const presaleListCont = await ethers.deployContract("PresaleList");
    await presaleListCont.waitForDeployment();
    presaleListing = presaleListCont;

    // deploy factory
    const factoryCont = await ethers.deployContract("PresaleFactory", [presaleListing.target]);
    await factoryCont.waitForDeployment();
    presaleFactory = factoryCont;

    //add factory contract to whitelist in presale list
    const addWhitelistFactory = await presaleListCont.addWhitelist(presaleFactory.target);
    await addWhitelistFactory.wait();

    // deploy token
    const tokenCont = await ethers.deployContract("Token");
    await tokenCont.waitForDeployment();

    // approve token to presale contract
    const tokensToDepositForPresale = tokensToDeposit(presaleData);
    const approve = await tokenCont.approve(presaleFactory.target, toWei(tokensToDepositForPresale))
    await approve.wait();
    token = tokenCont;

    const [creator] = await ethers.getSigners();

    const timestampNow = (await getBlock())?.timestamp ?? 0;

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
    const txReceipt = await ethers.provider.getTransactionReceipt(createPresaleContract.hash);
    const events = txReceipt?.logs.map((log: any) => presaleFactory.interface.parseLog(log as any));
    const presaleCreatedEvent = events?.find((e: any) => e?.name === 'PresaleCreated');
    const presaleCont = await ethers.getContractAt("Presale", presaleCreatedEvent?.args.presaleAddress, creator);
    presale = presaleCont;
  })

  it("it should return presale data", async function () {
    const presalesData = await presaleListing.getPresales();
    console.log('presalesData: ', presalesData);
    expect(presalesData.length).to.be.equal(1);
  })
})