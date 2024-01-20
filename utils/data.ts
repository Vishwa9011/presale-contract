import { Presale } from "../typechain-types";

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

export type DeploymentOptions = Pick<Presale.PresaleInfoStruct, 'isWhitelist'>;


export const initSaleData = [
  {
    saleRate: 1000,
    minBuy: 0.5,
    maxBuy: 1,
    softCap: 0.5,
    hardCap: 2,
    listingRate: 800,
    liquidityPercent: 60,
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

