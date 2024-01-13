import { expect } from "chai";
import { ethers, network } from "hardhat";
import { initSaleData } from "./data";
import { getBlock, toWei, tokensToDeposit } from "./utils";
import { Presale, Token } from '../typechain-types';

type PresaleContract = Presale
type TokenContract = Token

describe("Presale contract", function () {
  let token: TokenContract;
  let presale: PresaleContract;

  const presaleData = initSaleData[0];

  const ethRaised = async () => {
    return await presale.ethRaised();
  }

  const contributorBalance = async (address: string) => {
    return await presale.contributorBalance(address);
  }


  it("Should deploy Token contract", async function () {
    const [creator] = await ethers.getSigners();
    expect(creator).to.not.be.undefined;

    const tokenFactory = await ethers.getContractFactory("Token");
    const tokenCon = await tokenFactory.deploy();
    await tokenCon.waitForDeployment();
    token = tokenCon;
  });

  it("Should deploy Presale contract", async function () {
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

    const presaleFactory = await ethers.getContractFactory("Presale");
    const presaleCont = await presaleFactory.connect(creator).deploy(token.target, 18, weth, uniswapv2Router, uniswapv2Factory, teamWallet, launchpadOwner, burnToken, isWhitelist, pool);
    presale = presaleCont;
  });

  it("Should Approve tokens for Presale contract", async function () {
    expect(token).to.not.be.undefined;
    expect(presale).to.not.be.undefined;
    // approve token to presale contract
    const tokensToDepositForPresale = tokensToDeposit(presaleData);
    const approve = await token.approve(presale.target, toWei(tokensToDepositForPresale))
    await approve.wait();
  });

  it("Should deposit tokens", async function () {
    const [creator] = await ethers.getSigners();
    const deposit = await presale.connect(creator).deposit();
    await deposit.wait();

    const balance = await token.balanceOf(presale.target);
    const depositTokens = tokensToDeposit(presaleData);
    expect(balance).to.equal(toWei(depositTokens))
  });

  it("should wait for sale to start", async function () {
    // await wait(15 * 1000)
    network.provider.send("evm_increaseTime", [15])
    network.provider.send("evm_mine")
  })

  it("Should be contritbuted by users", async function () {
    const [creator, user1, user2, user3, user4] = await ethers.getSigners();

    const user1Con = await presale.connect(user1).buyTokens({ value: toWei(0.05) })
    await user1Con.wait();
    const user2Con = await presale.connect(user2).buyTokens({ value: toWei(0.05) })
    await user2Con.wait();
    const user3Con = await presale.connect(user3).buyTokens({ value: toWei(0.05) })
    await user3Con.wait();
    // const user4Con = await presale.connect(user4).buyTokens({ value: toWei(0.05) })
    // await user4Con.wait();

    const user1Balance = await contributorBalance(user1.address);
    expect(user1Balance).to.equal(toWei(0.05));
    const user2Balance = await contributorBalance(user2.address);
    expect(user2Balance).to.equal(toWei(0.05));
    const user3Balance = await contributorBalance(user3.address);
    expect(user3Balance).to.equal(toWei(0.05));
    // const user4Balance = await contributorBalance(user4.address);
    // expect(user4Balance).to.equal(toWei(0.05));

    // const totalContribution = await presale.ethRaised();
    // expect(totalContribution).to.equal(toWei(0.2));
  })

  it("Should wait for sale to end", async function () {
    network.provider.send("evm_increaseTime", [500])
    network.provider.send("evm_mine")
  })

  it("Should be finalized the sale", async function () {
    const [creator] = await ethers.getSigners();
    const finalize = await presale.connect(creator).finishSale();
    await finalize.wait();
  })

  it("Should be able to claim tokens", async function () {
    const [creator, user1, user2, user3, user4] = await ethers.getSigners();

    const user1Claim = await presale.connect(user1).claimTokens();
    await user1Claim.wait();

    const user2Claim = await presale.connect(user2).claimTokens();
    await user2Claim.wait();

    const user3Claim = await presale.connect(user3).claimTokens();
    await user3Claim.wait();

    // const user4Claim = await presale.connect(user4).claimTokens();
    // await user4Claim.wait();

    const user1TokenBalance = await token.balanceOf(user1.address);
    expect(user1TokenBalance).to.equal(toWei(50));

    const user2TokenBalance = await token.balanceOf(user2.address);
    expect(user2TokenBalance).to.equal(toWei(50));

    const user3TokenBalance = await token.balanceOf(user3.address);
    expect(user3TokenBalance).to.equal(toWei(50));

    // const user4TokenBalance = await token.balanceOf(user4.address);
    // expect(user4TokenBalance).to.equal(toWei(50));
  });

  it.skip("Should be alble to emergency withdraw", async function () {
    const [creator, user1] = await ethers.getSigners();
    const user1Withdraw = await presale.connect(user1).emergencyWithdraw();
    await user1Withdraw.wait();

    const user1ContributorBalance = await contributorBalance(user1.address);

    expect(user1ContributorBalance).to.equal(0);
  })

});

describe("Presale Contract with Canceled Sale and refund", function () {
  let token: TokenContract;
  let presale: PresaleContract;

  const presaleData = initSaleData[0];
  const contributorBalance = async (address: string) => {
    return await presale.contributorBalance(address);
  }

  it("Should deploy Token contract", async function () {
    const [creator] = await ethers.getSigners();
    expect(creator).to.not.be.undefined;

    const tokenFactory = await ethers.getContractFactory("Token");
    const tokenCon = await tokenFactory.deploy();
    await tokenCon.waitForDeployment();
    token = tokenCon;
  });

  it("Should deploy Presale contract", async function () {
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

    const presaleFactory = await ethers.getContractFactory("Presale");
    const presaleCont = await presaleFactory.connect(creator).deploy(token.target, 18, weth, uniswapv2Router, uniswapv2Factory, teamWallet, launchpadOwner, burnToken, isWhitelist, pool);
    presale = presaleCont;
  });

  it("Should Approve tokens for Presale contract", async function () {
    expect(token).to.not.be.undefined;
    expect(presale).to.not.be.undefined;
    // approve token to presale contract
    const tokensToDepositForPresale = tokensToDeposit(presaleData);
    const approve = await token.approve(presale.target, toWei(tokensToDepositForPresale))
    await approve.wait();
  });

  it("Should deposit tokens", async function () {
    const [creator] = await ethers.getSigners();
    const deposit = await presale.connect(creator).deposit();
    await deposit.wait();

    const balance = await token.balanceOf(presale.target);
    const depositTokens = tokensToDeposit(presaleData);
    expect(balance).to.equal(toWei(depositTokens))
  });

  it("should wait for sale to start", async function () {
    network.provider.send("evm_increaseTime", [15])
    network.provider.send("evm_mine")
  })

  it("Should be contritbuted by users", async function () {
    const [creator, user1, user2, user3, user4] = await ethers.getSigners();

    const user1Con = await presale.connect(user1).buyTokens({ value: toWei(0.05) })
    await user1Con.wait();
    const user2Con = await presale.connect(user2).buyTokens({ value: toWei(0.05) })
    await user2Con.wait();
    const user3Con = await presale.connect(user3).buyTokens({ value: toWei(0.05) })
    await user3Con.wait();

    const user1Balance = await contributorBalance(user1.address);
    expect(user1Balance).to.equal(toWei(0.05));
    const user2Balance = await contributorBalance(user2.address);
    expect(user2Balance).to.equal(toWei(0.05));
    const user3Balance = await contributorBalance(user3.address);
    expect(user3Balance).to.equal(toWei(0.05));
  })

  it("Should cancel the sale", async function () {
    const [creator] = await ethers.getSigners();
    const tokenBalanceBefore = await token.balanceOf(creator.address);
    const presaleTokenBalanceBefore = await token.balanceOf(presale.target);
    const cancelSale = await presale.connect(creator).cancelSale();
    await cancelSale.wait();

    const presaleTokenBalanceAfter = await token.balanceOf(presale.target);
    const tokenBalanceAfter = await token.balanceOf(creator.address);

    expect(presaleTokenBalanceAfter).to.equal(0);
    expect(tokenBalanceAfter).to.equal(tokenBalanceBefore + presaleTokenBalanceBefore);
  })

  it("Should be able to get refund", async function () {
    const [_, user1, user2, user3, user4] = await ethers.getSigners();

    const user1Con = await presale.connect(user1).refund();
    await user1Con.wait();

    const user2Con = await presale.connect(user2).refund();
    await user2Con.wait();

    const user3Con = await presale.connect(user3).refund();
    await user3Con.wait();

    await expect(presale.connect(user4).refund()).to.be.revertedWith("No refund available");

  })

  it("If user buy tokens after sale canceled, should be reverted", async function () {
    const [_, user1] = await ethers.getSigners();
    await expect(presale.connect(user1).buyTokens({ value: toWei(0.05) })).to.be.revertedWith("Sale must be active");
  })
})

describe("Presale Contract with Whitelist", function () {
  let token: TokenContract;
  let presale: PresaleContract;

  const presaleData = initSaleData[0];

  const contributorBalance = async (address: string) => {
    return await presale.contributorBalance(address);
  }

  it("Should deploy Token contract", async function () {
    const [creator] = await ethers.getSigners();
    expect(creator).to.not.be.undefined;

    const tokenFactory = await ethers.getContractFactory("Token");
    const tokenCon = await tokenFactory.deploy();
    await tokenCon.waitForDeployment();
    token = tokenCon;
  });

  it("Should deploy Presale contract", async function () {
    const [creator] = await ethers.getSigners();
    const weth = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
    const uniswapv2Router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
    const uniswapv2Factory = "0x6725F303b657a9451d8BA641348b6761A6CC7a17";
    const teamWallet = "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B";
    const launchpadOwner = "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B";
    const burnToken = false;
    const isWhitelist = true;

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

    const presaleFactory = await ethers.getContractFactory("Presale");
    const presaleCont = await presaleFactory.connect(creator).deploy(token.target, 18, weth, uniswapv2Router, uniswapv2Factory, teamWallet, launchpadOwner, burnToken, isWhitelist, pool);
    presale = presaleCont;
  });

  it("Should Approve tokens for Presale contract", async function () {
    expect(token).to.not.be.undefined;
    expect(presale).to.not.be.undefined;
    // approve token to presale contract
    const tokensToDepositForPresale = tokensToDeposit(presaleData);
    const approve = await token.approve(presale.target, toWei(tokensToDepositForPresale))
    await approve.wait();
  });

  it("Should deposit tokens", async function () {
    const [creator] = await ethers.getSigners();
    const deposit = await presale.connect(creator).deposit();
    await deposit.wait();

    const balance = await token.balanceOf(presale.target);
    const depositTokens = tokensToDeposit(presaleData);
    expect(balance).to.equal(toWei(depositTokens))
  });

  it("should wait for sale to start", async function () {
    network.provider.send("evm_increaseTime", [15])
    network.provider.send("evm_mine")
  })

  it("Not whitelisted user should not be able to buy tokens", async function () {
    const [_, user1] = await ethers.getSigners();
    await expect(presale.connect(user1).buyTokens({ value: toWei(0.05) }))
      .to.be.revertedWith("User not whitelisted");
  })

  it("Able to add single user to whitelist", async function () {
    const [creator, user1] = await ethers.getSigners();
    const addWhitelist = await presale.connect(creator).addWhitelist(user1.address);
    await addWhitelist.wait();

    expect((await presale.whitelists(user1.address))).to.be.true;
  })

  it("Able to add multiple users to whitelist", async function () {
    const [creator, _, user2, user3, user4] = await ethers.getSigners();

    const addWhitelist = await presale.connect(creator).addMultipleWhitelist([user2.address, user3.address, user4.address]);
    await addWhitelist.wait();

    expect((await presale.whitelists(user2.address))).to.be.true;
    expect((await presale.whitelists(user3.address))).to.be.true;
    expect((await presale.whitelists(user4.address))).to.be.true;
  })

  it("Whitelisted user should be able to buy tokens", async function () {
    const [_, user1, user2, user3, user4] = await ethers.getSigners();

    const user1Con = await presale.connect(user1).buyTokens({ value: toWei(0.05) })
    await user1Con.wait();
    const user2Con = await presale.connect(user2).buyTokens({ value: toWei(0.05) })
    await user2Con.wait();
    const user3Con = await presale.connect(user3).buyTokens({ value: toWei(0.05) })
    await user3Con.wait();
    const user4Con = await presale.connect(user4).buyTokens({ value: toWei(0.05) })
    await user4Con.wait();

    const user1Balance = await contributorBalance(user1.address);
    expect(user1Balance).to.equal(toWei(0.05));
    const user2Balance = await contributorBalance(user2.address);
    expect(user2Balance).to.equal(toWei(0.05));
    const user3Balance = await contributorBalance(user3.address);
    expect(user3Balance).to.equal(toWei(0.05));
    const user4Balance = await contributorBalance(user4.address);
    expect(user4Balance).to.equal(toWei(0.05));
  });

  it("Should wait for sale to end", async function () {
    network.provider.send("evm_increaseTime", [500])
    network.provider.send("evm_mine")
  })

  it("Should be finalized the sale", async function () {
    const [creator] = await ethers.getSigners();
    const finalize = await presale.connect(creator).finishSale();
    await finalize.wait();
  })

  it("Should be able to claim tokens", async function () {
    const [creator, user1, user2, user3, user4] = await ethers.getSigners();

    const user1Claim = await presale.connect(user1).claimTokens();
    await user1Claim.wait();

    const user2Claim = await presale.connect(user2).claimTokens();
    await user2Claim.wait();

    const user3Claim = await presale.connect(user3).claimTokens();
    await user3Claim.wait();

    const user4Claim = await presale.connect(user4).claimTokens();
    await user4Claim.wait();

    const user1TokenBalance = await token.balanceOf(user1.address);
    expect(user1TokenBalance).to.equal(toWei(50));

    const user2TokenBalance = await token.balanceOf(user2.address);
    expect(user2TokenBalance).to.equal(toWei(50));

    const user3TokenBalance = await token.balanceOf(user3.address);
    expect(user3TokenBalance).to.equal(toWei(50));

    const user4TokenBalance = await token.balanceOf(user4.address);
    expect(user4TokenBalance).to.equal(toWei(50));
  })

  it("Should be able to remove single user from whitelist", async function () {
    const [creator, user1] = await ethers.getSigners();
    const removeWhitelist = await presale.connect(creator).removeWhitelist(user1.address);
    await removeWhitelist.wait();

    expect((await presale.whitelists(user1.address))).to.be.false;
  });

  it("Should be able to remove multiple users from whitelist", async function () {
    const [creator, _, user2, user3, user4] = await ethers.getSigners();

    const removeWhitelist = await presale.connect(creator).removeMultipleWhitelist([user2.address, user3.address, user4.address]);
    await removeWhitelist.wait();

    expect((await presale.whitelists(user2.address))).to.be.false;
    expect((await presale.whitelists(user3.address))).to.be.false;
    expect((await presale.whitelists(user4.address))).to.be.false;
  })

  it("Not whitelisted user should not be able to buy tokens", async function () {
    const [_, user1] = await ethers.getSigners();
    await expect(presale.connect(user1).buyTokens({ value: toWei(0.05) }))
      .to.be.revertedWith('Sale must be active');
  })

  it("Should be able to off whitelist", async function () {
    const [creator] = await ethers.getSigners();

    const offWhitelist = await presale.connect(creator).setWhitelist(false);
    await offWhitelist.wait();

    expect((await presale.isWhitelist())).to.be.false;
  })

})

