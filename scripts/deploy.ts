import { ethers } from 'hardhat';

async function main() {


  const tokenAddress = "0x3e86294846F495213B35FdDedDC779753f372a83";
  const tokenDecimals = 18;
  const weth = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
  const uniswapv2Router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
  const uniswapv2Factory = "0x6725F303b657a9451d8BA641348b6761A6CC7a17";
  const teamWallet = "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B";
  const burnToken = false;
  const isWhitelist = false;


  const presale = await ethers.deployContract("Presale", [tokenAddress, tokenDecimals, weth, uniswapv2Router, uniswapv2Factory, teamWallet, burnToken, isWhitelist]);

  await presale.waitForDeployment();

  console.log("YourContractName deployed to:", presale.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
