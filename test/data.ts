export type SaleData = {
  saleRate: number;
  minBuy: number;
  maxBuy: number;
  softCap: number;
  hardCap: number;
  listingRate: number;
  liquidityPercent: number;
}

export const initSaleData = [
  {
    saleRate: 1000,
    minBuy: 0.01,
    maxBuy: 0.1,
    softCap: 0.05,
    hardCap: 0.2,
    listingRate: 899,
    liquidityPercent: 51,
    lockTime: 15
  }
]

