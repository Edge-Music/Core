import { ClickUtil } from "@pura/harmony-utils"
import { avPlayerManager } from "../util/AVPlayerManager";
import { PlaylistManager } from "../util/PlaylistManager"
import { audio } from "@kit.AudioKit";

@ComponentV2
export  struct HandingCtrl{
  @Local isPlaying:boolean = false
  @Event on_Click: () => void = () => {}
  private playerManager = avPlayerManager;
  // 必须持有同一个引用：removeListener 按引用相等过滤，
  // 原先注册匿名函数、注销时又传新的空函数，等于从未摘除过监听
  private handlePlay: () => void = () => {
    this.isPlaying = true;
  }
  private handlePause: () => void = () => {
    this.isPlaying = false;
  }
  aboutToAppear(): void {

    this.playerManager.getAVPlayerInstance().then(player => {
      this.isPlaying = player.getState() === audio.AudioState.STATE_RUNNING;
    });

    // 添加事件监听
    this.playerManager.addListener('onPlay', this.handlePlay);
    this.playerManager.addListener('onPause', this.handlePause);
  }
  aboutToDisappear(): void {
    this.playerManager.removeListener('onPlay', this.handlePlay)
    this.playerManager.removeListener('onPause', this.handlePause)
  }
  build() {
    Column({space:5}){

      // 下一首按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_prev'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.text_primary'))
      }
      .width(36)
      .height(36)

      .backgroundBlurStyle(BlurStyle.Thin)
      .backgroundColor('rgba(200, 200, 200, 0.1)')
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        ClickUtil.debounce(async () => {
          this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            const prevSong = PlaylistManager.playPrevious()
            if (prevSong) {
              PlaylistManager.playSong(prevSong)
            }
          })
        }, 500, "playPrev")
        this.on_Click()
      })
      // 播放/暂停按钮
      Button({ type: ButtonType.Circle }) {
        if(this.isPlaying){
          Image($r('app.media.ic_pause'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.text_primary'))

        }else{
          Image($r('app.media.ic_play'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.text_primary'))
            .margin({ left: 2 })
        }
      }
      .width(36)
      .height(36)
      .alignSelf(ItemAlign.Center)
      .backgroundBlurStyle(BlurStyle.Thin)
      .backgroundColor('rgba(179, 179, 179, 0.10)')
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        this.isPlaying = !this.isPlaying
        if (this.isPlaying) {
          this.playerManager.play();
        } else {
          this.playerManager.pause();
        }
        this.on_Click()

      })

      // 下一首按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_next'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.text_primary'))
      }
      .width(36)
      .height(36)
      .backgroundBlurStyle(BlurStyle.Thin)
      .backgroundColor('rgba(200, 200, 200, 0.1)')
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .onClick(() => {
        const nextSong = PlaylistManager.playNext();
        if (nextSong) {
          PlaylistManager.playSong(nextSong);
        }
        this.on_Click()

      })


    } .width(50).borderRadius('100%') .backgroundBlurStyle(10) .padding({top:8,bottom:8})
  }
}

