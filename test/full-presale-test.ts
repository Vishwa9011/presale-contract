import { ethers } from "hardhat";
import { Presale, PresaleFactory, PresaleList, Token } from "../typechain-types"
import { getBlock, toWei, tokensToDeposit } from "./utils";
import { initSaleData } from "./data";



describe("Full Presale Test", function () {
  let token: Token;
  let presale: Presale;
  let presaleFactory: PresaleFactory;
  let presaleListing: PresaleList;

  const presaleData = initSaleData[0];
  this.beforeEach(async () => {
    const presaleListCont = await ethers.deployContract("PresaleList");
    await presaleListCont.waitForDeployment();
    presaleListing = presaleListCont;

    const factoryCont = await ethers.deployContract("PresaleFactory", [presaleListing.target]);
    await factoryCont.waitForDeployment();
    presaleFactory = factoryCont;

    const tokenCont = await ethers.deployContract("Token");
    await tokenCont.waitForDeployment();

    // approve token to presale contract
    const tokensToDepositForPresale = tokensToDeposit(presaleData);
    const approve = await tokenCont.approve(presaleFactory.target, toWei(tokensToDepositForPresale))
    await approve.wait();
    token = tokenCont;

    const [creator] = await ethers.getSigners();
    const weth = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const uniswapv2Router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
    const uniswapv2Factory = "0x6725F303b657a9451d8BA641348b6761A6CC7a17";
    const teamWallet = "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B";
    const launchpadOwner = "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B";
    const burnToken = false;
    const isWhitelist = false;

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
      lockPeriod: presaleData.lockTime,
    }

    const createPresaleContract = await presaleFactory.connect(creator).createPresale(token.target, 18, weth, uniswapv2Router, uniswapv2Factory, teamWallet, launchpadOwner, burnToken, isWhitelist, pool, { value: toWei(0.001) });
    const txReceipt = await ethers.provider.getTransactionReceipt(createPresaleContract.hash);
    const events = txReceipt?.logs.map((log: any) => presaleFactory.interface.parseLog(log as any));
    const presaleCreatedEvent = events?.find((e: any) => e?.name === 'PresaleCreated');
    const presaleCont = await ethers.getContractAt("Presale", presaleCreatedEvent?.args.presaleAddress, creator);
    presale = presaleCont;

  })



  it("User Should be able to buy, claim and emergency withdraw", async function () {
  })
})