
@Component
export struct AddAggregationPlaylist {
  @Link playlistDesc: string
  @Link playlistName: string

  build() {
    Column(){
      List({ space: 10 }){
        ListItem(){
          Column(){
            Text('歌单名称')
              .fontSize(16)
              .fontWeight(700)
              .margin({ left: 14 })
            TextInput({ placeholder: '请输入歌单名称', text: this.playlistName })
              .width('100%')
              .margin({ top: 5 })
              .onChange((value: string) => {
                this.playlistName = value;
              })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }

        ListItem(){
          Column() {
            Text('歌单描述')
              .fontSize(14)
              .fontWeight(700)
              .margin({ left: 16 })
            TextArea({ placeholder: '请输入歌单描述', text: this.playlistDesc })
              .width('100%')
              .height(120)
              .margin({ top: 5 })
              .onChange((value: string) => {
                this.playlistDesc = value;
              })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('auto')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}