import { ethers } from "hardhat";
import { PresaleFactory } from "../typechain-types";
import { SaleData } from "./data";


export function toWei(value: number): bigint {
  return ethers.parseEther(value.toString());
}

export const tokensToDeposit = (data: SaleData) => {
  return Number((tokensForSale(data) + tokensForLiquidity(data)).toFixed(5));
}

export const tokensForSale = (data: SaleData) => {
  return data.hardCap * data.saleRate;
}

export const tokensForLiquidity = (data: SaleData) => {
  const liquidityTokens = data.hardCap * data.listingRate * data.liquidityPercent / 100;
  return (liquidityTokens - (liquidityTokens * 5 / 100));
}

export const wait = (ms: number) => {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export const getBlock = async () => {
  return await ethers.provider.getBlock('latest');
}

export const getPresaleAddressFromTx = async (hash: string, presaleFactory: PresaleFactory) => {
  const txReceipt = await ethers.provider.getTransactionReceipt(hash);
  const events = txReceipt?.logs.map((log: any) => presaleFactory.interface.parseLog(log as any));
  const presaleCreatedEvent = events?.find((e: any) => e?.name === 'PresaleCreated');
  return presaleCreatedEvent?.args.presaleAddress;
}