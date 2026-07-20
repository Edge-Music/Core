import { LogUtil, PreferencesUtil } from '@pura/harmony-utils';
import { PreferencesCache } from './PreferenceCache';

export class ResponseCacheUtil {
  private static EXPIRATION_PREFIX = '_exp_';
  private static KEY_PREFIX = '_cache_';
  private static CREATED_AT_PREFIX = '_created_';
  private static PREFERENCE_NAME = 'response_cache';

  static setPrefix(prefix: string): void {
    ResponseCacheUtil.KEY_PREFIX = prefix;
  }

  private static getFullKey(key: string): string {
    return `${ResponseCacheUtil.KEY_PREFIX}${key}`;
  }

  static set<T>(key: string, value: T, expireTime?: number): void {
    // 未显式指定过期时间时按配置项换算（3.0 默认 0 天）
    if (!expireTime) {
      expireTime = 24 * 60 * 60 * 1000 * PreferencesCache.requestCacheExpire();
    }
    // 过期时间 <= 0 即「不缓存」：直接跳过写入，避免堆积立即过期的垃圾缓存
    if (expireTime <= 0) {
      return;
    }

    const fullKey = ResponseCacheUtil.getFullKey(key);
    const stringValue = typeof value === 'string' ? value : JSON.stringify(value);

    PreferencesUtil.putSync(fullKey, stringValue, ResponseCacheUtil.PREFERENCE_NAME);

    // 保存缓存创建时间
    const createdAt = Date.now();
    PreferencesUtil.putSync(ResponseCacheUtil.CREATED_AT_PREFIX + fullKey, createdAt.toString(),
      ResponseCacheUtil.PREFERENCE_NAME);

    const expireAt = createdAt + expireTime;
    PreferencesUtil.putSync(ResponseCacheUtil.EXPIRATION_PREFIX + fullKey, expireAt.toString(),
      ResponseCacheUtil.PREFERENCE_NAME);
  }

  static get<T>(key: string, defaultValue?: T): T | undefined {
    const fullKey = ResponseCacheUtil.getFullKey(key);

    // 检查是否过期
    const expireAt = PreferencesUtil.getStringSync(ResponseCacheUtil.EXPIRATION_PREFIX + fullKey, undefined,
      ResponseCacheUtil.PREFERENCE_NAME);
    if (expireAt && Date.now() > Number(expireAt)) {
      ResponseCacheUtil.remove(key);
      return defaultValue ?? undefined;
    }

    const value = PreferencesUtil.getStringSync(fullKey, undefined, ResponseCacheUtil.PREFERENCE_NAME);
    if (!value) {
      return defaultValue ?? undefined;
    }

    try {
      return JSON.parse(value) as T;
    } catch {
      return value as T;
    }
  }

  static getExpireTime(key: string): number {
    const fullKey = ResponseCacheUtil.getFullKey(key);
    const expireAt = PreferencesUtil.getStringSync(ResponseCacheUtil.EXPIRATION_PREFIX + fullKey, undefined,
      ResponseCacheUtil.PREFERENCE_NAME);
    return Number(expireAt);
  }

  static getCreatedTime(key: string): number {
    const fullKey = ResponseCacheUtil.getFullKey(key);
    const createdAt = PreferencesUtil.getStringSync(ResponseCacheUtil.CREATED_AT_PREFIX + fullKey, undefined,
      ResponseCacheUtil.PREFERENCE_NAME);
    return Number(createdAt);
  }

  static has(key: string): boolean {
    const fullKey = ResponseCacheUtil.getFullKey(key);
    return PreferencesUtil.hasSync(fullKey, ResponseCacheUtil.PREFERENCE_NAME);
  }

  static remove(key: string): void {
    const fullKey = ResponseCacheUtil.getFullKey(key);
    PreferencesUtil.deleteSync(fullKey, ResponseCacheUtil.PREFERENCE_NAME);
    PreferencesUtil.deleteSync(ResponseCacheUtil.EXPIRATION_PREFIX + fullKey, ResponseCacheUtil.PREFERENCE_NAME);
    PreferencesUtil.deleteSync(ResponseCacheUtil.CREATED_AT_PREFIX + fullKey, ResponseCacheUtil.PREFERENCE_NAME);
  }

  static clear(): void {
    PreferencesUtil.clearSync(ResponseCacheUtil.PREFERENCE_NAME);
  }

  static size(): number {
    return Object.keys(PreferencesUtil.getAllSync(ResponseCacheUtil.PREFERENCE_NAME)).length;
  }
}