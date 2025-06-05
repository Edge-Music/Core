import { SourceAdapter } from '../adapter';
import { PlaylistList } from '../component/PlaylistList';
import { StyleConstants } from '../constants/StyleConstants';
// import { Index_page } from '../pages/Index';
import { Playlist } from '../type/Adapter';
import { cover } from '../util/AdapterHelper';

import { PushPathHelper } from '../util/PushPathHelper';
import { PlayListfor2in1 } from './Playlist_2in1';
import { Setting } from '../view/Setting';
import { InputMethodListDialog } from '@ohos.inputMethodList';
import { Index_page } from './Index_2in1';
import { MiniPlaybackControl } from '../component/MiniPlaybackControl';
import { Setting_2in1 } from './Setting_for2in1';
import { MultiSearch_2in1 } from './MultiSearch_2in1';

// import { Index_page } from '../pages/Index';

// import { Index_page } from './ex_2in1'

// import { PlayList } from './Playlist';

@Builder
export function FOR_2IN1_UI(){
  IS_2IN1_UI()
}
@Component
export  struct IS_2IN1_UI{
  @Consume('NavPathStack') pageStack: NavPathStack;
  @StorageLink('user_playlist') playlists: Playlist[] = [];
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm'
  @StorageProp('2in1title') title:string='首页'
  @Watch('_2in1page_judge')@StorageProp('2in1page_judge') page_judge:string =                   AppStorage.get('2in1page_judge')??'index'

  @State sidebar_ctrl:boolean =false
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('topRect') topRect: number = 0
  aboutToAppear(): void {
   this.sidebar_ctrl = this.currentBreakpoint==='sm'? false:true
  }
  _2in1page_judge(){
    this.page_judge=                   AppStorage.get('2in1page_judge')??'index'
  }
  @Builder
  /**
   *
   *  @param  button_list()  这就是个列表展开关闭按键的UI
   */
  button_list(){
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
    }.width(25).height(25)

  }
  @Builder
  Titlebar(){
    Row(){
      Column().width(40).height(40)
      Text(this.title)
        .fontSize(30)
        .layoutWeight(1)
      Blank()
      Button('设置').onClick(()=>{
        this.page_judge='Setting'
        AppStorage.setOrCreate('2in1page_judge',"Setting")

        this.title ='设置'
      }).margin({right: AppStorage.get("devicetype")==='2in1'?150:16})
    }.width('100%').alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start).padding({left:16})

  }
  build() {
    Column(){
    Stack(){
      Stack(){
        SideBarContainer(this.currentBreakpoint==='sm'? SideBarContainerType.Overlay:SideBarContainerType.Embed){
          Column(){
            Column(){
              Row(){

                Button('搜索').onClick(()=>{
                  this.page_judge='search'
                  AppStorage.setOrCreate('2in1page_judge',"search")
                  this.title='搜索'
                })
              }
            }.height(50).width('100%').padding({left:50})
            List({space:8}){
              ListItem(){
                Column(){
                  Text('首页').fontSize(36)
                  Divider().width('100%').color(this.title==='首页'?'#05468c':'#000000')
                    .strokeWidth(this.title==='首页'?3:1)
                }
              }.onClick(()=>{
                this.page_judge='index'
                AppStorage.setOrCreate('2in1page_judge',"index")
                this.title='首页'
              })
              ForEach(this.playlists,(playlist:Playlist)=>{
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
                      Divider().width('100%')
                    }
                    // .backgroundColor(this.title===playlist?.name ?'#123456':'#00000000')
                    .onClick(async ()=>{
                      this.page_judge='playlist'
                      this.title=playlist?.name || '未知歌单'
                      AppStorage.setOrCreate('2in1page_judge',"playlist")

                      const playlistitem = await SourceAdapter.getPlaylistDetail(playlist)
                      AppStorage.setOrCreate('current_playlist_data', playlistitem)
                    }).width(300)

                    if (this.title===playlist?.name) {
                      Divider()
                        .color('#05468c')//
                        .strokeWidth(3)
                        .width('90%')
                    }
                  }

                }
              })
              ListItem(){
                Column().height(100)
              }
            }
          }.expandSafeArea().width(300) .backgroundColor($r('app.color.page_background'))
          Column(){
            this.Titlebar()
            if (this.page_judge==='index'){
              Index_page()//index_2in1 等待适配
            }else if (this.page_judge==='Setting'){
               Setting_2in1()
            }else if (this.page_judge==='playlist'){
              PlayListfor2in1()
            }else if (this.page_judge==='search'){
              MultiSearch_2in1()

            }
          }
          .scale(this.sidebar_ctrl&&this.currentBreakpoint==='sm'?{x:0.95,y:0.95}:{})
          .blur(this.sidebar_ctrl&&this.currentBreakpoint==='sm'?20:1)
        }
        .showSideBar($$this.sidebar_ctrl)
        .sideBarWidth(300)
        .maxSideBarWidth(300)
        .minSideBarWidth(300)
        .controlButton({
          height:0,
          width:0
        })
        MiniPlaybackControl()
      }.alignContent(Alignment.Bottom)

      Column(){
        this.button_list()
      }.justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center) .width(40).height(40).margin({left:16}).onClick(()=>{
        animateTo({
          duration: 250,
          curve: Curve.EaseOut,
          delay: 0,
          onFinish: () => {

          }
        }, () => {
          this.sidebar_ctrl=!this.sidebar_ctrl
        });

      })
    }.alignContent(Alignment.TopStart)

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
    .padding({top:this.topRect/3})
    .gesture(
      PanGesture({ direction: PanDirection.Right })

        .onActionUpdate((event) => {
          // 更新滑动偏移量
            let test =event.offsetX;
          if (test>70) {
            animateTo({
              duration: 250,
              curve: Curve.EaseOut,
              delay: 0,
              onFinish: () => {

              }
            }, () => {
              this.sidebar_ctrl = true
            });

          }else if (test<-70){
            animateTo({
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



  in1page_judge(changedPropertyName: string) {
  }
}