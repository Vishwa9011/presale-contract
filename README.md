# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

```shell
npx hardhat run scripts/deploy.ts --network testnet
npx hardhat verify --network bsctest YOUR_CONTRACT_ADDRESS "Constructor argument 1" "Constructor argument 2"
npx hardhat verify --network testnet 0x8E4f565E7E4265bEc09B443fA98Dae8B86488575 "0xc8EcB4Bc9591F96882D88e55992b45621ef3a5B2" "18"

hardhat verify --network testnet 0x60AdC269E346AaBf2F24328712473933b90f406A "0x3e86294846F495213B35FdDedDC779753f372a83" "18" "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd" "0xD99D1c33F9fC3444f8101754aBC46c52416550D1" "0x6725F303b657a9451d8BA641348b6761A6CC7a17" "0xCa65Ee22787809f5B0B8F4639cFe117543EAb30B" "false" "false"
```

## Deployed Contract Address

// 0x07CEabcd37fCbbde4D19Aa9a973f5221226A9783

initSale =
saleRate = 1000

listingRate = 800

softCap = 50 ETH (in Wei)

hardCap = 200 ETH (in Wei)

minBuy = 0.1 ETH (in Wei)

maxBuy = 5 ETH (in Wei)

liquidityPercent = 60

lockPeriod = 180 days in seconds (180 \_ 24 \_ 60 \* 60)

uint64 \_startTime,
uint64 \_endTime,
uint8 \_liquidityPortion,
uint256 \_saleRate,
uint256 \_listingRate,
uint256 \_hardCap,
uint256 \_softCap,
uint256 \_maxBuy,
uint256 \_minBuy

const approvePresale = await token.connect(creator).approve(presale.address, BigInt(1000000000000\*(10\*\*18)));
await approvePresale.wait();

        const timestampNow = Math.floor(new Date().getTime()/1000);
        const initSale = await presale.connect(creator).initSale(timestampNow + 35, timestampNow + 450, 75, BigInt(70000000000 * (10**18)), BigInt(50000000000*(10**18)), BigInt(3000000000000000), BigInt(2000000000000000), BigInt(3000000000000000), BigInt(3000000000000));
        await initSale.wait();
        console.log('Sale initialized');
