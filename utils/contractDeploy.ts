import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { Presale } from "../typechain-types";
import { PresaleFactory } from "../typechain-types";
import { DeploymentOptions, SaleData } from "./data";
import { time } from "@nomicfoundation/hardhat-network-helpers"
import { getPresaleAddressFromTx, toWei, tokensToDeposit } from "./utils";

const getPresaleDeployArgs = async (presaleData: SaleData, token: string, options?: DeploymentOptions) => {
  const timestampNow = await time.latest()

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
    tokenAddress: token,
    weth: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
    pinkLock: "0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5",
    teamWallet: "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B",
    launchpadOwner: "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B",
    uniswapv2Router: "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    uniswapv2Factory: "0x6725F303b657a9451d8BA641348b6761A6CC7a17",
    ...options
  }
  const links = presaleData.links;

  return { pool, presaleInfo, links }
}

export const createPresale = async (creator: Signer, presaleData: SaleData, token: string, presaleFactory: PresaleFactory) => {
  const { links, pool, presaleInfo } = await getPresaleDeployArgs(presaleData, token);

  const createPresaleContract = await presaleFactory.connect(creator).createPresale(presaleInfo, pool, links, { value: toWei(0.001) });
  const presaleAddress = await getPresaleAddressFromTx(createPresaleContract.hash, presaleFactory);
  const presaleCont = await ethers.getContractAt("Presale", presaleAddress, creator);
  return presaleCont
}

export const deployToken = async (creator: Signer) => {
  const tokenFactory = await ethers.getContractFactory("Token")
  const tokenCont = await tokenFactory.connect(creator).deploy();
  await tokenCont.waitForDeployment();
  return tokenCont;
}

export const approveTokenFor = async (creator: Signer, token: string, spender: string, presaleData: SaleData) => {
  const tokenCont = await ethers.getContractAt("Token", token, creator);
  const tokensToDepositForPresale = tokensToDeposit(presaleData);
  const approve = await tokenCont.approve(spender, toWei(tokensToDepositForPresale));

  // check allowance
  const allowance = await tokenCont.allowance((await creator.getAddress()), spender);
  expect(allowance).to.equal(toWei(tokensToDepositForPresale));

  await approve.wait();
}

export const deployPresaleList = async (creator: Signer) => {
  const presaleListFactory = await ethers.getContractFactory("PresaleList")
  const presaleListCont = await presaleListFactory.connect(creator).deploy();
  await presaleListCont.waitForDeployment();
  return presaleListCont;
}

export const deployPresaleFactory = async (creator: Signer, presaleList: string) => {
  const presaleFactoryFactory = await ethers.getContractFactory("PresaleFactory")
  const presaleFactoryCont = await presaleFactoryFactory.connect(creator).deploy(presaleList, toWei(0.001));
  await presaleFactoryCont.waitForDeployment();
  return presaleFactoryCont;
}

export const deployPresale = async (creator: Signer, presaleData: SaleData, token: string, presaleList: string, options?: DeploymentOptions) => {
  const { links, pool, presaleInfo } = await getPresaleDeployArgs(presaleData, token, options);

  const presaleFactory = await ethers.getContractFactory("Presale");
  const presaleCont = await presaleFactory.connect(creator).deploy(presaleInfo, pool, links, presaleList);
  await presaleCont.waitForDeployment();

  return presaleCont;
}
