const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LinearVesting contract", async function() {

    let LinearVesting;
    let linearVesting;
    let Token;
    let testToken;
    let owner;
    let addr1;
    let addr2;

    before(async function () {
        Token = await ethers.getContractFactory("Token");
        LinearVesting = await ethers.getContractFactory("MockLinearVesting");
    });

    beforeEach(async function() {
        // Get the Signers here
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy test token
        testToken = await Token.deploy("Test Token", "TT", 1000000);
        await testToken.deployed();

        // Deploy LinearVesting contract
        linearVesting = await LinearVesting.deploy();
    })
    
    describe("Deployment", async function() {
        it("Should assign the total supply of tokens to the owner", async function () {
            const ownerBalance = await testToken.balanceOf(owner.address);
            expect(await testToken.totalSupply()).to.equal(ownerBalance);
        });
    });
   
    describe("Vesting", async function() {

        describe("Deposit", async function() {
            it("Should fail if token address is zero", async function() {
                const zeroAddr = ethers.constants.AddressZero;
                // deposit tokens to vesting contract
                await expect(linearVesting.deposit(zeroAddr, 1000))
                .to.be.revertedWith("LinearVesting: token is zero address");
            });
    
            it("Should fail if token amount is zero", async function() {
                // deposit tokens to vesting contract
                await expect(linearVesting.deposit(testToken.address, 0))
                .to.be.revertedWith("LinearVesting: token amount is zero");
            });
    
            it("Should fail if token balance of user is not enough", async function() {
                // deposit tokens to vesting contract
                await expect(linearVesting.deposit(testToken.address, 2000000))
                .to.be.revertedWith("LinearVesting: user has not enough tokens");
            });
    
            it("Should fail if token balance of user is not enough", async function() {
                // deposit tokens to vesting contract
                await expect(linearVesting.deposit(testToken.address, 2000000))
                .to.be.revertedWith("LinearVesting: user has not enough tokens");
            });
    
            it("Should increase token balance of contract by deposited amount", async function() {
                // deposit tokens to vesting contract
                await testToken.approve(linearVesting.address, 1000);
                await expect(linearVesting.deposit(testToken.address, 1000))
                .to.emit(linearVesting, "TokenDeposited")
                .withArgs(owner.address, testToken.address, 1000);

                expect(await testToken.balanceOf(linearVesting.address))
                .to.be.equal(1000);
            });
    
            it("Should increase available token amount of user by deposited amount", async function() {
                // deposit tokens to vesting contract
                await testToken.approve(linearVesting.address, 1000);
                await expect(linearVesting.deposit(testToken.address, 1000))
                .to.emit(linearVesting, "TokenDeposited")
                .withArgs(owner.address, testToken.address, 1000);

                const tokenAmountByOwner = await linearVesting.getTokenAmountByUser(testToken.address);
                expect(tokenAmountByOwner).to.be.equal(1000);
            });
        });

        describe.only("Mint", async function() {
            beforeEach(async function() {
                // deposit tokens to vesting contract
                await testToken.approve(linearVesting.address, 1000);
                await linearVesting.deposit(testToken.address, 1000);
            })

            it("Should fail if token amount deposited by user is not enough", async function() {
            
                const amount = 10000;
                const time = 1000;

                // mint tokens to addr1
                await expect(linearVesting.mint(testToken.address, addr1.address, amount, time))
                .to.be.revertedWith("LinearVesting: cannot mint because user has not enough tokens");
            });

            it("Should fail if token address is zero", async function() {
                const amount = 100;
                const time = 1000;
                const zeroAddr = ethers.constants.AddressZero;

                // mint tokens to addr1
                await expect(linearVesting.mint(zeroAddr, addr1.address, amount, time))
                .to.be.revertedWith("LinearVesting: token is zero address");
            });
    
            it("Should fail if token amount is zero", async function() {
                const amount = 0;
                const time = 1000;

                // mint tokens to addr1
                await expect(linearVesting.mint(testToken.address, addr1.address, amount, time))
                .to.be.revertedWith("LinearVesting: token amount is zero");
            });
    
            it("Should fail if beneficiary address is zero", async function() {
                const amount = 100;
                const time = 1000;
                const zeroAddr = ethers.constants.AddressZero;

                // mint tokens to addr1
                await expect(linearVesting.mint(testToken.address, zeroAddr, amount, time))
                .to.be.revertedWith("LinearVesting: mint to the zero address");
            });
   
            it("Should decrease available token amount of user by minted amount", async function() {
                const amount = 100;
                const time = 1000;
                const tokenAmountByUserBefore = await linearVesting.getTokenAmountByUser(testToken.address);

                // mint tokens to addr1
                await linearVesting.mint(testToken.address, addr1.address, amount, time);
                const tokenAmountByUserAfter = await linearVesting.getTokenAmountByUser(testToken.address);
                expect(tokenAmountByUserBefore.sub(tokenAmountByUserAfter).toNumber())
                .to.be.equal(100);
            });

            it("Should increase schedule id by 1", async function() {
                const amount = 100;
                const time = 1000;
                const scheduleIDBefore = await linearVesting.getCurScheduleID();

                expect(scheduleIDBefore).to.be.equal(0);

                // mint tokens to addr1
                await linearVesting.mint(testToken.address, addr1.address, amount, time);
                const scheduleIDAfter = await linearVesting.getCurScheduleID();

                expect(scheduleIDAfter).to.be.equal(1);
            });

            it("Redeemable amount should increase by time passed", async function() {
                const amount = 100;
                const time = 1000;
                const baseTime = 1625097600;

                const scheduleID = await linearVesting.getCurScheduleID();

                await linearVesting.setCurrentTime(baseTime);

                // mint tokens to addr1
                await linearVesting.mint(testToken.address, addr1.address, amount, time);

                // check that vested amount is 0
                expect(
                    await linearVesting.connect(addr1.address).getRedeemableAmount(scheduleID)
                ).to.be.equal(0);

                // set time to half the vesting period
                const halfTime = baseTime + time / 2;
                await linearVesting.setCurrentTime(halfTime);

                // check that vested amount is half the total amount to vest
                expect(
                    await linearVesting.getRedeemableAmount(scheduleID)
                ).to.be.equal(50);

            });

            it("Should fail if someone but beneficiary try to redeem vested tokens", async function() {
                const amount = 100;
                const time = 1000;

                const scheduleID = await linearVesting.getCurScheduleID();

                // mint tokens to addr1
                await linearVesting.mint(testToken.address, addr1.address, amount, time);

                // Try to redeem by addr2
                await expect(linearVesting.connect(addr2).redeem(scheduleID))
                .to.be.revertedWith("LinearVesting: only beneficiary can redeem vested tokens");
            });

            it("Should redeem X tokens and emit TokenRedeemed event with a value of X", async function() {
                const amount = 100;
                const time = 1000;
                const baseTime = 1625097600;

                const scheduleID = await linearVesting.getCurScheduleID();

                await linearVesting.setCurrentTime(baseTime);

                // mint tokens to addr1
                await linearVesting.mint(testToken.address, addr1.address, amount, time);

                // should fail to mint tokens again
                await expect(linearVesting.mint(testToken.address, addr1.address, 901, time))
                .to.be.revertedWith("LinearVesting: cannot mint because user has not enough tokens");

                // set time to quater the vesting period
                const quaterTime = baseTime + time / 4;
                await linearVesting.setCurrentTime(quaterTime);

                // Redeem 25 tokens by addr1
                await expect(linearVesting.connect(addr1).redeem(scheduleID))
                .to.emit(linearVesting, "TokenRedeemed")
                .withArgs(addr1.address, 25);

                let vestingSchedule = await linearVesting.getVestingSchedule(scheduleID);

                // check that the redeemed amount is 25
                expect(vestingSchedule.redeemed).to.be.equal(25);

                // check that balance of addr1 is 25
                expect(await testToken.balanceOf(addr1.address)).to.be.equal(25);

                // set current time after the end of the vesting period
                await linearVesting.setCurrentTime(baseTime + time + 1);
                
                // Redeem 75 tokens by addr1
                await expect(linearVesting.connect(addr1).redeem(scheduleID))
                .to.emit(linearVesting, "TokenRedeemed")
                .withArgs(addr1.address, 75);
                
                vestingSchedule = await linearVesting.getVestingSchedule(scheduleID);

                // check that the number of released tokens is 100
                expect(vestingSchedule.redeemed).to.be.equal(100);

                // check that the vested amount is 0
                expect(
                    await linearVesting.getRedeemableAmount(scheduleID)
                ).to.be.equal(0);

                // check that balance of addr1 is 100
                expect(await testToken.balanceOf(addr1.address)).to.be.equal(100);
            });

        });

    });
    
});