const { assert } = require('chai')
const { ethers } = require("hardhat");

const chai = require('chai')
    .use(require('chai-as-promised'))
    .should()

describe("Non-Dilutive Token", () => {
    before(async () => {
        [
            owner,
            address1,
            address2
        ] = await ethers.getSigners();

        priceInWei = "20000000000000000"

        MigratedContract = await ethers.getContractFactory("MockToken721");
        migratedContract = await MigratedContract.deploy(
            "migrate",
            "mgrt"
        )
        migratedContract = await migratedContract.deployed();

        MAX_SUPPLY = 900;
        Contract = await ethers.getContractFactory("NonDilutive721");
        contract = await Contract.deploy(
            "Non-Dilutive",
            "No-D",
            "ipfs://unrevealed/",
            "ipfs://generation-zero/",
            MAX_SUPPLY,
            migratedContract.address
        );

        contract = await contract.deployed();
    })

    it('Migrated contract deploys successfully.', async() => {
        address = migratedContract.address
        assert.notEqual(address, '')
        assert.notEqual(address, 0x0)
        assert.notEqual(address, null)
        assert.notEqual(address, undefined)
    });

    it('Mint migrated from token for testing', async() => {
        await migratedContract.connect(owner).mint(300)
        await migratedContract.connect(address1).mint(300)
        await migratedContract.connect(address2).mint(300)
    });

    // Note: In this test file we are calling all of these functions just for the sake of testing however in production the order of utilization will be:
    // 1. initialize2309() which is highly platform dependent
    // 2. if 2309 does not suffice, utilize initializeToOwners() as it 
    //    allows for simpler script creation. But, is limited by a large supply
    //    becoming too gassy to perform.
    // 3. initializeToCalldata() as the final callback which is for larger
    //    collection sizes however you need to take every precaution to not
    //    deploy an event to the wrong address.
    it('Initializing with EIP2309 event', async() => {
        await contract.initialize2309();
    })
    
    it('Initializing to target with EIP2309 event', async() => {
        await contract.initialize2309ToTarget(0, MAX_SUPPLY, owner.address);
    })
    
    it('Initializing with owners, single transfer events', async() => {
        await contract.initializeToOwners(0, MAX_SUPPLY);
    })

    it('Initializing with single transfer events', async() => {
        await contract.initialize(0, MAX_SUPPLY);
    })
    
    it('Initializing with calldata, single transfer events', async() => {
        var owners = [];
        for(var i =0; i<300; i++) {
            var wallet = await ethers.Wallet.createRandom();
            owners.push(wallet.address);
        }

        console.log(owners.length)

        await contract.initializeToCalldata(0, 300, owners);
        await contract.initializeToCalldata(300, 600, owners);
        await contract.initializeToCalldata(600, 900, owners);

    })

    it('Migrate to contract deploys successfully.', async() => {
        address = contract.address
        assert.notEqual(address, '')
        assert.notEqual(address, 0x0)
        assert.notEqual(address, null)
        assert.notEqual(address, undefined)
    });

    it('Migrate to contract has a name.', async() => {
        let name = await contract.name()
        assert.equal(name, 'Non-Dilutive')
    });

    it('Enable migration.', async() => {
        let name = await contract.name()
        assert.equal(name, 'Non-Dilutive')
    });

    it('Toggle migration', async() => { 
        await contract.toggleMigration();
    })

    it('Minting 1 in public sale.', async() => {
        await contract.connect(owner).migrate(1)
    });

    it('Minting 2 in public sale should fail when wrong owner calls it.', async() => {
        await contract.connect(address1).migrate(2).should.be.revertedWith("TokenOwnerMismatch()")
        await contract.connect(address2).migrate(2).should.be.revertedWith("TokenOwnerMismatch()")
    });

    it('Validate token uri', async () => { 
        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes("ipfs://unrevealed/"), true);
    });

    it('Reveal generation zero', async () => { 
        await contract.setRevealed(0, 500);
        await contract.setRevealed(0, 200).should.be.revertedWith('TokenRevealed');
    });

    it('Validate token uri after having revealed', async () => { 
        // get the base token id of this genreation
        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes(`ipfs://generation-zero/`), true);
    });

    it('Get token generation', async () => {
        generation = await contract.getTokenGeneration(1);
        assert.equal(generation.toString(), "0");
    });

    it('Reconnecting layer zero fails', async () => { 
        await hre.network.provider.request({method: "hardhat_impersonateAccount", params: [owner.address],});
        await contract.connect(owner).focusGeneration(0, 1).should.be.revertedWith("GenerationNotDifferent")
    });

    it("Connect generation 1", async () => { 
        await contract.loadGeneration(
            1,
            false,
            true,
            false,
            0,
            0,
            'ipfs://generation-one/'
        )
    });

    it("Connect reconnect generation 1", async () => { 
        await contract.loadGeneration(
            1,
            true,
            true,
            false,
            0,
            0,
            'ipfs://generation-one/'
        ).should.be.revertedWith('GenerationAlreadyLoaded')
    });

    it("Cannot focus generation 1 while disabled", async () => { 
        await hre.network.provider.request({method: "hardhat_impersonateAccount", params: [owner.address],});
        
        await contract.connect(owner).focusGeneration(1, 1).should.be.revertedWith("GenerationNotEnabled")
    });

    it("Enable generation 1", async () => { 
       await contract.toggleGeneration(1);
    });

    it("Disable generation 1 should fail", async () => { 
        await contract.toggleGeneration(1).should.be.revertedWith('GenerationNotToggleable');
    });

    it("Can now focus generation 1", async () => { 
        await hre.network.provider.request({method: "hardhat_impersonateAccount", params: [owner.address],});

        await contract.connect(owner).focusGeneration(1, 1)
    });

    it("Transfer token", async() => { 
        await contract.transferFrom(owner.address, address1.address, 200);
    })

    it("Transfer token fails from wrong owner", async() => { 
        await contract.transferFrom(owner.address, address1.address, 330).should.be.reverted;
    })

    it('Validate token uri is unrevealed after generation 1 upgrade', async () => { 
        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes("ipfs://unrevealed/"), true);
    });

    it("Can focus generation 0 after upgrading to generation 1", async () => { 
        await hre.network.provider.request({method: "hardhat_impersonateAccount", params: [owner.address],});
        
        await contract.connect(owner).focusGeneration(0, 1)

        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes(`ipfs://generation-zero/`), true);
    });

    it('Reveal generation 1 assets', async () => { 
        await contract.setRevealed(1, 500);
    });

    it("Can reenable generation 1", async () => { 
        await contract.connect(owner).focusGeneration(1, 1)

        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes(`ipfs://generation-one/`), true);
    })

    it("Load generation 2", async () => { 
        await contract.loadGeneration(
            2,
            true,
            true,
            true,
            '20000000000000000',
            0,
            'ipfs://generation-two/'
        )

        await contract.setRevealed(2, 500);
    });

    it("Focus generation 2 while paying", async () => { 
        await contract.connect(owner).focusGeneration(2, 1, { value: ethers.utils.parseEther("0.02")});

        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes(`ipfs://generation-two/`), true);
    });

    it("Cannot downgrade from generation 2", async () => {
        await contract.connect(owner).focusGeneration(1, 1).should.be.revertedWith('GenerationNotDowngradable')

        tokenUri = await contract.tokenURI(1);
        assert.equal(tokenUri.includes(`ipfs://generation-two/`), true);
    });

    it("Project owner cannot disable generation 2", async () => { 
        await contract.toggleGeneration(2).should.be.revertedWith('GenerationNotToggleable');
    });

    it("Can withdraw funds", async () => { 
        await contract.withdraw();
    });
})