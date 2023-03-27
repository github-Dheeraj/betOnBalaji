const hre = require("hardhat");
const { ethers } = require("hardhat")
async function main() {
    const verify = async (_adrs, _args) => {
        await hre.run("verify:verify", {
            address: _adrs,
            constructorArguments: [_args],
        });
    }
    let _wbtcAddress = "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6"
    let _priceFeed = "0xc907E116054Ad103354f2D350FD2514433D57F6f"
    let duration = 7776000

    const Contract = await ethers.getContractFactory('BetOnBalaji')
    const contract = await Contract.deploy(_wbtcAddress, _priceFeed, duration)
    await contract.deployed()
    console.log('NFT Contract deployed to:', contract.address)
    // await contract.deployed();
    await contract.deployTransaction.wait(8)

    await hre.run("verify:verify", {
        address: contract.address,
        constructorArguments: [_wbtcAddress, _priceFeed, duration],
    });
}
main()