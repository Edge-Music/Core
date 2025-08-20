import { LogUtil } from '@pura/harmony-utils';
import { Song } from '../type/Adapter';

const TAG = 'SongDataSource'
export class SongsDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private dataArray: Song[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): Song {
    return this.dataArray[index];
  }

  public pushData(data: Song): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  public pushMultiData(dataList: Song[]): void {
    dataList.forEach(data => {
      this.dataArray.push(data);
      this.notifyDataAdd(this.dataArray.length - 1);
    })
  }

  public deleteData(index: number): void {
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
  }

  public clearData(): void {
    this.dataArray = []
    this.reloadData()
  }

  public reloadData(): void {
    this.notifyDataReload();
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
      LogUtil.info(`[${TAG}]`, `registerDataChangeListener: ${JSON.stringify(listener)}`)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
      LogUtil.info(`[${TAG}]`, `unregisterDataChangeListener: ${JSON.stringify(listener)}`)
    }
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
      LogUtil.info(`[${TAG}]`, `notifyDataDelete: ${index}`)
    });
  }

  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    });
  }

  notifyDatasetChange(operations: DataOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operations);
    });
  }
}