import { SourceAdapter } from '../adapter';
import { StyleConstants } from '../constants/StyleConstants';
import { Playlist } from '../type/Adapter';
import { cover } from '../util/AdapterHelper';
import { PlayListFor2in1 } from './Playlist_2in1';
import { Index_page } from './Index_2in1';
import { MiniPlaybackControl } from '../component/MiniPlaybackControl';
import { Setting_2in1 } from './Setting_for2in1';
import { MenuIcon } from '../component/MenuIcon';

@Component
export struct IS_2IN1_UI{
  @StorageProp('decorHeight') decorHeight: number = 0
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageLink('user_playlist') playlists: Playlist[] = [];
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm'
  @Link page_judge: string
  @State sidebar_ctrl: boolean = false
  @Link title: string
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  uiContext: UIContext | undefined = undefined;
  aboutToAppear(): void {
   this.sidebar_ctrl = this.currentBreakpoint === 'sm' ? false : true
    this.uiContext = this.getUIContext();
    if (!this.uiContext) {
      console.warn("no uiContext");
      return;
    }
  }
  @Builder
  /**
   *
   *  @param  button_list()  这就是个列表展开关闭按键的UI
   */
  button_list(){
    Row() {
      Row() {
        Button({ type: ButtonType.Circle }){
          Column(){
            Row().width(25).height(2.5).backgroundColor($r("app.color.text_primary")).opacity(0)
            Row().width(25).height(4).backgroundColor($r("app.color.text_primary"))
              .translate({x:0,y:this.sidebar_ctrl?8:0})
              .rotate({
                x: 0,
                y: 0,
                z: 1,
                angle: this.sidebar_ctrl?45:0
              })
            Row().width(25).height(4).backgroundColor($r("app.color.text_primary")).opacity(0)
            Row().width(25).height(4).backgroundColor($r("app.color.text_primary")).opacity(this.sidebar_ctrl?0:1).translate({x:this.sidebar_ctrl?-8:0,y:0})
            Row().width(25).height(4).backgroundColor($r("app.color.text_primary")).opacity(0)
            Row().width(25).height(4).backgroundColor($r("app.color.text_primary"))
              .translate({x:0,y:this.sidebar_ctrl?-8:0})
              .rotate({
                x: 0,
                y: 0,
                z: 1,
                angle: this.sidebar_ctrl?-45:0
              })
            Row().width(25).height(2.5).backgroundColor($r("app.color.text_primary")).opacity(0)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width(25)
          .height(25)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(()=>{
          this.uiContext?.animateTo({
            duration: 250,
            curve: Curve.EaseOut,
            delay: 0,
            onFinish: () => {
            }
          }, () => {
            this.sidebar_ctrl = !this.sidebar_ctrl
          });
        })

        Row(){
          if(this.sidebar_ctrl){
            Text($r('app.string.library'))
              .fontColor($r('app.color.text_title'))
              .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
              .fontSize($r('app.float.title_font_size'))
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        if(this.sidebar_ctrl){
          Button({ type: ButtonType.Circle }){
            Text('󰀩')
              .fontColor($r('app.color.text_title'))
              .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
              .fontSize($r('app.float.title_font_size'))
          }
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(()=>{
            this.pageStack.pushPath({ name: 'MultiSearch' })
          })
          .margin({ right:16 })
        }
      }
      .margin({ left: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
    .height(StyleConstants.TITLE_HEIGHT)
    .width(this.sidebar_ctrl ? 300 : 100)
    .animation({
      duration: 250,
      curve: Curve.FastOutSlowIn
    })
  }

  @Builder
  TitleBar(){
    Column(){
      // PC工具栏适配
      Row()
        .height(this.topRect)
        .width('100%')
        .visibility(this.topRect > 0 ? Visibility.Visible : Visibility.None)

      Row()
        .height(this.decorHeight)
        .width('100%')
        .visibility(this.decorHeight > 0 ? Visibility.Visible : Visibility.None)

      Row() {
        Row()
          .height(StyleConstants.TITLE_HEIGHT)
          .aspectRatio(1)

        Row(){
          Text(this.title)
            .fontColor($r('app.color.text_title'))
            .fontWeight(StyleConstants.FONT_WEIGHT_SEVEN)
            .fontSize($r('app.float.title_font_size'))
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
        }
        .layoutWeight(1)
        .height(StyleConstants.TITLE_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        this.MenuRight()
      }
      .padding({ left: 16, right: 16})
      .justifyContent(FlexAlign.SpaceBetween)
      .width(StyleConstants.FULL_WIDTH)
      .alignItems(VerticalAlign.Center)
      .height(50)
    }
    .height(this.topRect+StyleConstants.TITLE_HEIGHT+this.decorHeight)
  }

  @Builder
  MenuRight(){
    MenuIcon({
      icon: this.page_judge === 'index' ? $r('app.media.ic_gearshape') : $r('app.media.house')
    })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => {
        if(this.page_judge === 'index'){
          this.page_judge = 'Setting'
          this.title = '设置'
        } else {
          this.page_judge = 'index'
          this.title = '首页'
        }
      })
      .animation({
        duration: 250,
        curve: Curve.FastOutSlowIn
      })
  }

  @Builder
  ButtonShowList(){
    Column(){
      // PC工具栏适配
      if(this.topRect > 0){
        Row()
          .height(this.topRect)
      }
      if(this.decorHeight > 0){
        Row(){
          Image($r('app.media.icon'))
            .height(this.decorHeight/2)
            .width(this.decorHeight/2)
            .margin({ left: 16 })
          Blank().width(5)
          Text('云享社')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_title'))
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .height(this.decorHeight)
      }

      this.button_list()
    }
    .height(this.decorHeight+this.topRect+StyleConstants.TITLE_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  OverlayInterceptor() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.uiContext?.animateTo({
          duration: 250,
          curve: Curve.EaseOut,
          delay: 0,
          onFinish: () => {
          }
        }, () => {
          this.sidebar_ctrl = false
        });
      })
  }

  build() {
    Column(){
      Stack(){
        Stack(){

          SideBarContainer(this.currentBreakpoint === 'sm' ? SideBarContainerType.Overlay : SideBarContainerType.Embed){
            Column(){
              Column(){
                Row()
                  .height(this.topRect)
                  .visibility(this.topRect > 0 ? Visibility.Visible : Visibility.None)

                Row()
                  .justifyContent(FlexAlign.Start)
                  .alignItems(VerticalAlign.Center)
                  .height(this.decorHeight)
                  .visibility(this.decorHeight > 0 ? Visibility.Visible : Visibility.None)

                Row()
                  .height(StyleConstants.TITLE_HEIGHT)
              }
              .height(this.decorHeight+this.topRect+StyleConstants.TITLE_HEIGHT)


              List({space:8}){
                ForEach(this.playlists, (playlist: Playlist) => {
                  ListItem(){
                    Column(){
                      Row(){
                        Stack({ alignContent: Alignment.BottomStart }) {
                          Image(cover(playlist?.cover || '', 120))
                            .width(58)
                            .height(58)
                            .objectFit(ImageFit.Cover)
                            .borderRadius(8)
                        }
                        .margin({ right: 12,left:12 })
                        Column(){
                          Text(playlist?.name || '未知歌单')
                            .fontSize(15)
                            .fontWeight(StyleConstants.FONT_WEIGHT_FIVE)
                            .fontColor($r('app.color.text_primary'))
                            .maxLines(2)
                            .width('100%')
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }.height(58).width(300-58-12-12).padding({right:16}).justifyContent(FlexAlign.Center)
                      }
                      .hoverEffect(HoverEffect.Scale)
                      .clickEffect({ level: ClickEffectLevel.LIGHT })
                      .onClick(async ()=>{
                        this.page_judge='playlist'
                        this.title=playlist?.name || '未知歌单'

                        const playlistItem = await SourceAdapter.getPlaylistDetail(playlist)
                        AppStorage.setOrCreate('current_playlist_data', playlistItem)
                      }).width(300)

                    }

                  }
                })
                ListItem(){
                  Row() {
                    Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + this.bottomRect + this.topRect + this.decorHeight + 50)
                  }
                }
              }
            }
            .width(300)
            .backgroundColor($r('app.color.page_background'))

            Stack(){
              Column(){
                Column(){
                  this.TitleBar()
                }
                .backgroundColor($r('app.color.page_background'))
                Stack(){
                  if(this.page_judge === 'index'){
                    Index_page()//index_2in1 等待适配
                  }else if (this.page_judge === 'Setting'){
                    Setting_2in1()
                  }else if (this.page_judge === 'playlist'){
                    PlayListFor2in1()
                  }
                }
              }
              .zIndex(1)
              .scale(this.sidebar_ctrl && this.currentBreakpoint === 'sm' ? { x: 0.95, y: 0.95 } : {})
              .blur(this.sidebar_ctrl && this.currentBreakpoint === 'sm' ? 20 : 0)

              Column(){
                this.OverlayInterceptor()
              }
              .zIndex(this.sidebar_ctrl && this.currentBreakpoint === 'sm' ? 99 : 0)
            }

          }
          .showSideBar(this.sidebar_ctrl)
          .sideBarWidth(300)
          .maxSideBarWidth(300)
          .minSideBarWidth(300)
          .showControlButton(false)
          .onChange((value: boolean) => {
            console.info('status:' + value);
            this.uiContext?.animateTo({
              duration: 250,
              curve: Curve.EaseOut,
              delay: 0,
              onFinish: () => {
              }
            }, () => {
              this.sidebar_ctrl = value

            });
          })
          MiniPlaybackControl()
        }
        .alignContent(Alignment.Bottom)

        this.ButtonShowList()
      }
      .alignContent(Alignment.TopStart)

      // Column(){
      //   PlaylistList({
      //     playlists: [...this.playlists],
      //     sIndex: 1,
      //     subTitleIndex: 1,
      //     is_2in1:true,
      //     adapters: [],
      //     onPlaylistSelected: async (item: Playlist) => {
      //       const playlist = await SourceAdapter.getPlaylistDetail(item)
      //       AppStorage.setOrCreate('current_playlist_data', playlist)
      //       // })
      //     }
      //   })
      // }.layoutWeight(1)
      // .width('100%')
      // .height('100%')
    }
    .gesture(
      PanGesture({ direction: PanDirection.Right })
        .onActionUpdate((event) => {
          // 更新滑动偏移量
            let test =event.offsetX;
          if (test > 70) {
            this.uiContext?.animateTo({
              duration: 250,
              curve: Curve.EaseOut,
              delay: 0,
              onFinish: () => {

              }
            }, () => {
              this.sidebar_ctrl = true
            });

          }else if (test < -70){
            this.uiContext?.animateTo({
              duration: 250,
              curve: Curve.EaseOut,
              delay: 0,
              onFinish: () => {

              }
            }, () => {
              this.sidebar_ctrl = false
            });
          }

        })
    )
  }
}