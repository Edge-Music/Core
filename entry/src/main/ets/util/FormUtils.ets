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
import { EventHelper } from './EventHelper';
import { rpc } from '@kit.IPCKit';
import { CollectAction, PlayActionType } from '../widget/model/FormCardConstant';
import { PlaylistManager } from './PlaylistManager';
import { LyricsLine } from './LyricsManager';
import { audio } from '@kit.AudioKit';

const TAG = 'FormUtils';

class FormUtils {
  private static context: Context | undefined;
  // 缓存当前播放状态，用于新卡片添加时同步正确的播放/暂停状态
  static currentPlayState: boolean = false;

  public async init(context: Context) {
    FormUtils.context = context;
  }


  public insertFormData(data: FormInfo): Promise<number> {
    return FormRdbHelper.getInstance(FormUtils.context!).insertForm(data);
  }

  public async updateCardCollectStatus(isCollected?: boolean) {
    let songItem: Song = AppStorage.get('current_playing_song') as Song;
    let updateData: Record<string, boolean | string > = {
      'isCollected': isCollected ?? songItem.meta?.isFavorite!
    };
    LogUtil.info("[FAV_DEBUG]", `updateCardCollectStatus: isCollected=${isCollected} song=${songItem}`);
    if (songItem&&isCollected!==undefined) {
      SourceAdapter.likeSong(songItem, isCollected).then((ok: boolean) => {
        if (ok) {
          EventHelper.postFavoriteToggle(isCollected)
        }
      })
    }
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCard');
    LogUtil.info("[FAV_DEBUG]", `updateCardCollectStatus: 更新 ${formList.length} 张卡片 isCollected=${isCollected}`);
    formList.forEach(formInfo => {
      this.updateForm(formInfo.formId, updateData);
    });
  }

  public async updateCardPlayStatus(isPlay: boolean) {
    // 缓存当前播放状态，供新添加的卡片同步使用
    FormUtils.currentPlayState = isPlay;
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

  public async updateCardLyrics(parsedLyrics: LyricsLine[]) {
    class CardLyricsUpdateData {
      parsedLyrics: LyricsLine[] = parsedLyrics
    }

    let data = new CardLyricsUpdateData();
    // 更新所有歌词相关卡片（PlayControlCardWithLyrics + PlayControlCardLargeLyrics）
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCardWithLyrics');
    let largeLyricsList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCardLargeLyrics');
    formList = formList.concat(largeLyricsList);
    LogUtil.info(TAG, `updateCardPlayLyrics formList length:  ${formList.length}`);
    formList.forEach(formInfo => {
      this.updateForm(formInfo.formId, data);
    });
  }

  public async updateCardLyricsIndex(currentLyricsIndex: number) {
    class CardLyricsUpdateData {
      currentLyricsIndex: number = currentLyricsIndex
    }

    let data = new CardLyricsUpdateData();
    // 更新所有歌词相关卡片（PlayControlCardWithLyrics + PlayControlCardLargeLyrics）
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCardWithLyrics');
    let largeLyricsList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCardLargeLyrics');
    formList = formList.concat(largeLyricsList);
    LogUtil.info(TAG, `updateCardPlayLyricsIndex formList length:  ${formList.length}`);
    formList.forEach(formInfo => {
      this.updateForm(formInfo.formId, data);
    });
  }

  public async updateCardCurrentLyrics(currentLyric: string) {
    class CardCurrentLyricsUpdateData {
      currentLyric: string = currentLyric
    }

    let data = new CardCurrentLyricsUpdateData();
    let formList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCard2x4');
    let largeLyricsList: Array<FormInfo> = await FormRdbHelper.getInstance(FormUtils.context!).queryFormByName('PlayControlCardLargeLyrics');
    formList = formList.concat(largeLyricsList);
    LogUtil.info(TAG, `updateCardCurrentLyrics formList length:  ${formList.length}`);
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
    formData.currentLyric = (AppStorage.get<string>('test_index') as string) || '';
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
          let blurFile: fileIo.File | null = null;
          try {
            await fileIo.write(imgFile.fd, data.result as ArrayBuffer);
            let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);
            formData.imageColor = imageDealData.imageColor;
            formData.imageColorHex = imageDealData.imageColorHex;
            formData.accentColorHex = imageDealData.accentColorHex;
            LogUtil.info(TAG, `updateMusicControlCards imageColorHex: ${imageDealData.imageColorHex.length}`)
            // 模糊封面落盘成 fd，随 formImages 一起推给卡片（2×4 用作铺底背景）
            const blurResult = await ImageUtils.writeBlurToTemp(FormUtils.context!, imageDealData.blurPixelMapForCard, 'card');
            if (blurResult) {
              blurFile = blurResult.file;
              imgMap[blurResult.fileName] = blurFile.fd;
              formData.blurImg = blurResult.fileName;
            }
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
            if (blurFile) {
              fileIo.closeSync(blurFile);
            }
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
    let isPlay = player.getState() === audio.AudioState.STATE_RUNNING
    let songItem: Song = AppStorage.get('current_playing_song') as Song;
    LogUtil.info(`updateMusicControlSingle isPlay:${isPlay}, songItem:${JSON.stringify(songItem)}`);
    let formData = new FormControlData();
    formData.isPlay = isPlay;
    formData.formId = formId;
    formData.singer = songItem?.artists ? songItem.artists.map(artist => artist.name).join(" / ") : "未知艺术家"
    formData.title = songItem.name;
    formData.songId = songItem.id;
    formData.isCollected = songItem?.meta?.isFavorite || false;
    formData.currentLyric = (AppStorage.get<string>('test_index') as string) || '';
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
          let blurFile: fileIo.File | null = null;
          try {
            await fileIo.write(imgFile.fd, data.result as ArrayBuffer);
            let imageDealData = await ImageUtils.getImageDealDataByArr(data.result as ArrayBuffer);
            formData.imageColor = imageDealData.imageColor;
            formData.imageColorHex = imageDealData.imageColorHex;
            formData.accentColorHex = imageDealData.accentColorHex;
            LogUtil.info(TAG, `updateMusicControlCards imageColorHex: ${imageDealData.imageColorHex.length}`)
            // 模糊封面落盘成 fd，随 formImages 一起推给卡片（2×4 用作铺底背景）
            const blurResult = await ImageUtils.writeBlurToTemp(FormUtils.context!, imageDealData.blurPixelMapForCard, 'single');
            if (blurResult) {
              blurFile = blurResult.file;
              imgMap[blurResult.fileName] = blurFile.fd;
              formData.blurImg = blurResult.fileName;
            }
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
            if (blurFile) {
              fileIo.closeSync(blurFile);
            }
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
      'formId': formId,
      // 同步当前播放状态，避免新卡片先显示暂停再切回播放的闪烁
      'isPlay': FormUtils.currentPlayState
    };
    this.updateForm(formId, updateData);
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
