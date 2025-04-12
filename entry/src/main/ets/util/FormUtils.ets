import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { http } from '@kit.NetworkKit';
import { FormControlData } from '../viewmodel/FormData';
import { Song } from '../type/Adapter';
import { LogUtil } from '@pura/harmony-utils';
import { FormInfo } from '../viewmodel/FormData';
import { FormRdbHelper } from './FormRdbHelper';
import ImageUtils from './ImageUtils';
import { avPlayerManager } from './AVPlayerManager';
import { SourceAdapter } from '../adapter';
import { rpc } from '@kit.IPCKit';
import { CollectAction, PlayActionType } from '../widget/model/FormCardConstant';
import { PlaylistManager } from './PlaylistManager';

const TAG = 'FormUtils';

class FormUtils {
  private static context: Context | undefined;

  public async init(context: Context) {
    FormUtils.context = context;
  }


  public insertFormData(data: FormInfo): Promise<number> {
    return FormRdbHelper.getInstance(FormUtils.context!).insertForm(data);
  }

  public async updateCardCollectStatus(isCollected: boolean) {
    let updateData: Record<string, boolean | string> = {
      'isCollected': isCollected
    };
    let songItem: Song = AppStorage.get('current_playing_song') as Song;
    if (songItem) {
      SourceAdapter.likeSong(songItem, isCollected)
    }
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCard');
    formList.forEach(formInfo => {
      this.updateForm(formInfo.formId, updateData);
    });
  }

  public async updateCardPlayStatus(isPlay: boolean) {
    class CardUpdateData {
      isPlay: boolean = isPlay;
    }

    let data = new CardUpdateData();
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCard');
    LogUtil.info(TAG, `updateCardPlayStatus formList length:  ${formList.length}`);
    formList.forEach(formInfo => {
      this.updateForm(formInfo.formId, data);
    });
  }

  public async updateMusicControlCards(songItem: Song, isPlay: boolean) {
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCard');
    let formData = new FormControlData();
    formData.isPlay = isPlay;
    formData.singer = songItem?.artists ? songItem.artists.map(artist => artist.name).join(" / ") : "未知艺术家"
    formData.title = songItem.name;
    formData.songId = songItem.id;
    formData.isCollected = songItem?.meta?.isFavorite || false;
    LogUtil.info(TAG, `updateMusicControlCards isPlay:${isPlay}, songItem:${JSON.stringify(songItem)}`);
    try {
      let netFile = songItem?.album?.cover + "?param=512y512" ?? "";
      let tempDir = FormUtils.context!.getApplicationContext().tempDir;
      let fileName = 'file' + Date.now();
      let tmpFile = tempDir + '/' + fileName;
      let imgMap: Record<string, number> = {};
      let httpRequest = http.createHttp()
      let data = await httpRequest.request(netFile);
      if (data?.responseCode == http.ResponseCode.OK) {
        try {
          let imgFile = fileIo.openSync(tmpFile, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
          imgMap[fileName] = imgFile.fd;
          try {
            await fileIo.write(imgFile.fd, data.result as ArrayBuffer);
            let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);
            formData.imageColor = imageDealData.imageColor;
            formData.imageColorHex = imageDealData.imageColorHex;
            LogUtil.info(TAG, `updateMusicControlCards imageColorHex: ${imageDealData.imageColorHex.length}`)
            try {
              formData.formImages = imgMap
              formData.imgName = fileName
              formList.forEach(formInfo => {
                this.updateForm(formInfo.formId, formData);
              });
            } catch (error) {
              LogUtil.error(TAG, `FormAbility updateForm failed: ${JSON.stringify(error)}`);
            }
          } catch (err) {
            LogUtil.error(TAG,
              "write data to file failed with error message: " + err.message + ", error code: " + err.code);
          } finally {
            // 在fileIo.closeSync执行之前，确保formProvider.updateForm已执行完毕。
            fileIo.closeSync(imgFile);
          }
          ;
        } catch (e) {
          LogUtil.error(TAG, `openSync failed: ${JSON.stringify(e as BusinessError)}`);
        }
      }
    } catch (e) {
      LogUtil.error(TAG, ` failed: ${JSON.stringify(e as BusinessError)}`);
    }
  }

  public async updateMusicControlSingle( formId: string) {
    const player = await avPlayerManager.getAVPlayerInstance()
    let isPlay = player.state === 'playing'
    let songItem: Song = AppStorage.get('current_playing_song') as Song;
    LogUtil.info(`updateMusicControlSingle isPlay:${isPlay}, songItem:${JSON.stringify(songItem)}`);
    let formData = new FormControlData();
    formData.isPlay = isPlay;
    formData.formId = formId;
    formData.singer = songItem?.artists ? songItem.artists.map(artist => artist.name).join(" / ") : "未知艺术家"
    formData.title = songItem.name;
    formData.songId = songItem.id;
    formData.isCollected = songItem?.meta?.isFavorite || false;
    try {
      let netFile = songItem?.album?.cover + "?param=512y512" ?? "";
      let tempDir = FormUtils.context!.getApplicationContext().tempDir;
      let fileName = 'file' + Date.now();
      let tmpFile = tempDir + '/' + fileName;
      let imgMap: Record<string, number> = {};
      let httpRequest = http.createHttp()
      let data = await httpRequest.request(netFile);
      if (data?.responseCode == http.ResponseCode.OK) {
        try {
          let imgFile = fileIo.openSync(tmpFile, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
          imgMap[fileName] = imgFile.fd;
          try {
            await fileIo.write(imgFile.fd, data.result as ArrayBuffer);
            let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);
            formData.imageColor = imageDealData.imageColor;
            formData.imageColorHex = imageDealData.imageColorHex;
            LogUtil.info(TAG, `updateMusicControlCards imageColorHex: ${imageDealData.imageColorHex.length}`)
            try {
              formData.formImages = imgMap
              formData.imgName = fileName
              this.updateForm(formData.formId, formData);
            } catch (error) {
              LogUtil.error(TAG, `FormAbility updateForm failed: ${JSON.stringify(error)}`);
            }
          } catch (err) {
            LogUtil.error(TAG,
              "write data to file failed with error message: " + err.message + ", error code: " + err.code);
          } finally {
            // 在fileIo.closeSync执行之前，确保formProvider.updateForm已执行完毕。
            fileIo.closeSync(imgFile);
          }
          ;
        } catch (e) {
          LogUtil.error(TAG, `openSync failed: ${JSON.stringify(e as BusinessError)}`);
        }
      }
    } catch (e) {
      LogUtil.error(TAG, ` failed: ${JSON.stringify(e as BusinessError)}`);
    }
  }

  public updateMusicControlCard(formId: string, needUpdate: boolean) {
    LogUtil.info(TAG, `updateMusicControlCard formId:${formId},needUpdate:${needUpdate}`);
    let updateData: Record<string, boolean | string> = {
      'isNeedRequestUpdate': needUpdate,
      'formId': formId
    };
    this.updateForm(formId, updateData);
  }


  public async updateRecommendedCards(imageUrl: string) {
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('RecommendedMusic');
    let tempDir = FormUtils.context!.getApplicationContext().tempDir;
    let fileName = 'file' + Date.now();
    let tmpFile = tempDir + '/' + fileName + '.jpg';
    let httpRequest = http.createHttp();
    let data = await httpRequest.request(imageUrl+'?param=512y512');
    let imgMap: Record<string, number> = {};

    class FormDataClass {
      imgBg: string = fileName;
      formImages: Record<string, number> = imgMap;
      isLoaded: boolean = true;
      imageColorHex: string = '';
    }

    if (data.responseCode === http.ResponseCode.OK) {
      let imgFile = fileIo.openSync(tmpFile, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      imgMap[fileName] = imgFile.fd;
      try {
        let imageBuffer: ArrayBuffer = data.result as ArrayBuffer;
        let writeLen: number = fileIo.writeSync(imgFile.fd, imageBuffer);
        let imageDealData = await ImageUtils.getImageDealDataByArr(imageBuffer);
        LogUtil.info(TAG, `write data to file succeed and size is: ${writeLen}`);
        LogUtil.info(TAG, `ArkTSCard download complete: ${tmpFile}`);
        let formData = new FormDataClass();
        formData.imageColorHex = imageDealData.imageColorHex;
        formList.forEach(formInfo => {
          this.updateForm(formInfo.formId, formData);
        });
      } catch (err) {
        LogUtil.error(TAG, `write data to file failed with error: ${JSON.stringify(err)}`);
      } finally {
        fileIo.closeSync(imgFile);
        httpRequest.destroy();
      }
    } else {
      LogUtil.error(TAG, `ArkTSCard download task failed`);
    }
  }

  private updateForm(formId: string, updateData: object) {
    LogUtil.info(TAG, `updateForm  updateData: ${JSON.stringify(updateData)}}`);
    let formMsg: formBindingData.FormBindingData = formBindingData.createFormBindingData(updateData);
    formProvider.updateForm(formId, formMsg).then(() => {
      LogUtil.info(TAG, `updateForm success formId:  ${formId}}`);
    }).catch((error: BusinessError) => {
      LogUtil.error(TAG, `updateForm failed: ${JSON.stringify(error)}`);
    });
  }

  public requestUpdatePlayCard = (data: rpc.MessageSequence) => {
    let params: Record<string, string> = JSON.parse(data.readString());
    let formId = params.formId;
    if (formId) {
      this.updateMusicControlSingle(formId);
    }
    return null;
  };

  playByActionCall = (data: rpc.MessageSequence) => {
    let params: Record<string, string> = JSON.parse(data.readString());
    if (params.playActionType) {
      let playActionType: PlayActionType = params.playActionType as PlayActionType;
      switch (playActionType) {
        case PlayActionType.PAUSE:
          avPlayerManager.pause()
          break;
        case PlayActionType.PLAY:
          avPlayerManager.play()
          break;
        case PlayActionType.PREVIOUS:
          const prevSong = PlaylistManager.playPrevious()
          if (prevSong) {
            PlaylistManager.playSong(prevSong)
          }
          break;
        case PlayActionType.NEXT:
          const nextSong = PlaylistManager.playNext()
          if (nextSong) {
            PlaylistManager.playSong(nextSong)
          }
          break;
      }
    }
    return null;
  };

  collectActionCall = (data: rpc.MessageSequence) => {
    let params: Record<string, string> = JSON.parse(data.readString());
    if (params.collectActionType) {
      if (params.collectActionType === CollectAction.COLLECTED) {
        this.updateCardCollectStatus(true)
      } else {
        this.updateCardCollectStatus(false)
      }
    }
    return null;
  };

}

export default new FormUtils();
