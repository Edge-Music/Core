export const ENTRY_ABILITY = 'EntryAbility';

export enum FormCarAction {
  CALL = 'call',
  ROUTER = 'router'
}

export enum FormCardName {
  CONTROL_2X2 = 'PlayControlCard2x2',
  CONTROL_2X4 = 'PlayControlCard2x4',
  RECOMMENDED_1X2 = 'RecommendedMusic1x2',
  RECOMMENDED_2X4 = 'RecommendedMusic2x4',
}

export enum PlayActionType {
  PAUSE = '0',
  PLAY = '1',
  PREVIOUS = '2',
  NEXT = '3',
}

export enum CallMethod {
  REQUEST_UPDATE_CARD = 'requestUpdatePlayCard',
  PLAY_BY_ACTION = 'playByAction',
  COLLECT_ACTION = 'collectAction',
}

export enum CollectAction {
  COLLECTED = '1',
  UNCOLLECTED = '0'
}

export enum RouterType {
  PLAYER = 'Playing',
  LYRICS = '2',
  PLAYLISTS = 'Library',
  COLLECTED = '4'
}