import * as chai from 'chai';
import BigNumber from 'bignumber.js';
import * as Web3 from 'web3';
import ethUtil = require('ethereumjs-util');
import { chaiSetup } from './utils/chai_setup';
import { Artifacts } from '../../util/artifacts';
import assertRevert from '../helpers/assertRevert';
import expectThrow from '../helpers/expectThrow';
import eventByName from '../helpers/eventByName';
import { duration } from '../helpers/increaseTime';
import * as Bluebird from 'bluebird';

import increaseTime from '../helpers/increaseTime';

chaiSetup.configure();
const expect = chai.expect;
const { LicenseCoreTest, SaleStore, LicenseInventory } = new Artifacts(artifacts);
const LicenseCore = LicenseCoreTest;

const { ERC20 } = new Artifacts(artifacts);
chai.should();

const web3: Web3 = (global as any).web3;
const web3Eth: any = Bluebird.promisifyAll(web3.eth);

const latestTime = async () => {
  const block = await web3Eth.getBlockAsync('latest');
  return block.timestamp;
};

contract('SaleStore', (accounts: string[]) => {
  let token: any = null;
  let daiContract: any = null;
  let licenseSale: any = null;
  let licenseInventory: any = null;
  const creator = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];
  const owner = accounts[4];
  let p1Created: any;
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

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
    // DAI contract
    daiContract = await ERC20.new({ from: owner });
    await daiContract.transfer(user1, 100000, { from: owner });
    await daiContract.transfer(user2, 100000, { from: owner });
    await daiContract.transfer(user3, 100000, { from: owner });

    // Ownership contract
    token = await LicenseCore.new({ from: creator });
    await token.transferOwnership(owner, { from: creator });

    // Sale contract
    licenseSale = await SaleStore.new({ from: creator })
    await licenseSale.transferOwnership(owner, { from: creator })
    await licenseSale.setDAIContract(daiContract.address, { from: owner })

    // Inventory contract
    licenseInventory = await LicenseInventory.new({ from: creator })
    await licenseInventory.transferOwnership(owner, { from: creator })
    await licenseInventory.setSaleController(licenseSale.address, { from: owner })

    await licenseSale.setInventoryContract(licenseInventory.address, { from: owner })
    await licenseSale.setOwnershipContract(token.address, { from: owner })
    await token.setSaleController(licenseSale.address, { from: owner })

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

    await licenseInventory.createProduct(
      thirdProduct.id,
      thirdProduct.price,
      thirdProduct.initialInventory,
      thirdProduct.supply,
      thirdProduct.interval,
      { from: owner }
    );
  });

  describe('when purchasing', async () => {
    describe('it should fail because it', async () => {
      it('should not sell a product that has no inventory', async () => {
        await licenseInventory.clearInventory(firstProduct.id, { from: owner });
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
      it('should not sell a product that was sold out', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        await licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 });
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user2 });
        await licenseSale.purchase(firstProduct.id, 1, user2, ZERO_ADDRESS, { from: user2 });
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user3 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 1, user3, ZERO_ADDRESS, { from: user3 })
        );
        (await token.totalSold(firstProduct.id)).should.be.bignumber.equal(2);
        (await token.availableInventoryOf(firstProduct.id)).should.be.bignumber.equal(0);
      });
      it('should not sell at a price too low', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price - 1, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 })
        );
        await daiContract.approve(licenseSale.address, 0, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
      it('should not sell at a price too high', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price + 1, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
      it('should not sell if the contract is paused', async () => {
        await token.pause({ from: owner });
        await daiContract.approve(licenseSale.address, firstProduct.price + 1, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 })
        );
      });

      it('should not sell any product for 0 cycles', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 0, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
      it('should not sell a non-subscription product for more cycles than 1', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        await assertRevert(
          licenseSale.purchase(firstProduct.id, 2, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
      it('should not sell a subscription for a value less than the number of cycles requires', async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
        await assertRevert(
          licenseSale.purchase(secondProduct.id, 2, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
      it('should not sell a subscription for a value more than the number of cycles requires', async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price * 2 + 1, { from: user1 });
        await assertRevert(
          licenseSale.purchase(secondProduct.id, 2, user1, ZERO_ADDRESS, { from: user1 })
        );
      });
    });

    describe('and it succeeds as a non-subscription', async () => {
      let tokenId: any;
      let issuedEvent: any;

      beforeEach(async () => {
        let test = await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        const { logs } = await licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 });
        issuedEvent = eventByName(logs, 'LicenseIssued');
        tokenId = issuedEvent.args.licenseId;
      });

      it('should decrement the inventory', async () => {
        (await token.availableInventoryOf(
          firstProduct.id
        )).should.be.bignumber.equal(1);
      });

      it('should track the number sold', async () => {
        (await token.totalSold(firstProduct.id)).should.be.bignumber.equal(1);
      });

      describe('the resulting License', async () => {
        it('should keep track of the license id', async () => {
          const owner = await token.ownerOf(tokenId);
          owner.should.be.equal(user1);
        });

        it('should fetch licenseInfo', async () => {
          const [
            productId,
            attributes,
            issuedTime,
            expirationTime,
            affiliate
          ] = await token.licenseInfo(tokenId);
          productId.should.be.bignumber.equal(firstProduct.id);
          attributes.should.not.be.bignumber.equal(0);
          issuedTime.should.not.be.bignumber.equal(0);
          expirationTime.should.be.bignumber.equal(0);
          affiliate.should.be.bignumber.equal(0);
        });

        it('should emit an Issued event', async () => {
          issuedEvent.args.owner.should.be.eq(user1);
          issuedEvent.args.licenseId.should.be.bignumber.equal(tokenId);
          issuedEvent.args.productId.should.be.bignumber.equal(firstProduct.id);
        });

        it('should have an issued time', async () => {
          const issuedTime = await token.licenseIssuedTime(tokenId);
          issuedTime.should.not.be.bignumber.equal(0);
        });

        it('should have attributes', async () => {
          const attributes = await token.licenseAttributes(tokenId);
          attributes.should.not.be.bignumber.equal(0);
        });

        it('should be able to find the product id', async () => {
          const productId = await token.licenseProductId(tokenId);
          productId.should.be.bignumber.equal(firstProduct.id);
        });

        it('should not have an expiration time', async () => {
          const productId = await token.licenseExpirationTime(tokenId);
          productId.should.be.bignumber.equal(0);
        });

        it('should not have an affiliate', async () => {
          const productId = await token.licenseAffiliate(tokenId);
          productId.should.be.bignumber.equal(ZERO_ADDRESS);
        });

        it('should transfer the license to the new owner', async () => {
          const originalOwner = await token.ownerOf(tokenId);
          originalOwner.should.be.equal(user1);

          await token.transfer(user3, tokenId, { from: user1 });
          const newOwner = await token.ownerOf(tokenId);
          newOwner.should.be.equal(user3);

          const productId = await token.licenseProductId(tokenId);
          productId.should.be.bignumber.equal(firstProduct.id);
        });

        it('should set an expiration time of 0', async () => {
          const expirationTime = await token.licenseExpirationTime(tokenId);
          expirationTime.should.be.bignumber.equal(0);
        });
      });
    });

    describe('and it succeeds as a subscription', async () => {
      let tokenId: any;
      let issuedEvent: any;

      beforeEach(async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
        const { logs } = await licenseSale.purchase(
          secondProduct.id,
          1,
          user1,
          ZERO_ADDRESS,
          {
            from: user1
            // value: secondProduct.price
          }
        );
        issuedEvent = eventByName(logs, 'LicenseIssued');
        tokenId = issuedEvent.args.licenseId;
      });

      it('should set an appropriate expiration time', async () => {
        let now = await latestTime();
        let expectedTime = now + secondProduct.interval;
        let actualTime = await token.licenseExpirationTime(tokenId);
        actualTime.should.be.bignumber.equal(expectedTime);
      });
      it('should allow buying for multiple cycles', async () => {
        await daiContract.approve(licenseSale.address, thirdProduct.price * 3, { from: user1 });
        const { logs } = await licenseSale.purchase(
          thirdProduct.id,
          3,
          user1,
          ZERO_ADDRESS,
          {
            from: user1
            // value: thirdProduct.price * 3
          }
        );
        issuedEvent = eventByName(logs, 'LicenseIssued');
        tokenId = issuedEvent.args.licenseId;

        let now = await latestTime();
        let expectedTime = now + thirdProduct.interval * 3;
        let actualTime = await token.licenseExpirationTime(tokenId);
        actualTime.should.be.bignumber.equal(expectedTime);
      });
    });
  });

  describe('when creating a promotional purchase', async () => {
    describe('if a rando is trying it', async () => {
      it('should not be allowed', async () => {
        await assertRevert(
          token.createPromotionalPurchase(firstProduct.id, 1, user3, 0, {
            from: user3
          })
        );
      });
    });

    describe('if the owner is creating it', async () => {
      it('should not allow violation of the total inventory', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user3 });
        await licenseSale.purchase(firstProduct.id, 1, user3, ZERO_ADDRESS, {
          from: user3,
          // value: firstProduct.price
        });
        await token.createPromotionalPurchase(firstProduct.id, 1, user3, 0, {
          from: owner
        });
        await assertRevert(
          token.createPromotionalPurchase(firstProduct.id, 1, user3, 0, {
            from: owner
          })
        );
      });

      it('should not allow violation of the total supply', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user3 });
        await licenseSale.purchase(firstProduct.id, 1, user3, ZERO_ADDRESS, {
          from: user3,
          value: firstProduct.price
        });
        await token.createPromotionalPurchase(firstProduct.id, 1, user3, 0, {
          from: owner
        });
        await assertRevert(
          token.incrementInventory(firstProduct.id, 1, {
            from: owner
          })
        );
      });

      it('should decrement the inventory', async () => {
        (await token.availableInventoryOf(
          firstProduct.id
        )).should.be.bignumber.equal(2);
        await token.createPromotionalPurchase(firstProduct.id, 1, user3, 0, {
          from: owner
        });
        (await token.availableInventoryOf(
          firstProduct.id
        )).should.be.bignumber.equal(1);
      });

      it('should count the amount sold', async () => {
        (await token.totalSold(firstProduct.id)).should.be.bignumber.equal(0);
        await token.createPromotionalPurchase(firstProduct.id, 1, user3, 0, {
          from: owner
        });
        (await token.totalSold(firstProduct.id)).should.be.bignumber.equal(1);
      });
    });
  });

  describe('when renewing a subscription', async () => {
    let tokenId: any;
    let issuedEvent: any;

    beforeEach(async () => {
      await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
      const { logs } = await licenseSale.purchase(secondProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 });
      issuedEvent = eventByName(logs, 'LicenseIssued');
      tokenId = issuedEvent.args.licenseId;
    });

    describe('it fails because', async () => {
      it('should not allow zero cycles', async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
        await assertRevert(
          token.renew(tokenId, 0, { from: user1 })
        );
      });

      it('should require that the token has an owner', async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
        await assertRevert(
          token.renew(100, 1, { from: user1 })
        );
      });

      it('should not allow renewing a non-subscription product', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        const { logs } = await licenseSale.purchase(firstProduct.id, 1, user1, ZERO_ADDRESS, { from: user1 });
        const issuedEvent = eventByName(logs, 'LicenseIssued');
        const tokenId = issuedEvent.args.licenseId;

        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        await assertRevert(
          token.renew(tokenId, 1, { from: user1 })
        );
      });

      describe('and the admins set a product to be unrenewable', async () => {
        beforeEach(async () => {
          let isRenewable = await token.renewableOf(secondProduct.id);
          isRenewable.should.be.true();
          await token.setRenewable(secondProduct.id, false, { from: owner });
          isRenewable = await token.renewableOf(secondProduct.id);
          isRenewable.should.be.false();
        });

        it('should not allow renewing a non-renewable product', async () => {
          await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
          await assertRevert(
            token.renew(tokenId, 1, { from: user1 })
          );
        });
      });
      it('should not allow an underpaid value', async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price * 2 - 1, { from: user1 });
        await assertRevert(
          token.renew(tokenId, 2, { from: user1 })
        );
      });
      it('should not allow an overpaid value', async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price * 2 - 1, { from: user1 });
        await assertRevert(
          token.renew(tokenId, 2, { from: user1 })
        );
      });
      describe('and the contract is paused it', async () => {
        beforeEach(async () => {
          await token.pause({ from: owner });
        });
        it('should not work', async () => {
          await daiContract.approve(licenseSale.address, secondProduct.price * 2, { from: user1 });
          await assertRevert(
            token.renew(tokenId, 2, { from: user1 })
          );
        });
      });
    });
    describe('and succeeds', async () => {
      describe('when the renewal time is in the past', async () => {
        beforeEach(async () => {
          const originalExpirationTime = await token.licenseExpirationTime(tokenId);
          await increaseTime(secondProduct.interval + duration.days(1));
          originalExpirationTime.should.be.bignumber.greaterThan(0);
          let now = await latestTime();
          now.should.be.bignumber.greaterThan(originalExpirationTime);
        });

        it('should renew from now forward', async () => {
          await daiContract.approve(licenseSale.address, secondProduct.price * 2, { from: user1 });
          let now = await latestTime();
          await token.renew(tokenId, 2, {
            // value: secondProduct.price * 2
            from: user1
          });
          const expectedExpirationTime = new BigNumber(now).plus(
            secondProduct.interval * 2
          );
          const actualExpirationTime = await token.licenseExpirationTime(
            tokenId
          );
          actualExpirationTime.should.be.bignumber.equal(
            expectedExpirationTime
          );
        });
      });

      describe('when the renewal time is in the future', async () => {
        let originalExpirationTime: any;
        beforeEach(async () => {
          originalExpirationTime = await token.licenseExpirationTime(tokenId);
          originalExpirationTime.should.be.bignumber.greaterThan(0);

          await daiContract.approve(licenseSale.address, secondProduct.price * 2, { from: user1 });
          await token.renew(tokenId, 2, {
            from: user1
            // value: secondProduct.price * 2
          });
        });

        it('should add time to the existing renewal time', async () => {
          let expectedTime = originalExpirationTime.add(
            secondProduct.interval * 2
          );
          let actualTime = await token.licenseExpirationTime(tokenId);
          actualTime.should.be.bignumber.equal(expectedTime);
        });
      });

      it('should emit a LicenseRenewal event', async () => {
        const originalExpirationTime = await token.licenseExpirationTime(
          tokenId
        );
        const expectedExpirationTime = originalExpirationTime.add(
          secondProduct.interval * 2
        );

        await daiContract.approve(licenseSale.address, secondProduct.price * 2, { from: user1 });
        const { logs } = await token.renew(tokenId, 2, {
          // value: secondProduct.price * 2
          from: user1
        });

        const renewalEvent = eventByName(logs, 'LicenseRenewal');
        renewalEvent.args.licenseId.should.be.bignumber.equal(tokenId);
        renewalEvent.args.productId.should.be.bignumber.equal(secondProduct.id);
        renewalEvent.args.expirationTime.should.be.bignumber.equal(
          expectedExpirationTime
        );
      });
    });
  });

  describe('when renewing a promotional subscription', async () => {
    describe('and an admin is sending', async () => {
      it('should not allow renewing a non-subscription product', async () => {
        await daiContract.approve(licenseSale.address, firstProduct.price, { from: user1 });
        const { logs } = await licenseSale.purchase(
          firstProduct.id,
          1,
          user1,
          ZERO_ADDRESS,
          {
            from: user1
            // value: firstProduct.price
          }
        );
        const issuedEvent = eventByName(logs, 'LicenseIssued');
        const tokenId = issuedEvent.args.licenseId;
        await assertRevert(
          token.createPromotionalRenewal(tokenId, 1, { from: owner })
        );
      });
      describe('and the product is a subscription product', async () => {
        let tokenId: any;
        beforeEach(async () => {
          await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
          const { logs } = await licenseSale.purchase(
            secondProduct.id,
            1,
            user1,
            ZERO_ADDRESS,
            {
              from: user1
              // value: secondProduct.price
            }
          );
          const issuedEvent = eventByName(logs, 'LicenseIssued');
          tokenId = issuedEvent.args.licenseId;
        });

        describe('if the admins have set a product to be unrenewable', async () => {
          beforeEach(async () => {
            let isRenewable = await token.renewableOf(secondProduct.id);
            isRenewable.should.be.true();
            await token.setRenewable(secondProduct.id, false, { from: owner });
            isRenewable = await token.renewableOf(secondProduct.id);
            isRenewable.should.be.false();
          });

          it('should not allow renewing a non-renewable product', async () => {
            await assertRevert(
              token.createPromotionalRenewal(tokenId, 1, { from: owner })
            );
          });
        });
        describe('and the contract is paused', async () => {
          beforeEach(async () => {
            await token.pause({ from: owner });
          });
          it('should not work', async () => {
            await assertRevert(
              token.createPromotionalRenewal(tokenId, 1, { from: owner })
            );
          });
        });
        it('should renew according to the product time', async () => {
          const originalExpirationTime = await token.licenseExpirationTime(
            tokenId
          );
          originalExpirationTime.should.be.bignumber.greaterThan(0);
          token.createPromotionalRenewal(tokenId, 1, { from: owner });

          let expectedTime = originalExpirationTime.add(secondProduct.interval);
          let actualTime = await token.licenseExpirationTime(tokenId);
          // actualTime.should.be.bignumber.equal(expectedTime);
        });
      });
    });

    describe('and a rando is sending', async () => {
      let tokenId: any;
      beforeEach(async () => {
        await daiContract.approve(licenseSale.address, secondProduct.price, { from: user1 });
        const { logs } = await licenseSale.purchase(
          secondProduct.id,
          1,
          user1,
          ZERO_ADDRESS,
          {
            from: user1
            // value: secondProduct.price
          }
        );
        const issuedEvent = eventByName(logs, 'LicenseIssued');
        tokenId = issuedEvent.args.licenseId;
      });

      it('should not be allowed', async () => {
        await assertRevert(
          token.createPromotionalRenewal(tokenId, 1, { from: user1 })
        );
      });
    });
  });

  describe('when setting the withdrawal address', async () => {
    it('should not allow a rando', async () => {
      await assertRevert(token.setWithdrawalAddress(user1, { from: user1 }));
    });
  });

  describe('when withdrawing the balance', async () => {
    beforeEach(async () => {
      await token.transferOwnership(owner);
    });
    it('should not allow a rando', async () => {
      await assertRevert(token.setWithdrawalAddress(user1, { from: user1 }));
    });
  });
});

///
