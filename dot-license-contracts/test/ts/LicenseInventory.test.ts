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
const { LicenseCoreTest } = new Artifacts(artifacts);
const LicenseCore = LicenseCoreTest;
chai.should();

const web3: Web3 = (global as any).web3;

contract('LicenseInventory', (accounts: string[]) => {
  let token: any = null;
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
    token = await LicenseCore.new({ from: creator });
    await token.transferOwnership(owner, { from: creator });

    p1Created = await token.createProduct(
      firstProduct.id,
      firstProduct.price,
      firstProduct.initialInventory,
      firstProduct.supply,
      firstProduct.interval,
      { from: owner }
    );

    await token.createProduct(
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
      const [
        price,
        inventory,
        supply,
        interval,
        renewable
      ] = await token.productInfo(firstProduct.id);
      price.toNumber().should.equal(firstProduct.price);
      inventory.toNumber().should.equal(firstProduct.initialInventory);
      supply.toNumber().should.equal(firstProduct.supply);
      interval.toNumber().should.equal(firstProduct.interval);
      renewable.should.be.false();
    });

    it('should create the second product', async () => {
      const [
        price,
        inventory,
        supply,
        interval,
        renewable
      ] = await token.productInfo(secondProduct.id);
      price.toNumber().should.equal(secondProduct.price);
      inventory.toNumber().should.equal(secondProduct.initialInventory);
      supply.toNumber().should.equal(secondProduct.supply);
      interval.toNumber().should.equal(secondProduct.interval);
      renewable.should.be.true();
    });

    it('should emit a ProductCreated event', async () => {
      const { logs } = p1Created;
      logs.length.should.be.equal(1);
      logs[0].event.should.be.eq('ProductCreated');
      logs[0].args.id.should.be.bignumber.equal(firstProduct.id);
      logs[0].args.price.should.be.bignumber.equal(firstProduct.price);
      logs[0].args.available.should.be.bignumber.equal(
        firstProduct.initialInventory
      );
      logs[0].args.supply.should.be.bignumber.equal(firstProduct.supply);
      logs[0].args.interval.should.be.bignumber.equal(firstProduct.interval);
      logs[0].args.renewable.should.be.false();
    });

    it('should not create a product with the same id', async () => {
      await assertRevert(
        token.createProduct(
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
        token.createProduct(
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
          token.createProduct(
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
      (await token.availableInventoryOf(
        secondProduct.id
      )).should.be.bignumber.equal(3);
      await token.incrementInventory(secondProduct.id, 2, { from: owner });
      (await token.availableInventoryOf(
        secondProduct.id
      )).should.be.bignumber.equal(5);
    });
    it('should decrement the inventory', async () => {
      (await token.availableInventoryOf(
        secondProduct.id
      )).should.be.bignumber.equal(3);
      await token.decrementInventory(secondProduct.id, 3, { from: owner });
      (await token.availableInventoryOf(
        secondProduct.id
      )).should.be.bignumber.equal(0);
    });

    describe('if the product does not exist', async () => {
      it('should not increment the inventory', async () => {
        await assertRevert(
          token.incrementInventory(1298120398, 2, { from: owner })
        );
      });

      it('should not decrement the inventory', async () => {
        await assertRevert(
          token.decrementInventory(1298120398, 2, { from: owner })
        );
      });
    });

    it('should not decrement below zero', async () => {
      await expectThrow(
        token.decrementInventory(
          secondProduct.id,
          secondProduct.initialInventory + 1,
          { from: owner }
        )
      );
    });
    it('allow clearing inventory to zero', async () => {
      (await token.availableInventoryOf(
        secondProduct.id
      )).should.be.bignumber.equal(3);
      await token.clearInventory(secondProduct.id, { from: owner });
      (await token.availableInventoryOf(
        secondProduct.id
      )).should.be.bignumber.equal(0);
    });
    it('should not allow setting the inventory greater than the total supply', async () => {
      await assertRevert(
        token.incrementInventory(secondProduct.id, 3, { from: owner })
      );
    });
    it('should emit a ProductInventoryAdjusted event', async () => {
      const { logs } = await token.incrementInventory(secondProduct.id, 2, {
        from: owner
      });
      logs.length.should.be.equal(1);
      logs[0].event.should.be.eq('ProductInventoryAdjusted');
      logs[0].args.productId.should.be.bignumber.equal(secondProduct.id);
      logs[0].args.available.should.be.bignumber.equal(
        secondProduct.initialInventory + 2
      );
    });
    describe('and minding permissions', async () => {
      it('should not allow a rando to change inventory', async () => {
        await assertRevert(
          token.incrementInventory(secondProduct.id, 1, { from: user1 })
        );
      });
    });
  });
  describe('when changing prices', async () => {
    it('should change the price', async () => {
      (await token.priceOf(secondProduct.id)).should.be.bignumber.equal(
        secondProduct.price
      );
      await token.setPrice(secondProduct.id, 1234567, { from: owner });
      (await token.priceOf(secondProduct.id)).should.be.bignumber.equal(
        1234567
      );
    });
    it('should not allow a rando to change the price', async () => {
      await assertRevert(token.setPrice(secondProduct.id, 1, { from: user1 }));
    });
    it('should emit a ProductPriceChanged event', async () => {
      const { logs } = await token.setPrice(secondProduct.id, 1234567, {
        from: owner
      });

      logs.length.should.be.equal(1);
      logs[0].event.should.be.eq('ProductPriceChanged');
      logs[0].args.productId.should.be.bignumber.equal(secondProduct.id);
      logs[0].args.price.should.be.bignumber.equal(1234567);
    });
  });

  describe('when changing renewable', async () => {
    describe('and an executive is changing renewable', async () => {
      it('should be allowed', async () => {
        (await token.renewableOf(secondProduct.id)).should.be.true();
        await token.setRenewable(secondProduct.id, false, { from: owner });
        (await token.renewableOf(secondProduct.id)).should.be.false();
      });
      it('should emit a ProductRenewableChanged event', async () => {
        (await token.renewableOf(secondProduct.id)).should.be.true();

        const { logs } = await token.setRenewable(secondProduct.id, false, {
          from: owner
        });
        logs.length.should.be.equal(1);
        logs[0].event.should.be.eq('ProductRenewableChanged');
        logs[0].args.productId.should.be.bignumber.equal(secondProduct.id);
        logs[0].args.renewable.should.be.false();
      });
    });
    describe('and a rando is changing renewable', async () => {
      it('should not be allowed', async () => {
        await assertRevert(
          token.setRenewable(secondProduct.id, false, { from: user1 })
        );
      });
    });
  });

  describe('when reading product information', async () => {
    it('should get all products that exist', async () => {
      const productIds = await token.getAllProductIds();
      productIds[0].should.be.bignumber.equal(firstProduct.id);
      productIds[1].should.be.bignumber.equal(secondProduct.id);
    });

    describe('and calling costForProductCycles', async () => {
      it('should know the price for one cycle', async () => {
        const cost = await token.costForProductCycles(secondProduct.id, 1);
        cost.should.not.be.bignumber.equal(0);
        cost.should.be.bignumber.equal(secondProduct.price);
      });
      it('should know the price for two cycles', async () => {
        const cost = await token.costForProductCycles(secondProduct.id, 3);
        cost.should.not.be.bignumber.equal(0);
        cost.should.be.bignumber.equal(secondProduct.price * 3);
      });
    });
    describe('and calling isSubscriptionProduct', async () => {
      it('should be true for a subscription', async () => {
        (await token.isSubscriptionProduct(secondProduct.id)).should.be.true();
      });
      it('should be false for a non-subscription', async () => {
        (await token.isSubscriptionProduct(firstProduct.id)).should.be.false();
      });
    });
  });
});

///
