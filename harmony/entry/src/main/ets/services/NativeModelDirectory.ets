export class NativeModelSelection { provider: string = ''; model: string = ''; reasoningEffort: string = ''; }
export class NativeModelEffort { id: string = ''; name: string = ''; description: string = ''; }
export class NativeModelReasoning { efforts: NativeModelEffort[] = []; defaultEffort: string = ''; }
export class NativeCatalogModel { id: string = ''; name: string = ''; reasoning: NativeModelReasoning | null = null; }
export class NativeModelProvider { id: string = ''; name: string = ''; models: NativeCatalogModel[] = []; }
export class NativeModelFailure { id: string = ''; name: string = ''; message: string = ''; }
export class NativeModelCatalog { default: NativeModelSelection = new NativeModelSelection(); groups: NativeModelProvider[] = []; failures: NativeModelFailure[] = []; }
class SelectionProjection { next: NativeModelSelection | null = null; }
class ProjectionValues { modelSelection: SelectionProjection | null = null; }
class ProjectionReply { values: ProjectionValues = new ProjectionValues(); }
class SelectionReply { selected: NativeModelSelection = new NativeModelSelection(); }
export class NativeModelDirectoryState {
  catalog: NativeModelCatalog = new NativeModelCatalog();
  selected: NativeModelSelection = new NativeModelSelection();
  generation: number = 0;
}
/** One directory per Session is shared by the composer caption and its selection panel. */
export class NativeModelDirectory {
  private entries: Map<string, NativeModelDirectoryState> = new Map<string, NativeModelDirectoryState>();
  private pending: Map<string, Promise<NativeModelDirectoryState>> = new Map<string, Promise<NativeModelDirectoryState>>();
  private call: (body: string) => Promise<string>;
  private changed: () => void;
  constructor(call: (body: string) => Promise<string>, changed: () => void = (): void => {}) { this.call = call; this.changed = changed; }
  state(id: string): NativeModelDirectoryState {
    let value = this.entries.get(id);
    if (!value) { value = new NativeModelDirectoryState(); this.entries.set(id, value); }
    return value;
  }
  caption(id: string): string {
    const state = this.state(id);
    const provider = state.catalog.groups.find((item: NativeModelProvider) => item.id === state.selected.provider);
    const model = provider?.models.find((item: NativeCatalogModel) => item.id === state.selected.model);
    const effort = state.selected.reasoningEffort || model?.reasoning?.defaultEffort || '';
    const name = model?.reasoning?.efforts.find((item: NativeModelEffort) => item.id === effort)?.name || effort;
    return (model?.name || state.selected.model || '模型') + (name ? ' · ' + name : '');
  }
  async load(id: string): Promise<NativeModelDirectoryState> {
    const active = this.pending.get(id);
    if (active) return active;
    const task = this.read(id).finally((): void => {
      if (this.pending.get(id) === task) this.pending.delete(id);
    });
    this.pending.set(id, task);
    return task;
  }
  /** A malformed response must never poison the caption path: keep the previous
   * catalog and reject the load instead of assigning an unvalidated shape. */
  private static selectionOf(value: Object | undefined | null): NativeModelSelection | null {
    if (value === undefined || value === null) return null;
    const record = value as Record<string, Object>;
    if (!record || typeof record['provider'] !== 'string' || typeof record['model'] !== 'string') return null;
    const selection = new NativeModelSelection();
    selection.provider = record['provider'] as string;
    selection.model = record['model'] as string;
    selection.reasoningEffort = typeof record['reasoningEffort'] === 'string' ? record['reasoningEffort'] as string : '';
    return selection;
  }
  private static catalogOf(value: Object): NativeModelCatalog | null {
    const record = value as Record<string, Object>;
    if (!record || !Array.isArray(record['groups']) || !Array.isArray(record['failures'])) return null;
    const fallback = NativeModelDirectory.selectionOf(record['default']);
    if (record['default'] !== undefined && !fallback) return null;
    const catalog = new NativeModelCatalog();
    catalog.default = fallback || new NativeModelSelection();
    for (const groupRaw of record['groups'] as Object[]) {
      const group = groupRaw as Record<string, Object>;
      if (!group || typeof group['id'] !== 'string' || !Array.isArray(group['models'])) return null;
      const provider = new NativeModelProvider();
      provider.id = group['id'] as string;
      provider.name = typeof group['name'] === 'string' ? group['name'] as string : '';
      for (const modelRaw of group['models'] as Object[]) {
        const model = modelRaw as Record<string, Object>;
        if (!model || typeof model['id'] !== 'string') return null;
        const entry = new NativeCatalogModel();
        entry.id = model['id'] as string;
        entry.name = typeof model['name'] === 'string' ? model['name'] as string : '';
        const reasoning = model['reasoning'];
        if (reasoning !== undefined && reasoning !== null) {
          const nested = reasoning as Record<string, Object>;
          if (!nested || !Array.isArray(nested['efforts'])) return null;
          const parsed = new NativeModelReasoning();
          for (const effortRaw of nested['efforts'] as Object[]) {
            const effort = effortRaw as Record<string, Object>;
            if (!effort || typeof effort['id'] !== 'string') return null;
            const item = new NativeModelEffort();
            item.id = effort['id'] as string;
            item.name = typeof effort['name'] === 'string' ? effort['name'] as string : '';
            item.description = typeof effort['description'] === 'string' ? effort['description'] as string : '';
            parsed.efforts.push(item);
          }
          parsed.defaultEffort = typeof nested['defaultEffort'] === 'string' ? nested['defaultEffort'] as string : '';
          entry.reasoning = parsed;
        }
        provider.models.push(entry);
      }
      catalog.groups.push(provider);
    }
    return catalog;
  }
  private async read(id: string): Promise<NativeModelDirectoryState> {
    const state = this.state(id); const version = ++state.generation;
    const results = await Promise.all([this.call(JSON.stringify({ operation: 'modelCatalog' })), this.call(JSON.stringify({ operation: 'projections', sessionId: id }))]);
    const catalog = NativeModelDirectory.catalogOf(JSON.parse(results[0]) as Object);
    if (!catalog) throw Error('模型目录不可用');
    const projection = JSON.parse(results[1]) as ProjectionReply;
    if (version === state.generation) {
      state.catalog = catalog;
      state.selected = NativeModelDirectory.selectionOf(projection?.values?.modelSelection?.next as Object) || catalog.default;
      this.changed();
    }
    return state;
  }
  async select(id: string, route: NativeModelSelection): Promise<void> {
    const state = this.state(id); const version = ++state.generation;
    const result = JSON.parse(await this.call(JSON.stringify({ operation: 'selectModel', sessionId: id, provider: route.provider,
      model: route.model, reasoningEffort: route.reasoningEffort || undefined }))) as SelectionReply;
    if (state.generation === version) { state.selected = result.selected; this.changed(); }
  }
  reset(): void { this.entries.forEach((state: NativeModelDirectoryState): void => { state.generation++; }); }
  clear(): void { this.entries.clear(); this.pending.clear(); }
}
