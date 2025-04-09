/**
 * 将过去的时间转换为友好的相对时间描述
 * @param pastTime 过去的时间（Date对象或时间戳）
 * @returns 友好的时间描述字符串
 */
export function formatRelativeTime(pastTime: Date | number): string {
  // 将输入转换为Date对象
  const pastDate = pastTime instanceof Date ? pastTime : new Date(pastTime);

  // 获取当前时间
  const now = new Date();

  // 计算时间差（毫秒）
  const diffMs = now.getTime() - pastDate.getTime();

  // 转换为秒、分钟、小时和天
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  // 根据时间差返回对应的描述
  if (diffMinutes < 5) {
    return '刚刚';
  } else if (diffMinutes < 60) {
    return `${diffMinutes}分钟前`;
  } else if (diffHours < 24) {
    return `${diffHours}小时前`;
  } else {
    return `${diffDays}天前`;
  }
}

/**
 * 从文件名或URL中提取文件扩展名
 * @param {string} filePath - 文件路径、文件名或URL
 * @return {string} 文件扩展名（带点，如".mp3"）或空字符串（无扩展名时）
 */
export function getFileExtension(filePath: string): string {
  // 首先处理可能存在的查询参数
  const pathWithoutQuery = filePath.split('?')[0];

  // 获取文件名（移除路径）
  const fileName = pathWithoutQuery.split('/').pop();

  // 如果没有文件名，返回空字符串
  if (!fileName) {
    return '';
  }

  // 提取扩展名
  const extMatch = fileName.match(/\.[^.]+$/);
  return extMatch ? extMatch[0] : '';
}