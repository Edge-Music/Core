import { HomePageMenu } from "../model/HomePageMenu"


export const HomePageMenuData = [
  new HomePageMenu($r('app.string.aggregation'), 'Aggregation'),
  new HomePageMenu($r('app.string.download'), 'Download'),
  new HomePageMenu($r('app.string.playlist'), 'Library'),
  new HomePageMenu($r('app.string.statistics'), 'Statistics'),
  // OMSP 3.0 入口（新路由并存，暂不替换首屏）；「我的」由播放页侧栏进入、设置由「我的」齿轮进入
  new HomePageMenu('沉浸播放 3.0', 'ImmersivePlayer'),
]
