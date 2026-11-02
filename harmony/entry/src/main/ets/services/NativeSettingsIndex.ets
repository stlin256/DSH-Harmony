/** Pure, bilingual settings discovery index. UI navigation stays in NativeSettings. */
export class NativeSettingsEntry {
  id: string = '';
  page: string = 'root';
  title: string = '';
  detail: string = '';
  path: string = '';
  synonyms: string[] = [];
  rank: number = 0;
}

export class NativeSettingsHit {
  entry: NativeSettingsEntry = new NativeSettingsEntry();
  score: number = 0;
  matchedSynonym: string = '';
}

function entry(id: string, page: string, title: string, detail: string, path: string,
  synonyms: string[], rank: number = 0): NativeSettingsEntry {
  const value = new NativeSettingsEntry();
  value.id = id;
  value.page = page;
  value.title = title;
  value.detail = detail;
  value.path = path;
  value.synonyms = synonyms;
  value.rank = rank;
  return value;
}

export function nativeSettingsEntries(): NativeSettingsEntry[] {
  return [
    entry('dsh', 'dsh', 'DSH 设置', '对话与过程展示', 'DSH 设置',
      ['对话', '聊天', '过程', '思考', 'chat', 'transcript', 'reasoning'], 5),
    entry('dsh.transcript', 'dsh', '工作步骤展示', '简洁、标准、详细、完全展开', 'DSH 设置 · 对话',
      ['工作过程', '步骤', '展示', 'transcript view', 'verbose', 'detailed'], 3),
    entry('dsh.collapse', 'dsh', '过程收起时机', '完成时或下次发送时', 'DSH 设置 · 对话',
      ['折叠', '收起', 'collapse timing', 'next input'], 2),
    entry('dsh.folded', 'dsh', '收起后显示回复', '全部回复或仅最终回答', 'DSH 设置 · 对话',
      ['回复', '最终回答', 'folded replies', 'final'], 2),
    entry('dsh.busy', 'dsh', '运行时发送', '排队或立即干预', 'DSH 设置 · 对话',
      ['忙碌', '发送', '排队', '干预', 'busy enter', 'queue', 'steer'], 3),
    entry('appearance', 'appearance', '外观与动效', '主题、动态效果与透明度', '外观与动效',
      ['外观', '主题', '动画', 'appearance', 'theme', 'motion'], 5),
    entry('appearance.theme', 'appearance', '主题', '浅色、深色或跟随系统', '外观与动效 · 主题',
      ['深色', '浅色', '跟随系统', 'dark', 'light', 'system'], 3),
    entry('appearance.motion', 'appearance', '减少动态效果', '关闭页面与抽屉动画', '外观与动效 · 动效',
      ['动画', '动态', 'reduce motion', 'animation'], 3),
    entry('appearance.transparency', 'appearance', '减少透明效果', '使用不透明表面', '外观与动效 · 动效',
      ['透明', '材质', 'reduce transparency', 'material'], 3),
    entry('notifications', 'notifications', '通知', '任务级别、权限与系统推送', '通知',
      ['推送', '消息', '提醒', 'notification', 'push'], 5),
    entry('notifications.approval', 'notifications', '需要确认', '等待批准或选择时通知', '通知 · 通知级别',
      ['审批', '确认', 'approval', 'waiting'], 3),
    entry('notifications.failed', 'notifications', '任务失败', '任务异常结束时通知', '通知 · 通知级别',
      ['失败', '错误', 'failed', 'error'], 3),
    entry('notifications.completed', 'notifications', '任务完成', '任务正常结束时通知', '通知 · 通知级别',
      ['完成', '成功', 'completed', 'success'], 3),
    entry('notifications.connection', 'notifications', '连接异常', '服务连接中断时通知', '通知 · 通知级别',
      ['断线', '连接', 'connection', 'offline'], 2),
    entry('notifications.push', 'notifications', '系统推送', 'Push Kit 或后台任务监控', '通知 · 投递',
      ['推送', '后台', 'push kit', 'background monitor'], 3),
    entry('notifications.test', 'notifications', '发送测试通知', '验证通知权限和跳转', '通知 · 投递',
      ['测试', '权限', 'test notification'], 2),
    entry('notifications.system', 'notifications', '系统通知设置', '打开系统权限页面', '通知 · 投递',
      ['权限', '系统设置', 'system notification'], 2),
    entry('cards', 'cards', '桌面卡片', '任务名称、隐私与同步', '桌面卡片',
      ['小组件', '服务卡片', 'widget', 'card'], 4),
    entry('cards.taskName', 'cards', '显示任务名称', '关闭后显示匿名数量和状态', '桌面卡片 · 隐私',
      ['隐私', '任务名', 'widget details', 'privacy'], 3),
    entry('cards.sync', 'cards', '立即同步', '刷新任务数量', '桌面卡片 · 同步',
      ['刷新', '同步', 'sync', 'refresh'], 2),
    entry('storage', 'storage', '存储管理', '缓存池、占用与清理', '存储管理',
      ['缓存', '空间', '清理', 'storage', 'cache'], 5),
    entry('storage.pool', 'storage', '缓存池', '查看上限和当前账户占用', '存储管理 · 缓存池',
      ['容量', '上限', 'cache pool', 'quota'], 3),
    entry('storage.clear', 'storage', '清空缓存', '删除本机会话、文件与图片缓存', '存储管理 · 清理',
      ['清理', '删除', 'clear cache', 'reset'], 3),
    entry('connection', 'connection', '服务与账户', '连接地址、登录和退出', '服务与账户',
      ['服务器', '账户', '登录', 'server', 'account', 'login'], 5),
    entry('connection.server', 'connection', '当前服务', '查看当前服务地址', '服务与账户 · 服务',
      ['地址', '主机', 'server', 'origin', 'host'], 3),
    entry('connection.logout', 'connection', '退出登录', '清除连接与本地会话缓存', '服务与账户 · 账户',
      ['登出', '注销', 'logout', 'sign out'], 3),
    entry('about', 'about', '关于', '版本、开源许可与项目信息', '关于',
      ['版本', '许可', '项目', 'version', 'license', 'project'], 3)
  ];
}

export function nativeNormalizeSettingsQuery(value: string): string {
  let output = '';
  for (let index = 0; index < value.length; index++) {
    let code = value.charCodeAt(index);
    if (code === 0x3000) continue;
    if (code >= 0xFF01 && code <= 0xFF5E) code -= 0xFEE0;
    const character = String.fromCharCode(code);
    if (!character.trim()) continue;
    output += character.toLowerCase();
  }
  return output;
}

class NativeSettingsMatch {
  score: number = 0;
  synonym: string = '';
}

function bestMatch(entryValue: NativeSettingsEntry, query: string): NativeSettingsMatch | null {
  const title = nativeNormalizeSettingsQuery(entryValue.title);
  let score = 0;
  let synonym = '';
  if (title === query) {
    score = 100;
  } else if (title.startsWith(query)) {
    score = 80;
  } else if (title.includes(query)) {
    score = 60;
  }
  entryValue.synonyms.forEach((value: string): void => {
    const normalized = nativeNormalizeSettingsQuery(value);
    if (!normalized) return;
    if (score < 50 && normalized === query) {
      score = 50;
      synonym = value;
    } else if (score < 40 && normalized.includes(query)) {
      score = 40;
      synonym = value;
    }
  });
  if (score < 20) {
    const detail = nativeNormalizeSettingsQuery(entryValue.detail + ' ' + entryValue.path);
    if (detail.includes(query)) score = 20;
  }
  if (!score) return null;
  const result = new NativeSettingsMatch();
  result.score = score;
  result.synonym = synonym;
  return result;
}

export function nativeSearchSettings(query: string, limit: number = 20): NativeSettingsHit[] {
  const normalized = nativeNormalizeSettingsQuery(query);
  if (!normalized) return [];
  const hits: NativeSettingsHit[] = [];
  nativeSettingsEntries().forEach((value: NativeSettingsEntry): void => {
    const match = bestMatch(value, normalized);
    if (!match) return;
    const hit = new NativeSettingsHit();
    hit.entry = value;
    hit.score = match.score + Math.min(5, Math.max(0, value.rank));
    hit.matchedSynonym = match.synonym;
    hits.push(hit);
  });
  hits.sort((left: NativeSettingsHit, right: NativeSettingsHit): number => {
    if (left.score !== right.score) return right.score - left.score;
    return 0;
  });
  const bounded = Number.isSafeInteger(limit) && limit > 0 ? limit : 20;
  return hits.slice(0, bounded);
}
