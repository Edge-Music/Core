import { ID } from "../type/Adapter";

export class FormInfo {
  formId: string = '';
  formName: string = '';
  formDimension: string = '';
}

export class FormControlData {
  loaded: boolean = true;
  formId: string = '';
  singer: string = '';
  title: string = '';
  isPlay: boolean = false;
  imageColor?: string = '#432422';
  songId: ID = '';
  isCollected: boolean = false;
  imageColorHex:string = '';
  imgName: string = '';
  formImages: Record<string, number> = {};
}