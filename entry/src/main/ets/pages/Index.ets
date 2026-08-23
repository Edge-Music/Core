import { BreakpointSystem } from '../component/BreakpointSystem'
import { StyleConstants } from '../constants/StyleConstants'
import { PreferencesCache } from '../util/PreferenceCache'
import { Artist, Playlist, Song, SourceConfig } from '../type/Adapter'
import { SourceAdapter } from '../adapter'
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'
import { PipManager } from '../util/PipManager'
import { avPlayerManager } from '../util/AVPlayerManager'
import { ToastUtil, WantUtil } from '@pura/harmony-utils';
import { Log, LogUtil } from '../logger/Logger';
import { common } from '@kit.AbilityKit'
import { ImmersivePlayer } from '../v3/pages/ImmersivePlayer'
import { ImmersiveLyrics } from '../v3/pages/ImmersiveLyrics'
import { ImmersiveSettings } from '../v3/pages/ImmersiveSettings'
import { ImmersiveSearch } from '../v3/pages/ImmersiveSearch'
import { ImmersiveSourceManager } from '../v3/pages/ImmersiveSourceManager'
import { ImmersivePlaylist } from '../v3/pages/ImmersivePlaylist'
import { ImmersiveStatistics } from '../v3/pages/ImmersiveStatistics'
import { ImmersiveDownload } from '../v3/pages/ImmersiveDownload'
import { ImmersiveAggregation } from '../v3/pages/ImmersiveAggregation'
import LyricsManager from '../util/LyricsManager'
import { EventHelper } from '../util/EventHelper'
import { CrashReportSheet } from '../component/CrashReportSheet'
// import { motion } from '@kit.MultimodalAwarenessKit'
import { sensor } from '@kit.SensorServiceKit'
import { notificationManager } from '@kit.NotificationKit'
import { hilog } from '../logger/Logger'
import { audio } from '@kit.AudioKit'

// import { sensor } from '@kit.SensorServiceKit'

// import { motion } from '@kit.MultimodalAwarenessKit'

// 缓存常用值以避免重复计算
const COLUMNS_TEMPLATE_LG = '1fr 1fr 1fr 1fr' // 宽屏4列（1×4布局）
const COLUMNS_TEMPLATE_SM = '1fr 1fr' // 窄屏2列（2×2布局）
const TAG = 'Index'

// 隐私协议弹窗组件
@CustomDialog
struct PrivacyPolicyDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {
  };
  onDisagree: () => void = () => {
  };

  build() {
    Column({ space: 20 }) {
      // 标题
      Text($r('app.string.privacy_policy_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_title'))
        .margin({ top: 10 })

      // 内容
      Column({ space: 12 }) {
        Text($r('app.string.privacy_policy_main_text'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .width('100%')

        Text($r('app.string.privacy_policy_detail_text'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .width('100%')

        // 查看协议链接
        Row() {
          Text($r('app.string.privacy_policy_link_prefix'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))

          Text($r('app.string.privacy_policy_link_text'))
            .fontSize(14)
            .fontColor($r('app.color.text_click'))
            .decoration({ type: TextDecorationType.Underline })
            .onClick(() => {
              WantUtil.toWebBrowser("https://music.yby.zone/policy.html")
                .catch((err: BusinessError) => {
                  LogUtil.error(TAG, "打开隐私协议失败！", err.message);
                  ToastUtil.showShort("跳转到浏览器失败！");
                });
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 4, right: 4 })

      // 按钮区域
      Row({ space: 12 }) {
        Button($r('app.string.privacy_policy_disagree'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(8)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
            this.onDisagree();
          })

        Button($r('app.string.privacy_policy_agree'))
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.text_click'))
          .borderRadius(8)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
            this.onAgree();
          })
      }
      .width('100%')
      .margin({ bottom: 10 })
    }
    .padding(20)
    .borderRadius(12)
    .backgroundColor($r('app.color.page_background'))
    .width('90%')
  }
}

@Entry
@Component
struct Index {
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack()
  // 崩溃复盘半模态：仅当 hiAppEvent 捕获到真实 APP_CRASH（有 pending.flag）时才弹出；
  // 强杀/指令结束进程没有 crash 记录，不会误弹
  @State crashSheetShow: boolean = false
  private breakpointSystem: BreakpointSystem = new BreakpointSystem()

  // 3.0 根级关键初始化（原在旧 Index_page.onWillAppear + @StorageLink 播种，换首屏后迁到此处）
  private rootInit(): void {
    // 关键：把缓存播种进 AppStorage（原由旧 Index_page 的 @StorageLink 初始化器完成）——
    // 否则「我的」数据源列表/头像、推荐/榜单/聚合歌单为空（歌曲仍能取因 source 走缓存 API）
    AppStorage.setOrCreate('user_data_source', PreferencesCache.getUserDataSource())
    AppStorage.setOrCreate('show_user_data_source', PreferencesCache.getShowUserDataSource())
    AppStorage.setOrCreate('index_recommend_songs', PreferencesCache.getSongCache('index_recommend_songs'))
    AppStorage.setOrCreate('index_recommend_toplist', PreferencesCache.getPlaylistCache('index_recommend_toplist'))
    AppStorage.setOrCreate('aggregation_playlist', PreferencesCache.getPlaylistCache('aggregation_playlist'))
    // 再次打开保留歌曲信息
    const lastSong: Song | null = PreferencesCache.lastSong()
    if (lastSong) {
      AppStorage.setOrCreate('current_playing_song', lastSong)
      AppStorage.setOrCreate('current_playing_playlist', PreferencesCache.playlist())
      // 主动解析一次歌词：AVPlayerManager 仅在真正播放（player initialized）时才调 init，
      // 被动展示需在此触发，否则歌词为空。lastSong 已带 meta.lyric，可离线解析。
      LyricsManager.init()
      // 仅在没有已 prepare 的播放源时才恢复上一首（暂停态）。
      // 卡片后台起播后再开 App 时已有活跃管线，重 prepare 会把正在播放的歌拆掉并暂停。
      if (!avPlayerManager.getCurrentDecoder()) {
        EventHelper.postPlaySong([lastSong, true])
      }
    }
    // 供服务卡片/深链跳转读取的导航栈
    AppStorage.setOrCreate('pageStack', this.pageStack)
    // 断点系统：写 current_width_breakpoint / currentOrientation，v3 全部页面依赖
    this.breakpointSystem.register(this.getUIContext())
    // 音频会话
    avPlayerManager.setAudioSession()
    // 设备类型 / 宽屏标志
    const deviceType: string = deviceInfo.deviceType
    const productSeries: string = deviceInfo.productSeries
    AppStorage.setOrCreate<boolean>('isWideScreen', deviceType !== 'phone' && productSeries !== 'VDE')
    AppStorage.setOrCreate('devicetype', deviceType)
    PreferencesCache.setUserPreference('devicetype', deviceType)
    PreferencesCache.setUserPreference('is_Pura_X', productSeries === 'VDE' ? '1' : '0')
    // 桌面歌词（画中画）：用户开启则初始化，退后台自动启动
    if (PreferencesCache.getUserPreference('Lyic_desktop', '0') === '1') {
      PipManager.getInstance().init(this.getUIContext().getHostContext() as common.Context)
      PipManager.getInstance().setAutoStart(true)
    }
    // 悬浮球「智感」模式：注册握持手势监听（1左/2右），驱动 AppStorage 'hand'
    // 3.0 首页替换时漏迁移，补回；HoldHand 内部已做 canIUse 守卫
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      import('../util/HoldHand').then((nv) => {
        nv.startHoldingHand(this.getUIContext())
      })
    }
  }

  @Builder
  CrashReportSheetContent() {
    CrashReportSheet({
      onClose: () => {
        this.crashSheetShow = false
      }
    })
  }

  @Builder
  PageMap(name: string) {
    if (name === 'ImmersivePlayer') {
      ImmersivePlayer()
    } else if (name === 'ImmersiveLyrics') {
      ImmersiveLyrics()
    } else if (name === 'ImmersiveSettings') {
      ImmersiveSettings()
    } else if (name === 'ImmersiveSearch') {
      ImmersiveSearch()
    } else if (name === 'ImmersiveSourceManager') {
      ImmersiveSourceManager()
    } else if (name === 'ImmersivePlaylist') {
      ImmersivePlaylist()
    } else if (name === 'ImmersiveStatistics') {
      ImmersiveStatistics()
    } else if (name === 'ImmersiveDownload') {
      ImmersiveDownload()
    } else if (name === 'ImmersiveAggregation') {
      ImmersiveAggregation()
    }
  }

  aboutToAppear(): void {
    // 3.0：首屏即沉浸播放页（设计规范 §0/§3）
    this.rootInit()
    if (Log.hasPendingCrash()) {
      this.crashSheetShow = true
    }
    this.pageStack.replacePath({ name: 'ImmersivePlayer' })
    let pressure_change_judge = PreferencesCache.getUserPreference('pressure_change', '0')
    if (pressure_change_judge === '1') {
      try {
        // const TAG: string = '[PublishOperation]';
        const DOMAIN_NUMBER: number = 0xFF00;
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        notificationManager.isNotificationEnabled().then((data: boolean) => {
          hilog.info(DOMAIN_NUMBER, TAG, "isNotificationEnabled success, data: " + JSON.stringify(data));
          if (!data) {
            notificationManager.requestEnableNotification(context).then(() => {
              hilog.info(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification success`);
            }).catch((err: BusinessError) => {
              if (1600004 == err.code) {
                hilog.error(DOMAIN_NUMBER, TAG,
                  `[ANS] requestEnableNotification refused, code is ${err.code}, message is ${err.message}`);
              } else {
                hilog.error(DOMAIN_NUMBER, TAG,
                  `[ANS] requestEnableNotification failed, code is ${err.code}, message is ${err.message}`);
              }
            });
          }
        }).catch((err: BusinessError) => {
          hilog.error(DOMAIN_NUMBER, TAG, `isNotificationEnabled fail, code is ${err.code}, message is ${err.message}`);
        });

        sensor.on(sensor.SensorId.BAROMETER, (data: sensor.BarometerResponse) => {
          //过去气压获取
          let prevAtmospheric_pressure: number = AppStorage.get('Atmospheric_pressure') ?? data.pressure
          //过去差值获取
          let Atmospheric_pressure_change_prev: number = AppStorage.get('Atmospheric_pressure_change') ?? 0
          // 计算累积差值
          let Atmospheric_pressure_change: number =
            prevAtmospheric_pressure - data.pressure + Atmospheric_pressure_change_prev
          if (Atmospheric_pressure_change >= 50 || Atmospheric_pressure_change <= -50) {
            console.info('jizhishi_debug Succeeded in invoking on. Atmospheric_pressure_change: ' +
              Atmospheric_pressure_change);
            Atmospheric_pressure_change = 0

            let notificationRequest: notificationManager.NotificationRequest = {
              id: 114514,
              notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
              content: {
                notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
                normal: {
                  title: '气压变化超50百帕',
                  text: '当前气压:' + data.pressure.toFixed(3) + '百帕',
                  // additionalText: 'test_additionalText',
                }
              }
            };
            notificationManager.publish(notificationRequest, (err: BusinessError) => {
              if (err) {
                hilog.error(DOMAIN_NUMBER, TAG,
                  `Failed to publish notification. Code is ${err.code}, message is ${err.message}`);
                return;
              }
              hilog.info(DOMAIN_NUMBER, TAG, 'Succeeded in publishing notification.');
            });
          }

          AppStorage.setOrCreate('Atmospheric_pressure_change', Atmospheric_pressure_change)
          AppStorage.setOrCreate('Atmospheric_pressure', data.pressure)
          console.info('jizhishi_debug Succeeded in invoking on. Atmospheric pressure: ' + data.pressure);
        }, { interval: 100000000 });
        // setTimeout(() => {
        //   sensor.off(sensor.SensorId.BAROMETER);
        // }, 500);
      } catch (error) {
        let e: BusinessError = error as BusinessError;
        console.error(`jizhishi_debug Failed to invoke on. Code: ${e.code}, message: ${e.message}`);
      }
      let publishCallback = (err: BusinessError): void => {
        if (err) {
          console.error(`publish failed, code is ${err.code}, message is ${err.message}`);
        } else {
          console.info("publish success");
        }
      }

    }
    const TAG: string = '[PublishOperation]';
    const DOMAIN_NUMBER: number = 0xFF00;
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    notificationManager.isNotificationEnabled().then((data: boolean) => {
      hilog.info(DOMAIN_NUMBER, TAG, "isNotificationEnabled success, data: " + JSON.stringify(data));
      if (!data) {
        notificationManager.requestEnableNotification(context).then(() => {
          hilog.info(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification success`);
        }).catch(() => {
          // if(1600004 == err.code){
          //   hilog.error(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification refused, code is ${err.code}, message is ${err.message}`);
          // } else {
          //   hilog.error(DOMAIN_NUMBER, TAG, `[ANS] requestEnableNotification failed, code is ${err.code}, message is ${err.message}`);
          // }
        });
      }
    }).catch(() => {
      // hilog.error(DOMAIN_NUMBER, TAG, `isNotificationEnabled fail, code is ${err.code}, message is ${err.message}`);
    });
  }

  // aboutToDisappear(): void {
  //
  // }
  onPageHide(): void {

  }

  build() {
    Navigation(this.pageStack) {
      // empty
    }
    .onKeyEvent(async (event?: KeyEvent) => {
      // 通过stopPropagation阻止事件冒泡
      let names = this.pageStack.getAllPathName();
      let pageName = names[names.length-1];
      if (['ImmersivePlayer'].includes(pageName)) {
        if (event) {
          if (event.stopPropagation) {
            event.stopPropagation();
          }
          if (event.type === KeyType.Up) {
            // this.buttonType = 'Down';
            if (event.keyCode === 2050) {
              const player = await avPlayerManager.getAVPlayerInstance()
              // player.ge
              if (player.getState() === audio.AudioState.STATE_RUNNING
              ) {
                player.pause().catch(() => {
                  // TODO: Implement error handling.
                })
              } else {
                player.resume().catch(() => {
                  // TODO: Implement error handling.
                })
              }

            }
          }
          // if (event.type === KeyType.Up) {
          //   this.buttonType = 'Up';
          // }
          // this.buttonText = 'Button: \n' +
          //   'KeyType:' + this.buttonType + '\n' +
          //   'KeyCode:' + event.keyCode + '\n' +
          //   'KeyText:' + event.keyText;
        }

      } else {

      }
    })
    .navDestination(this.PageMap)
    .hideNavBar(true)
    .mode(NavigationMode.Stack)
    .bindSheet($$this.crashSheetShow, this.CrashReportSheetContent(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      onDisappear: () => {
        Log.consumePendingCrash()
      }
    })
  }
}

