export type SaleData = {
  saleRate: number;
  minBuy: number;
  maxBuy: number;
  softCap: number;
  hardCap: number;
  listingRate: number;
  liquidityPercent: number;
  lockTime: number;
  links: {
    logo: string;
    website: string;
    facebook: string;
    twitter: string;
    github: string;
    telegram: string;
    instagram: string;
    reddit: string;
    discord: string;
    description: string;
  }
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
    lockTime: 15,
    links: {
      logo: '',
      website: '',
      facebook: '',
      twitter: '',
      github: '',
      telegram: '',
      instagram: '',
      reddit: '',
      discord: '',
      description: '',
    }
  }
]

