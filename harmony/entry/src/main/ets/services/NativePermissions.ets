/** Host-owned permission presets and display-only labels. */

export const nativePermissionReadOnly: string = 'read-only';
export const nativePermissionWorkspaceWrite: string = 'workspace-write';
export const nativePermissionFullAccess: string = 'danger-full-access';
export const nativePermissionAuto: string = 'auto';
export const nativePermissionCustom: string = 'custom';

export class NativePermissionOption {
  value: string = '';
  name: string = '';
  description: string = '';
}

export class NativePermissionCatalog {
  options: NativePermissionOption[] = [];
  defaultOptions: NativePermissionOption[] = [];
  defaultPreset: string = '';
}

export class NativePermissionSelection {
  currentValue: string = '';
}

function permissionPreset(value: string): string {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(value) ? value : '';
}

function permissionText(value: string, maxLength: number): string {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function copyOption(value: NativePermissionOption): NativePermissionOption | null {
  const option = new NativePermissionOption();
  option.value = permissionPreset(value?.value);
  option.name = permissionText(value?.name, 120);
  option.description = value?.description === undefined ? '' : permissionText(value.description, 320);
  if (!option.value || !option.name || (value?.description !== undefined && !option.description)) return null;
  return option;
}

export function nativePermissionCatalogFromJson(value: string): NativePermissionCatalog | null {
  let parsed: NativePermissionCatalog;
  try {
    parsed = JSON.parse(value) as NativePermissionCatalog;
  } catch (_) {
    return null;
  }
  if (!parsed || !Array.isArray(parsed.options) || !Array.isArray(parsed.defaultOptions) ||
      parsed.options.length > 32 || parsed.defaultOptions.length > 32) return null;
  const catalog = new NativePermissionCatalog();
  const optionValues: Set<string> = new Set<string>();
  for (const raw of parsed.options) {
    const option = copyOption(raw);
    if (!option || option.value === nativePermissionCustom || optionValues.has(option.value)) return null;
    optionValues.add(option.value);
    catalog.options.push(option);
  }
  const defaultValues: Set<string> = new Set<string>();
  for (const raw of parsed.defaultOptions) {
    const option = copyOption(raw);
    if (!option || option.value === nativePermissionCustom || option.value === nativePermissionAuto ||
        defaultValues.has(option.value) || !optionValues.has(option.value)) return null;
    defaultValues.add(option.value);
    catalog.defaultOptions.push(option);
  }
  catalog.defaultPreset = permissionPreset(parsed.defaultPreset);
  if (!catalog.defaultPreset || !defaultValues.has(catalog.defaultPreset)) return null;
  return catalog;
}

export function nativePermissionSelectionFromValue(value: NativePermissionSelection | null): NativePermissionSelection | null {
  if (!value) return null;
  const currentValue = permissionPreset(value.currentValue);
  if (!currentValue) return null;
  const selection = new NativePermissionSelection();
  selection.currentValue = currentValue;
  return selection;
}

export function nativePermissionOption(catalog: NativePermissionCatalog | null,
  value: string): NativePermissionOption | null {
  if (!catalog) return null;
  return catalog.options.find((option: NativePermissionOption): boolean => option.value === value) || null;
}

export function nativePermissionCanSelect(catalog: NativePermissionCatalog | null, value: string): boolean {
  return value !== nativePermissionCustom && permissionPreset(value).length > 0 &&
    nativePermissionOption(catalog, value) !== null;
}

export function nativePermissionRequiresRisk(value: string): boolean {
  return value === nativePermissionFullAccess || value === nativePermissionAuto;
}

export function nativePermissionLabel(option: NativePermissionOption | null, value: string): string {
  if (value === nativePermissionReadOnly) return '仅可查看';
  if (value === nativePermissionWorkspaceWrite) return '工作区内修改';
  if (value === nativePermissionFullAccess) return '完全权限';
  if (value === nativePermissionAuto) return '自动审查';
  if (value === nativePermissionCustom) return '自定义权限';
  return option?.name || value || '未知权限';
}

export function nativePermissionShortLabel(value: string): string {
  if (value === nativePermissionReadOnly) return '只读';
  if (value === nativePermissionWorkspaceWrite) return '工作区';
  if (value === nativePermissionFullAccess) return '完全';
  if (value === nativePermissionAuto) return '自动';
  if (value === nativePermissionCustom) return '自定义';
  return '权限';
}

export function nativePermissionIcon(value: string): string {
  if (value === nativePermissionReadOnly) return 'permission-read-only';
  if (value === nativePermissionWorkspaceWrite) return 'permission-workspace-write';
  if (value === nativePermissionFullAccess) return 'permission-full-access';
  if (value === nativePermissionAuto) return 'permission-auto-review';
  return 'personalization-outline';
}

export function nativePermissionDescription(option: NativePermissionOption | null, value: string): string {
  if (option?.description) return option.description;
  if (value === nativePermissionReadOnly) return '浏览和查询，不修改工作区';
  if (value === nativePermissionWorkspaceWrite) return '可修改当前工作区';
  if (value === nativePermissionFullAccess) return '减少确认并允许敏感操作';
  if (value === nativePermissionAuto) return '由 Host 自动审查高风险调用';
  if (value === nativePermissionCustom) return '当前沙箱与审批组合不属于预设';
  return '';
}

export function nativePermissionRiskDescription(value: string): string {
  if (value === nativePermissionAuto) {
    return '自动审查会减少逐次确认，并由 Host 对高风险调用作出自动判断。此选项可能产生额外模型调用。';
  }
  return '启用后会减少确认步骤，并允许智能体直接执行敏感操作、修改文件或运行外部命令。';
}
