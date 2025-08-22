export function cover(url?: string | Resource, size = 100): string | Resource{
  if(typeof url === 'string') {
    // 如果使用的是https://ui-avatars.com，则直接返回
    if (url.indexOf('ui-avatars.com') !== -1) {
      return url as string;
    }
    return `${url}?param=${size}y${size}`
  } else {
    return url as Resource
  }
}

export function sample<T>(arr: Array<T>) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export function shuffle<T>(arr: T[], count: number = arr.length): T[] {
  const shuffled = [...arr].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}