export const ENTRY_ABILITY = 'EntryAbility';

export enum FormCarAction {
  CALL = 'call',
  ROUTER = 'router'
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
  PLAYER = 'ImmersivePlayer',
  LYRICS = '2',
  COLLECTED = '4'
}