import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtil } from '@pura/harmony-utils';

const TAG = 'RdbUtils';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'database.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

export class RdbUtils {
  private rdbStore?: relationalStore.RdbStore;
  private tableName: string = '';
  private sqlCreateTable: string = '';
  private context: Context;

  constructor(context: Context, tableName: string, sqlCreateTable: string) {
    this.context = context;
    this.tableName = tableName;
    this.sqlCreateTable = sqlCreateTable;
  }

  public getRdbStore(): Promise<relationalStore.RdbStore> {
    LogUtil.info(TAG, `getRdbStore The rdbStore context: ${this.context}`);
    return new Promise<relationalStore.RdbStore>((resolve, reject) => {
      if (this.rdbStore) {
        LogUtil.info(TAG, 'getRdbStore The rdbStore exists.');
        resolve(this.rdbStore);
      }
      relationalStore.getRdbStore(this.context, STORE_CONFIG).then((rdbStore: relationalStore.RdbStore) => {
        LogUtil.info(TAG, 'getRdbStore successfully.')
        this.rdbStore = rdbStore;
        this.rdbStore.executeSync(this.sqlCreateTable);
        resolve(rdbStore);
      }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `getRdbStore failed, code is ${err.code},message is ${err.message}`);
        reject(err);
      })
    });
  }

  async insertData(valuesBucket: relationalStore.ValuesBucket): Promise<number> {
    LogUtil.info(TAG, `insertData valuesBucket : ${JSON.stringify(valuesBucket)}`);
    let rdbStore = await this.getRdbStore();
    return new Promise<number>((resolve, reject) => {
      rdbStore.insert(this.tableName, valuesBucket).then((rowId: number) => {
        LogUtil.info(TAG, `insertData successfully. rowId: ${rowId}`);
        resolve(rowId);
      }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `insertData failed, code is ${err.code},message is ${err.message}`);
        reject(err);
      })
    });
  }

  async batchInsert(valueBucketArray: Array<relationalStore.ValuesBucket>): Promise<number> {
    LogUtil.info(TAG, `batchInsert valuesBucket : ${JSON.stringify(valueBucketArray)}`);
    let rdbStore = await this.getRdbStore();
    return new Promise<number>((resolve, reject) => {
      rdbStore.batchInsert(this.tableName, valueBucketArray).then((rowId: number) => {
        LogUtil.info(TAG, `batchInsert successfully. rowId: ${rowId}`);
        resolve(rowId);
      }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `batchInsert failed, code is ${err.code},message is ${err.message}`);
        reject(err);
      })
    });
  }

  async deleteData(predicates: relationalStore.RdbPredicates): Promise<number> {
    let rdbStore = await this.getRdbStore();
    return new Promise<number>((resolve, reject) => {
      rdbStore.delete(predicates).then((rows: number) => {
        LogUtil.info(TAG, `deleteData successfully. rows: ${rows}`)
        resolve(rows);
      }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `deleteData failed, code is ${err.code},message is ${err.message}`);
        reject(err);
      })
    });
  }

  async updateData(predicates: relationalStore.RdbPredicates, data: relationalStore.ValuesBucket): Promise<number> {
    let rdbStore = await this.getRdbStore();
    return new Promise<number>((resolve, reject) => {
      rdbStore.update(data, predicates).then((rows: number) => {
        LogUtil.info(TAG, `updateData successfully. rows: ${rows}`);
        resolve(rows);
      }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `updateData failed, code is ${err.code},message is ${err.message}`);
        reject(err);
      })
    });
  }

  async query(predicates: relationalStore.RdbPredicates): Promise<relationalStore.ResultSet> {
    let rdbStore = await this.getRdbStore();
    return new Promise<relationalStore.ResultSet>((resolve, reject) => {
      rdbStore.query(predicates).then((resultSet: relationalStore.ResultSet) => {
        LogUtil.info(TAG, `query successfully. rowCount: ${resultSet.rowCount}`);
        resolve(resultSet);
      }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `query failed, code is ${err.code},message is ${err.message}`);
        reject(err);
      })
    })
  }
}