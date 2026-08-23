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