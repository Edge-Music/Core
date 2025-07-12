
@Component
export struct AddAggregationPlaylist {
  @Link playlistDesc: string
  @Link playlistName: string

  build() {
    Column(){
      List({ space: 10 }){
        ListItem(){
          Column(){
            Text($r('app.string.playlist_name'))
              .fontSize(16)
              .fontWeight(700)
              .margin({ left: 14 })
            TextInput({ placeholder: $r('app.string.playlist_name_placeholder'), text: this.playlistName })
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
            Text($r('app.string.playlist_description'))
              .fontSize(16)
              .fontWeight(700)
              .margin({ left: 16 })
            TextArea({ placeholder: $r('app.string.playlist_desc_placeholder'), text: this.playlistDesc })
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