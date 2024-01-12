import { ethers } from "hardhat";
import { SaleData } from "./data"

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

export const getOwnerFee = (hardCap: bigint) => {

}

export const wait = (ms: number) => {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export const getBlock = async () => {
  return await ethers.provider.getBlock('latest');
}