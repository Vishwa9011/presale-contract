import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const Creator = "0x65ee15d2f130dd35f78d06d3b30ecbfa9d7c693835ba0672e2a489d85e2e2664";
const PRIVATE_KEY = "0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e";
const PRIVATE_KEY1 = "0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0";
const PRIVATE_KEY2 = "0x689af8efa8c651a91ad287602527f3af2fe9f6501a7ac4b061667b5a93e037fd";
const PRIVATE_KEY3 = "0xea6c44ac03bff858b476bba40716402b03e41b8e97e276d1baec7c37d42484a0";
const PRIVATE_KEY4 = "0x8166f546bab6da521a8369cab06c5d2b9e46670292d85c875ee9ec20e84ffb61";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  // defaultNetwork: "testnet",
  networks: {
    hardhat: {
      forking: {
        url: "https://bsc-testnet.publicnode.com",
      },
      chainId: 97,
      accounts: [
        { privateKey: PRIVATE_KEY, balance: "100000000000000000000" },
        { privateKey: PRIVATE_KEY1, balance: "100000000000000000000" },
        { privateKey: PRIVATE_KEY2, balance: "100000000000000000000" },
        { privateKey: PRIVATE_KEY3, balance: "100000000000000000000" },
        { privateKey: PRIVATE_KEY4, balance: "100000000000000000000" },
      ]
    },
    testnet: {
      url: "https://dark-yolo-shape.bsc-testnet.quiknode.pro/77c9ff31030ff95667403e0a795ba837a6ff5b60/",
      accounts: [Creator]
    }
  },
  etherscan: {
    apiKey: "6YDFAYUUN8DWR7H9YEWSAWJCBAMYTTVVAI"
  },
  sourcify: {
    enabled: true
  }
};

export default config;
