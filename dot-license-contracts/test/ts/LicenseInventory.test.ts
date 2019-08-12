import * as chai from 'chai';
import BigNumber from 'bignumber.js';
import * as Web3 from 'web3';
import ethUtil = require('ethereumjs-util');
import { chaiSetup } from './utils/chai_setup';
import { Artifacts } from '../../util/artifacts';
import assertRevert from '../helpers/assertRevert';
import expectThrow from '../helpers/expectThrow';
import { duration } from '../helpers/increaseTime';

chaiSetup.configure();
const expect = chai.expect;
const { LicenseInventory } = new Artifacts(artifacts);
chai.should();

const web3: Web3 = (global as any).web3;

contract('LicenseInventory', (accounts: string[]) => {
  let licenseInventory: any = null;
  const creator = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];
  const owner = accounts[4];
  let p1Created: any;

  const firstProduct = {
    id: 1,
    price: 1000,
    initialInventory: 2,
    supply: 2,
    interval: 0
  };

  const secondProduct = {
    id: 2,
    price: 2000,
    initialInventory: 3,
    supply: 5,
    interval: duration.weeks(4)
  };

  const thirdProduct = {
    id: 3,
    price: 3000,
    initialInventory: 5,
    supply: 10,
    interval: duration.weeks(4)
  };

  beforeEach(async () => {
    licenseInventory = await LicenseInventory.new({ from: creator });
    await licenseInventory.transferOwnership(owner, { from: creator });

    p1Created = await licenseInventory.createProduct(
      firstProduct.id,
      firstProduct.price,
      firstProduct.initialInventory,
      firstProduct.supply,
      firstProduct.interval,
      { from: owner }
    );

    await licenseInventory.createProduct(
      secondProduct.id,
      secondProduct.price,
      secondProduct.initialInventory,
      secondProduct.supply,
      secondProduct.interval,
      { from: owner }
    );
  });

  describe('when creating products', async () => {
    it('should create the first product', async () => {
      const {
        price,
        inventory,
        totalSupply,
        interval,
        renewable
      } = await licenseInventory.productInfo(firstProduct.id);
      price.toNumber().should.equal(firstProduct.price);
      inventory.toNumber().should.equal(firstProduct.initialInventory);
      totalSupply.toNumber().should.equal(firstProduct.supply);
      interval.toNumber().should.equal(firstProduct.interval);
      renewable.should.be.false();
    });

    it('should create the second product', async () => {
      const {
        price,
        inventory,
        totalSupply,
        interval,
        renewable
      } = await licenseInventory.productInfo(secondProduct.id);
      price.toNumber().should.equal(secondProduct.price);
      inventory.toNumber().should.equal(secondProduct.initialInventory);
      totalSupply.toNumber().should.equal(secondProduct.supply);
      interval.toNumber().should.equal(secondProduct.interval);
      renewable.should.be.true();
    });

    it('should emit a ProductCreated event', async () => {
      const { logs } = p1Created;
      logs.length.should.be.equal(1);
      logs[0].event.should.be.eq('ProductCreated');
      logs[0].args.id.toString().should.be.equal(firstProduct.id.toString());
      logs[0].args.price.toString().should.be.equal(firstProduct.price.toString());
      logs[0].args.available.toString().should.be.equal(firstProduct.initialInventory.toString());
      logs[0].args.supply.toString().should.be.equal(firstProduct.supply.toString());
      logs[0].args.interval.toString().should.be.equal(firstProduct.interval.toString());
      logs[0].args.renewable.should.be.false();
    });

    it('should not create a product with the same id', async () => {
      await assertRevert(
        licenseInventory.createProduct(
          firstProduct.id,
          firstProduct.price,
          firstProduct.initialInventory,
          firstProduct.supply,
          firstProduct.interval,
          { from: owner }
        )
      );
    });
    it('should not create a product with more inventory than the total supply', async () => {
      await assertRevert(
        licenseInventory.createProduct(
          thirdProduct.id,
          thirdProduct.price,
          thirdProduct.supply + 1,
          thirdProduct.supply,
          thirdProduct.interval,
          { from: owner }
        )
      );
    });
    describe('and minding permissions', async () => {
      it('should not allow a rando to create a product', async () => {
        await assertRevert(
          licenseInventory.createProduct(
            thirdProduct.id,
            thirdProduct.price,
            thirdProduct.initialInventory,
            thirdProduct.supply,
            thirdProduct.interval,
            { from: user1 }
          )
        );
      });
    });
  });
  describe('when changing inventories', async () => {
    it('should increment the inventory', async () => {
      (await licenseInventory.availableInventoryOf(
        secondProduct.id
      )).toNumber().should.be.equal(3);
      await licenseInventory.incrementInventory(secondProduct.id, 2, { from: owner });
      (await licenseInventory.availableInventoryOf(
        secondProduct.id
      )).toNumber().should.be.equal(5);
    });
    it('should decrement the inventory', async () => {
      (await licenseInventory.availableInventoryOf(
        secondProduct.id
      )).toNumber().should.be.equal(3);
      await licenseInventory.decrementInventory(secondProduct.id, 3, { from: owner });
      (await licenseInventory.availableInventoryOf(
        secondProduct.id
      )).toNumber().should.be.equal(0);
    });

    describe('if the product does not exist', async () => {
      it('should not increment the inventory', async () => {
        await assertRevert(
          licenseInventory.incrementInventory(1298120398, 2, { from: owner })
        );
      });

      it('should not decrement the inventory', async () => {
        await assertRevert(
          licenseInventory.decrementInventory(1298120398, 2, { from: owner })
        );
      });
    });

    it('should not decrement below zero', async () => {
      await expectThrow(
        licenseInventory.decrementInventory(
          secondProduct.id,
          secondProduct.initialInventory + 1,
          { from: owner }
        )
      );
    });
    it('allow clearing inventory to zero', async () => {
      (await licenseInventory.availableInventoryOf(
        secondProduct.id
      )).toNumber().should.be.equal(3);
      await licenseInventory.clearInventory(secondProduct.id, { from: owner });
      (await licenseInventory.availableInventoryOf(
        secondProduct.id
      )).toNumber().should.be.equal(0);
    });
    it('should not allow setting the inventory greater than the total supply', async () => {
      await assertRevert(
        licenseInventory.incrementInventory(secondProduct.id, 3, { from: owner })
      );
    });
    it('should emit a ProductInventoryAdjusted event', async () => {
      const { logs } = await licenseInventory.incrementInventory(secondProduct.id, 2, {
        from: owner
      });
      logs.length.should.be.equal(1);
      logs[0].event.should.be.eq('ProductInventoryAdjusted');
      logs[0].args.productId.toNumber().should.be.equal(secondProduct.id);
      logs[0].args.available.toNumber().should.be.equal(secondProduct.initialInventory + 2);
    });
    describe('and minding permissions', async () => {
      it('should not allow a rando to change inventory', async () => {
        await assertRevert(
          licenseInventory.incrementInventory(secondProduct.id, 1, { from: user1 })
        );
      });
    });
  });
  describe('when changing prices', async () => {
    it('should change the price', async () => {
      (await licenseInventory.priceOf(secondProduct.id)).toNumber().should.be.equal(secondProduct.price);
      await licenseInventory.setPrice(secondProduct.id, 1234567, { from: owner });
      (await licenseInventory.priceOf(secondProduct.id)).toNumber().should.be.equal(1234567);
    });
    it('should not allow a rando to change the price', async () => {
      await assertRevert(licenseInventory.setPrice(secondProduct.id, 1, { from: user1 }));
    });
    it('should emit a ProductPriceChanged event', async () => {
      const { logs } = await licenseInventory.setPrice(secondProduct.id, 1234567, { from: owner });

      logs.length.should.be.equal(1);
      logs[0].event.should.be.eq('ProductPriceChanged');
      logs[0].args.productId.toNumber().should.be.equal(secondProduct.id);
      logs[0].args.price.toNumber().should.be.equal(1234567);
    });
  });

  describe('when changing renewable', async () => {
    describe('and an executive is changing renewable', async () => {
      it('should be allowed', async () => {
        (await licenseInventory.renewableOf(secondProduct.id)).should.be.true();
        await licenseInventory.setRenewable(secondProduct.id, false, { from: owner });
        (await licenseInventory.renewableOf(secondProduct.id)).should.be.false();
      });
      it('should emit a ProductRenewableChanged event', async () => {
        (await licenseInventory.renewableOf(secondProduct.id)).should.be.true();

        const { logs } = await licenseInventory.setRenewable(secondProduct.id, false, {
          from: owner
        });
        logs.length.should.be.equal(1);
        logs[0].event.should.be.eq('ProductRenewableChanged');
        logs[0].args.productId.toNumber().should.be.equal(secondProduct.id);
        logs[0].args.renewable.should.be.false();
      });
    });
    describe('and a rando is changing renewable', async () => {
      it('should not be allowed', async () => {
        await assertRevert(
          licenseInventory.setRenewable(secondProduct.id, false, { from: user1 })
        );
      });
    });
  });

  describe('when reading product information', async () => {
    it('should get all products that exist', async () => {
      const productIds = await licenseInventory.getAllProductIds();
      productIds[0].toNumber().should.be.equal(firstProduct.id);
      productIds[1].toNumber().should.be.equal(secondProduct.id);
    });

    describe('and calling costForProductCycles', async () => {
      it('should know the price for one cycle', async () => {
        const cost = (await licenseInventory.costForProductCycles(secondProduct.id, 1)).toNumber();
        cost.should.not.be.equal(0);
        cost.should.be.equal(secondProduct.price);
      });
      it('should know the price for two cycles', async () => {
        const cost = (await licenseInventory.costForProductCycles(secondProduct.id, 3)).toNumber();
        cost.should.not.be.equal(0);
        cost.should.be.equal(secondProduct.price * 3);
      });
    });
    describe('and calling isSubscriptionProduct', async () => {
      it('should be true for a subscription', async () => {
        (await licenseInventory.isSubscriptionProduct(secondProduct.id)).should.be.true();
      });
      it('should be false for a non-subscription', async () => {
        (await licenseInventory.isSubscriptionProduct(firstProduct.id)).should.be.false();
      });
    });
  });
});

///
