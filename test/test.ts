import { expect } from "chai";
import { ethers } from "hardhat";
import { initSaleData } from "./data";
import { tokensToDeposit } from "./utils";

function toWei(value: number): bigint {
  return ethers.parseEther(value.toString());
}

describe("Presale contract", function () {
  let token: any;
  let presale: any;
  let tokenAddress: string;

  const presaleData = initSaleData[0]

  it("Should deploy Token contract", async function () {
    const [creator] = await ethers.getSigners();
    expect(creator).to.not.be.undefined;

    const tokenFactory = await ethers.getContractFactory("Token");
    const tokenCon = await tokenFactory.deploy();
    await tokenCon.waitForDeployment();
    tokenAddress = tokenCon.target as string;
    token = tokenCon;
  });

  it("Should deploy Presale contract", async function () {
    const weth = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const uniswapv2Router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
    const uniswapv2Factory = "0x6725F303b657a9451d8BA641348b6761A6CC7a17";
    const teamWallet = "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B";
    const burnToken = false;
    const isWhitelist = false;

    const presaleFactory = await ethers.getContractFactory("Presale");
    const presaleCon = await presaleFactory.deploy(tokenAddress, 18, weth, uniswapv2Router, uniswapv2Factory, teamWallet, burnToken, isWhitelist);
    await presaleCon.waitForDeployment();
    presale = presaleCon;
  });

  it("Should Approve tokens for Presale contract", async function () {
    expect(token).to.not.be.undefined;
    expect(presale).to.not.be.undefined;
    const [creator] = await ethers.getSigners();
    const approve = await token.connect(creator).approve(presale.target, toWei(1000));
    await approve.wait();
  });

  it("Should initialize the sale", async function () {
    const [creator] = await ethers.getSigners();
    const timestampNow = Math.floor(Date.now() / 1000);
    const initSale = await presale.connect(creator).initSale(timestampNow + 35, timestampNow + 450, toWei(presaleData.saleRate), toWei(presaleData.listingRate), toWei(presaleData.softCap), toWei(presaleData.hardCap), toWei(presaleData.minBuy), toWei(presaleData.maxBuy), presaleData.liquidityPercent, 10);
    await initSale.wait();
  });

  it("Should deposit tokens", async function () {
    const [creator] = await ethers.getSigners();
    const deposit = await presale.connect(creator).deposit();
    await deposit.wait();

    const balance = await token.balanceOf(presale.target);
    const depositTokens = tokensToDeposit(presaleData);
    expect(balance).to.equal(toWei(depositTokens))
  });


});
