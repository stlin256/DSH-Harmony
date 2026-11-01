import { picker, fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { NativeHarnessClient, NativeHttpError, NativeAttachmentDraft } from '../services/NativeHarnessClient';
import { NativeFrame, NativeJournalEntry, NativeMessage, NativeSession, NativeSessionModel, NativePendingQuestion,
  NativeWorkspaceItem, NativeWorkspaceSnapshot, NativeWorkspaceRow, NativeImagePreviewRequest,
  NativeFileViewRequest, NativeQueueBlock, NativeQueueFile, NativeQueueItem, nativeWorkspaceRows,
  nativeToolsParent, nativeWorkspaceDragOrder, nativeBackToBottomAvailable,
  nativeBackToBottomHasNewContent, nativeProcessStructureChange,
  nativeAssistantProgressKey, nativeStreamHealthRepairReason } from '../services/NativeSessionModel';
import { NativeListSource } from '../services/NativeListSource';
import { NativeExperience } from '../services/NativeExperience';
import { NativeTextContent } from './NativeTextContent';
import { NativeInteraction } from './NativeInteraction';
import { NativeSessionTools } from './NativeSessionTools';
import { NativeModelPicker } from './NativeModelPicker';
import { NativeMessageView } from './NativeMessageView';
import { NativeBackgroundNoticeView } from './NativeBackgroundNoticeView';
import { DSHIcon } from './DSHIcon';
import { NativeProcessView } from './NativeProcessView';
import {
  nativeTranscript,
  nativePresentTranscript,
  nativeUpdateLiveAssistant,
  nativeWithLiveText
} from '../services/NativeTranscript';
import { NativeWorkspacePicker } from './NativeWorkspacePicker';
import { BackgroundMonitor } from '../services/BackgroundMonitor';
import { NativeActionMenu } from './NativeActionMenu';
import { NativeNavigationState, nativeSessionMenu, nativeCanGoBack, nativeForkTitle,
  nativeUtilityMenu } from '../services/NativeNavigation';
import { NativeMenuItem } from '../services/NativeNavigation';
import { NativeMetadataCache } from '../services/NativeMetadataCache';
import { NativeTranscriptCache } from '../services/NativeTranscriptCache';
import { NativeWorkspaceCache } from '../services/NativeWorkspaceCache';
import { NativeStorageManager } from '../services/NativeStorageManager';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { NativeImageLightbox } from './NativeImageLightbox';
import { NativeSubagentLineage } from './NativeSubagentLineage';
import {
  NativePlanProjection, NativeProjectionSequence, NativeSessionAddress, NativeSubagentEntry,
  NativeSubagentIdentity, NativeSubagentProjectionValues, NativeSubagentTiming,
  nativePlanTargetActive, nativeSessionAddress, nativeSubagentAddress,
  nativeSubagentComposerEnabled, nativeSubagentReadOnlyReason, nativeSubagentStackPush
} from '../services/NativeModeSubagent';
import { NativeFilePreview } from './NativeFilePreview';
import { NativeFileBrowser } from './NativeFileBrowser';
import { NativeHistoryRetryPolicy, nativeHistoryPageAdvanced } from '../services/NativeHistoryPrefetch';
import { NativePlanDocument, nativeLatestPlan, nativePlanSignature } from '../services/NativePlan';
import { nativeDshUiCanReply } from '../services/NativeDshUi';
import { NativeTaskDock } from './NativeTaskDock';
import { NativeConversationDock } from './NativeConversationDock';
import {
  nativeLiveTurnChange,
  nativeTurnChangeFor,
  nativeTurnChangeInputSignature,
  nativeTurnChangeReferences,
  nativeTurnChangeSummaryFromJson,
  nativeTurnChanges,
  NativeTurnChangeReference,
  NativeTurnChangeSummary
} from '../services/NativeTurnChanges';
import { nativeFileTarget } from '../services/NativeLinkResolver';
import {
  NativeTurnChangePill,
  NativeTurnChangesCard
} from './NativeTurnChangesView';
import { NativeBottomConversationDock } from './NativeBottomConversationDock';
import { NativeQueueDock } from './NativeQueueDock';
import { NativeIconButton } from './NativeIconButton';

class NativeExportCapabilities { copyMarkdown: boolean = false; downloadLog: boolean = false; }
class NativeWorkspaceOrderRequest {
  operation: string = 'workspaceOrder';
  workspaceId: string;
  beforeWorkspaceId?: string;
  constructor(workspaceId: string) {
    this.workspaceId = workspaceId;
  }
}
function cloneWorkspaceSnapshot(value: NativeWorkspaceSnapshot): NativeWorkspaceSnapshot {
  const clone = new NativeWorkspaceSnapshot();
  clone.available = value.available;
  clone.archivedSessionIds = value.archivedSessionIds.slice();
  clone.pinnedSessionIds = value.pinnedSessionIds.slice();
  clone.items = value.items.map((item: NativeWorkspaceItem): NativeWorkspaceItem => {
    const row = new NativeWorkspaceItem();
    row.workspaceId = item.workspaceId;
    row.path = item.path;
    row.title = item.title;
    row.sessionIds = item.sessionIds.slice();
    return row;
  });
  return clone;
}
class NativeWorkspaceOrderOperation {
  request: NativeWorkspaceOrderRequest;
  next: NativeWorkspaceSnapshot;
  generation: number;
  constructor(request: NativeWorkspaceOrderRequest, next: NativeWorkspaceSnapshot, generation: number) {
    this.request = request;
    this.next = next;
    this.generation = generation;
  }
}

@Component
export struct NativeWorkspace {
  client: NativeHarnessClient = new NativeHarnessClient('');
  context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  supportsPush: boolean = false;
  onLogin: () => void = (): void => {};
  onSettings: () => void = (): void => {};
  onSnapshot: (value: string) => Promise<void> = async (): Promise<void> => {};
  onLocalNotification: (sessionId: string, title: string, state: string) => Promise<void> = async (): Promise<void> => {};
  onCompatibility: () => void = (): void => {};
  onWorkspaceReady: () => void = (): void => {};
  @StorageLink('nativeBackRevision') @Watch('backToSessions') private backRevision: number = 0;
  @StorageLink('nativeImagePreviewRevision') @Watch('imagePreviewChanged') private imagePreviewRevision: number = 0;
  @StorageLink('nativeFileViewRevision') @Watch('fileViewChanged') private fileViewRevision: number = 0;
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeHostSettingsRevision') @Watch('preferencesChanged') private preferencesRevision: number = 0;
  @StorageLink('nativeModelRevision') @Watch('modelCaptionChanged') private modelRevision: number = 0;
  @StorageLink('nativeRefreshRevision') @Watch('reload') private refreshRevision: number = 0;
  @StorageLink('nativeAppActive') @Watch('activityChanged') private active: boolean = true;
  @StorageLink('nativeBackgroundMonitor') @Watch('activityChanged') private backgroundMonitor: boolean = false;
  @StorageLink('requestedSession') @Watch('openRequested') private requestedSession: string = '';
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @State @Watch('sessionsChanged') private sessions: NativeSession[] = [];
  @State private continued: NativeFrame[] = [];
  @State private interactions: NativeFrame[] = [];
  @State private attachments: NativeAttachmentDraft[] = [];
  @State private imagePreviewOpen: boolean = false;
  @State private imagePreview: NativeImagePreviewRequest = new NativeImagePreviewRequest();
  @State private fileViewOpen: boolean = false;
  @State private fileView: NativeFileViewRequest = new NativeFileViewRequest();
  @State private attaching: boolean = false;
  @State private composerHeight: number = 0;
  @State @Watch('navigationChanged') private toolsOpen: boolean = false;
  @State private toolsId: string = '';
  @State @Watch('navigationChanged') private modelPickerOpen: boolean = false;
  @State @Watch('navigationChanged') private menuId: string = '';
  @State private menuTarget: string = '';
  @State @Watch('navigationChanged') private utilityOpen: boolean = false;
  @State private copying: boolean = false;
  @State private modelCaption: string = '模型';
  @State private downloading: boolean = false;
  @State private utilityKnown: boolean = false;
  @State private exportCapabilities: NativeExportCapabilities = new NativeExportCapabilities();
  private utilityCapabilities: Map<string, NativeExportCapabilities> = new Map<string, NativeExportCapabilities>();
  private utilityRequests: Set<string> = new Set<string>();
  @State private menuBusy: boolean = false;
  @State private archivedUndo: string = '';
  @State private steer: boolean = false;
  @State @Watch('navigationChanged') private newSessionOpen: boolean = false;
  @State @Watch('navigationChanged') private workspacePickerOpen: boolean = false;
  @State private workspacePickerPage: string = 'root';
  @State private workspacePickerDirection: number = 1;
  @State @Watch('sessionsChanged') private workspaces: NativeWorkspaceSnapshot = new NativeWorkspaceSnapshot();
  @State @Watch('sessionsChanged') private workspaceId: string = '';
  @State @Watch('sessionsChanged') private query: string = '';
  @State private searchOpen: boolean = false;
  @State private newWorkspaceId: string = '';
  @State private newCwd: string = '';
  @State private newPreset: string = '';
  @State private selected: string = '';
  @State private title: string = '工作空间';
  @State private draft: string = '';
  @State @Watch('navigationChanged') private showSessions: boolean = false;
  @State @Watch('navigationChanged') private wide: boolean = false;
  @State private windowWidth: number = 0;
  @State private loading: boolean = true;
  @State private sending: boolean = false;
  @State private connectionPhase: string = 'idle';
  @State private running: boolean = false;
  @State private waiting: boolean = false;
  @State private queue: NativeQueueItem[] = [];
  @State private pendingQueue: NativeQueueItem[] = [];
  @State private processEntranceIds: string[] = [];
  @State private uncertain: boolean = false;
  private connectionNotified: boolean = false;
  @State private error: string = '';
  @State private paging: boolean = false;
  @State private hasMore: boolean = false;
  @State private visibleSessionCount: number = 0;
  @State private collapsedGroups: string[] = [];
  @State private workspaceLoading: boolean = false;
  @State private workspaceError: string = '';
  @State private dragWorkspaceId: string = '';
  @State private dropWorkspaceId: string = '';
  @State private dropWorkspaceAfter: boolean = false;
  @State private backToBottomVisible: boolean = false;
  @State private backToBottomNew: boolean = false;
  @State private backToBottomPressed: boolean = false;
  @State private drawerFollowing: boolean = false;
  @State private drawerTranslation: number = 0;
  @State private transcriptViewportHeight: number = 0;
  @State private conversationDockHeight: number = 0;
  @State private footerCopiedId: string = '';
  @State private taskPlan: NativePlanDocument = new NativePlanDocument();
  @State private planProjection: NativePlanProjection | null = null;
  @State private subagentCatalog: NativeSubagentEntry[] | null = null;
  @State private subagentIdentity: NativeSubagentIdentity | null = null;
  @State private subagentIdentityKnown: boolean = false;
  @State private subagentTiming: NativeSubagentTiming | null = null;
  @State private activeAddress: NativeSessionAddress = nativeSessionAddress('');
  @State private subagentPath: NativeSessionAddress[] = [];
  @State private lineageOpen: boolean = false;
  @State private lineageLoading: boolean = false;
  @State private lineageError: string = '';
  @State private planLeaving: boolean = false;
  @State private planError: string = '';
  @State private turnChanges: NativeTurnChangeSummary[] = [];
  @State private officialTurnChanges: NativeTurnChangeSummary[] = [];
  @State private liveTurnChanges: NativeTurnChangeSummary = new NativeTurnChangeSummary();
  @State private liveTurnChangesVisible: boolean = false;
  private officialTurnChangeSequences: Map<string, number> = new Map<string, number>();
  private officialTurnChangeRequests: Set<string> = new Set<string>();
  private officialTurnChangeQueue: NativeTurnChangeReference[] = [];
  private officialTurnChangeActive: number = 0;
  private officialTurnChangeGeneration: number = 0;
  private sessionSource: NativeListSource<NativeWorkspaceRow> = new NativeListSource<NativeWorkspaceRow>();
  private source: NativeListSource<NativeMessage> = new NativeListSource<NativeMessage>();
  private scroller: Scroller = new Scroller();
  private model: NativeSessionModel = new NativeSessionModel();
  private projectionValues: Map<string, NativeSubagentProjectionValues> =
    new Map<string, NativeSubagentProjectionValues>();
  private projectionSeq: NativeProjectionSequence = new NativeProjectionSequence();
  private transcriptBaseSource: NativeMessage[] | null = null;
  private transcriptBaseRows: NativeMessage[] = [];
  private transcriptBaseRoot: string = '';
  private textProjectionCacheHit: boolean = false;
  private lastRenderedStreamText: string = '';
  private streamTextPatchDirty: boolean = false;
  private taskPlanSignature: string = '';
  private turnChangesInputSignature: string = '';
  private followTail: boolean = true;
  private mounted: boolean = false;
  private generation: number = 0;
  private paintTimer: number = -1;
  private reconnectTimer: number = -1;
  private historyRetryTimer: number = -1;
  private followWatchdogTimer: number = -1;
  private settlementTimer: number = -1;

  private baseSurface(): string {
    return NativeDesign.base(this.dark);
  }

  private raisedSurface(): string {
    return NativeDesign.raised(this.dark);
  }

  private fieldSurface(): string {
    return NativeDesign.field(this.dark);
  }

  private selectionSurface(): string {
    return NativeDesign.selection(this.dark);
  }

  private semanticBorderColor(): string {
    return NativeDesign.border(this.dark);
  }

  private dividerColor(): string {
    return NativeDesign.divider(this.dark);
  }

  private primaryText(): string {
    return NativeDesign.textPrimary(this.dark);
  }

  private secondaryText(): string {
    return NativeDesign.textSecondary(this.dark);
  }

  private tertiaryText(): string {
    return NativeDesign.textTertiary(this.dark);
  }

  private accentColor(): string {
    return NativeDesign.accent(this.dark);
  }

  private dangerText(): string {
    return NativeDesign.danger(this.dark);
  }

  private warningText(): string {
    return NativeDesign.warning(this.dark);
  }
  private followActivityAt: number = 0;
  private assistantProgressAt: number = 0;
  private followProgressKey: string = '';
  private deliveryMismatchKey: string = '';
  private deliveryMismatchAt: number = 0;
  private followConnectionGeneration: string = '';
  private followOpened: boolean = false;
  private followStateKnown: boolean = false;
  private followRunning: boolean = false;
  private followWaiting: boolean = false;
  private followAttemptId: string = '';
  private reconnectInFlight: boolean = false;
  private retries: number = 0;
  private widgetTimer: number = -1;
  private widgetEventTimer: number = -1;
  private backgroundTimer: number = -1;
  private preloadTimer: number = -1;
  private backgroundActive: boolean = false;
  private backgroundBusy: boolean = false;
  private backgroundStates: Map<string, string> = new Map<string, string>();
  private visibleRows: NativeMessage[] = [];
  private firstVisible: number = 0;
  private userHasScrolled: boolean = false;
  private historyDraining: boolean = false;
  private historyPumpRunning: boolean = false;
  private historyRetry: NativeHistoryRetryPolicy = new NativeHistoryRetryPolicy();
  private selectionGeneration: number = 0;
  private cacheTimer: number = -1;
  private backToBottomTimer: number = -1;
  private returnToBottomTimer: number = -1;
  private scrollMotionSettleTimer: number = -1;
  private scrollTailTimer: number = -1;
  private tailScrollGuardUntil: number = 0;
  private scrollMotionActive: boolean = false;
  private processEntranceTimer: number = -1;
  private processTailTimer: number = -1;
  private suppressProcessEntrance: boolean = false;
  private processEntranceBaselinePending: boolean = false;
  private returningToBottom: boolean = false;
  private workspaceOrderGeneration: number = 0;
  private workspaceOrderBusy: boolean = false;
  private workspaceOrderQueue: NativeWorkspaceOrderOperation[] = [];
  private workspaceOrderConfirmed: NativeWorkspaceSnapshot | null = null;
  private drawerSettleTimer: number = -1;
  private destinationTimer: number = -1;
  private utilityOpenedAt: number = 0;
  private interactionTimes: Map<string, number> = new Map<string, number>();
  private workspaceRowRects: Map<string, number[]> = new Map<string, number[]>();
  private workspaceReadyNotified: boolean = false;
  private workspaceReadyPending: boolean = false;

  private notifyWorkspaceReady(generation: number): void {
    if (this.workspaceReadyNotified || this.workspaceReadyPending) return;
    this.workspaceReadyPending = true;
    this.loading = false;
    setTimeout((): void => {
      this.workspaceReadyPending = false;
      if (this.mounted && generation === this.generation && !this.workspaceReadyNotified) {
        this.workspaceReadyNotified = true;
        NativeStorageManager.enforceDefaultLimit(this.context, this.client.cacheKey(),
          this.selected, Array.from(this.client.drafts.keys()), true).catch((): void => {});
        this.onWorkspaceReady();
      }
    }, 0);
  }

  private preferencesChanged(): void { this.steer = this.client.hostSettings.chat().busyEnter === 'steer'; this.renderTranscript(true); }
  private modelCaptionChanged(): void { this.modelCaption = this.client.modelDirectory.caption(this.selected); }

  private navigationChanged(): void {
    const state = new NativeNavigationState();
    state.wide = this.wide; state.drawerOpen = this.showSessions;
    state.drawerPage = this.searchOpen ? 'search' : 'primary';
    state.picker = this.workspacePickerOpen;
    state.create = this.newSessionOpen; state.tools = this.toolsOpen;
    state.menu = !!this.menuId || this.utilityOpen || this.modelPickerOpen;
    state.imagePreview = this.imagePreviewOpen;
    state.filePreview = this.fileViewOpen;
    state.lineage = this.lineageOpen;
    state.subagentHistory = this.activeAddress.kind === 'subagent';
    AppStorage.setOrCreate<boolean>('nativeWorkspaceCanGoBack', nativeCanGoBack(state));
    AppStorage.setOrCreate<boolean>('nativeWorkspaceHasSelection', this.selected.length > 0);
  }
  private imagePreviewChanged(): void {
    const raw = AppStorage.get<string>('nativeImagePreviewPayload') || '';
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw) as NativeImagePreviewRequest;
      if (!parsed.sessionId || !parsed.attachment?.attachmentId) return;
      const request = new NativeImagePreviewRequest();
      request.sessionId = parsed.sessionId;
      request.attachment = parsed.attachment;
      this.imagePreview = request;
      this.imagePreviewOpen = true;
      this.navigationChanged();
    } catch (_) {}
  }
  private closeImagePreview(): void {
    this.imagePreviewOpen = false;
    AppStorage.setOrCreate<string>('nativeImagePreviewPayload', '');
    this.navigationChanged();
  }
  private fileViewChanged(): void {
    const raw = AppStorage.get<string>('nativeFileViewPayload') || '';
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw) as NativeFileViewRequest;
      if (!parsed.sessionId || typeof parsed.path !== 'string' ||
        (parsed.kind !== 'file' && parsed.kind !== 'browser') ||
        (parsed.kind === 'file' && !parsed.path)) return;
      const request = new NativeFileViewRequest();
      request.kind = parsed.kind;
      request.sessionId = parsed.sessionId;
      request.path = parsed.path;
      request.requestId = parsed.requestId;
      request.previewOnly = parsed.previewOnly === true;
      if (this.fileViewOpen && this.fileView.sessionId === request.sessionId) {
        AppStorage.setOrCreate<string>('nativeBrowserPushPayload', JSON.stringify(request));
        AppStorage.setOrCreate<number>('nativeBrowserPushRevision',
          (AppStorage.get<number>('nativeBrowserPushRevision') || 0) + 1);
        return;
      }
      if (parsed.kind === 'browser') {
        this.client.rememberBrowsePath(parsed.sessionId, parsed.path);
      } else {
        const clean = parsed.path.replace(/\\/g, '/');
        const slash = clean.lastIndexOf('/');
        this.client.rememberBrowsePath(parsed.sessionId, slash >= 0 ? clean.slice(0, slash) : '');
      }
      this.fileView = request;
      this.fileViewOpen = true;
      this.navigationChanged();
    } catch (_) {}
  }
  private closeFileView(): void {
    this.fileViewOpen = false;
    AppStorage.setOrCreate<string>('nativeFileViewPayload', '');
    this.navigationChanged();
  }
  private workspaceRootFor(sessionId: string): string {
    const session = this.sessions.find((item: NativeSession): boolean => item.id === sessionId);
    if (session?.cwd) return session.cwd;
    const workspace = this.workspaces.items.find((item: NativeWorkspaceItem): boolean =>
      item.sessionIds.includes(sessionId));
    return workspace?.path || '';
  }
  private browserDirectoryForFile(path: string): string {
    const clean = path.replace(/\\/g, '/').replace(/\/+$/, '');
    const slash = clean.lastIndexOf('/');
    return slash > 0 ? clean.slice(0, slash) : '';
  }

  private sessionsChanged(): void {
    const visible = nativeWorkspaceRows(this.sessions, this.workspaces, this.workspaceId, this.query, this.client.models,
      this.selected, this.collapsedGroups, this.interactionTimes);
    this.visibleSessionCount = visible.filter((row: NativeWorkspaceRow) => !row.group).length;
    this.sessionSource.set(visible, (row: NativeWorkspaceRow): string => row.key);
  }
  private applyLiveTitle(id: string, value: string): void {
    if (typeof value !== 'string') return;
    const title = value.replace(/[\u0000-\u001f\u007f]/g, ' ')
      .replace(/\s+/g, ' ').trim().slice(0, 160);
    if (!title || !this.sessions.some((item: NativeSession): boolean => item.id === id)) return;
    this.sessions = this.sessions.map((item: NativeSession): NativeSession => {
      if (item.id !== id || item.title === title) return item;
      const next = new NativeSession();
      next.titleKnown = true; next.origin = item.origin; next.parentSessionId = item.parentSessionId;
      next.agentPreset = item.agentPreset; next.id = item.id; next.title = title;
      next.blank = false; next.cwd = item.cwd; next.agentAvailable = item.agentAvailable;
      next.running = item.running;
      next.updatedAt = item.updatedAt; next.projections = item.projections;
      return next;
    });
    if (this.selected === id) this.title = title;
    this.sessionsChanged();
    NativeMetadataCache.save(this.context, this.client.cacheKey(), this.sessions, this.workspaces);
  }
  private projectionValueFor(id: string): NativeSubagentProjectionValues {
    const value = this.projectionValues.get(id);
    if (value) return value;
    if (this.projectionValues.size >= 24 && !this.projectionValues.has(id)) {
      const oldest = Array.from(this.projectionValues.keys())[0];
      if (oldest && oldest !== this.selected) this.projectionValues.delete(oldest);
    }
    const created = new NativeSubagentProjectionValues();
    this.projectionValues.set(id, created);
    return created;
  }
  private cloneSubagentCatalog(entries: NativeSubagentEntry[] | null): NativeSubagentEntry[] | null {
    if (entries === null) return null;
    return entries.map((entry: NativeSubagentEntry): NativeSubagentEntry => {
      const next = new NativeSubagentEntry();
      next.id = entry.id; next.createdAt = entry.createdAt; next.mode = entry.mode;
      next.label = entry.label || '';
      next.running = this.sessions.find((session: NativeSession): boolean =>
        session.id === entry.id)?.running === true;
      return next;
    });
  }
  private refreshSelectedProjection(): void {
    const value = this.projectionValueFor(this.selected);
    this.planProjection = value.plan;
    this.subagentCatalog = this.cloneSubagentCatalog(value.subagentCatalog);
    this.subagentIdentity = value.subagent;
    this.subagentIdentityKnown = value.subagentKnown;
    this.subagentTiming = value.subagentTiming;
  }
  private mergeSessionProjection(session: NativeSession): void {
    if (!session.projections) return;
    const source = session.projections;
    const target = this.projectionValueFor(session.id);
    if (source.plan) target.plan = source.plan;
    if (source.subagentCatalog) target.subagentCatalog = source.subagentCatalog;
    if (source.subagentKnown) {
      target.subagentKnown = true;
      target.subagent = source.subagent;
    }
    if (source.subagentTiming) target.subagentTiming = source.subagentTiming;
  }
  private applyModeProjectionFrame(id: string, frame: NativeFrame): void {
    const value = this.projectionValueFor(id);
    if (frame.type === 'plan' && frame.plan &&
      this.projectionSeq.accept(id + ':plan', frame.projectionSeq)) {
      value.plan = frame.plan;
    } else if (frame.type === 'subagent-catalog' && frame.catalog &&
      this.projectionSeq.accept(id + ':subagentCatalog', frame.projectionSeq)) {
      value.subagentCatalog = frame.catalog;
    } else if (frame.type === 'subagent-identity' &&
      this.projectionSeq.accept(id + ':subagent', frame.projectionSeq)) {
      value.subagentKnown = true;
      value.subagent = frame.identity;
    } else if (frame.type === 'subagent-timing' && frame.timing &&
      this.projectionSeq.accept(id + ':subagentTiming', frame.projectionSeq)) {
      value.subagentTiming = frame.timing;
    } else {
      return;
    }
    if (this.selected === id) this.refreshSelectedProjection();
  }
  private hydrateModeProjections(): void {
    this.sessions.forEach((session: NativeSession): void => { this.mergeSessionProjection(session); });
    if (this.selected) this.refreshSelectedProjection();
  }
  private currentSubagentReadOnlyReason(): string {
    return nativeSubagentReadOnlyReason(this.activeAddress, this.subagentIdentity,
      this.subagentIdentityKnown, this.currentParentAgentAvailable(), this.running);
  }
  private currentSubagentInputEnabled(): boolean {
    return nativeSubagentComposerEnabled(this.activeAddress, this.subagentIdentity,
      this.subagentIdentityKnown, this.currentParentAgentAvailable(), this.running);
  }
  private currentParentAgentAvailable(): boolean | undefined {
    if (this.activeAddress.kind !== 'subagent') return true;
    return this.sessions.find((session: NativeSession): boolean =>
      session.id === this.activeAddress.parentSessionId)?.agentAvailable;
  }
  private currentParentTitle(): string {
    if (this.activeAddress.kind !== 'subagent') return '';
    return this.sessions.find((session: NativeSession): boolean =>
      session.id === this.activeAddress.parentSessionId)?.title || '父会话';
  }
  private currentSubagentTitle(): string {
    if (this.activeAddress.kind !== 'subagent') return '';
    return this.subagentIdentity?.label || this.sessions.find((session: NativeSession): boolean =>
      session.id === this.activeAddress.childSessionId)?.title || '子智能体';
  }
  private runningSubagentCount(): number {
    return (this.subagentCatalog || []).filter((entry: NativeSubagentEntry): boolean =>
      entry.running).length;
  }
  private openLineage(): void {
    this.utilityOpen = false;
    this.modelPickerOpen = false;
    this.menuId = '';
    this.lineageLoading = this.subagentCatalog === null;
    this.lineageError = '';
    this.lineageOpen = true;
    this.navigationChanged();
    if (this.subagentCatalog === null && this.selected) this.loadSelectedProjections();
  }
  private async loadSelectedProjections(): Promise<void> {
    const id = this.selected;
    if (!id) return;
    try {
      const snapshot = await this.client.projections(id);
      if (!this.mounted || this.selected !== id) return;
      const value = this.projectionValueFor(id);
      if (snapshot.values?.plan) value.plan = snapshot.values.plan;
      if (snapshot.values?.subagentCatalog !== undefined) {
        value.subagentCatalog = snapshot.values.subagentCatalog;
      }
      if (snapshot.values?.subagentKnown === true) {
        value.subagentKnown = true;
        value.subagent = snapshot.values.subagent;
      }
      if (snapshot.values?.subagentTiming) value.subagentTiming = snapshot.values.subagentTiming;
      this.refreshSelectedProjection();
      this.lineageLoading = false;
      this.lineageError = '';
    } catch (_) {
      if (this.mounted && this.selected === id) {
        this.lineageLoading = false;
        this.lineageError = '无法加载子智能体';
      }
    }
  }
  private openSubagent(entry: NativeSubagentEntry): void {
    if (!this.selected || entry.mode === 'external') return;
    const parentId = this.activeAddress.kind === 'subagent' ?
      this.activeAddress.childSessionId : this.selected;
    const address = nativeSubagentAddress(parentId, entry.id, entry.mode);
    if (!address) return;
    const trail = nativeSubagentStackPush(this.subagentPath, address);
    this.lineageOpen = false;
    this.navigationChanged();
    this.select(entry.id, address, trail, entry.label || entry.id);
  }
  private backToParentSession(): void {
    if (!this.subagentPath.length) return;
    const current = this.activeAddress;
    const nextTrail = this.subagentPath.slice(0, -1);
    const parentAddress = nextTrail.length ? nextTrail[nextTrail.length - 1] :
      nativeSessionAddress(current.parentSessionId);
    const parentTitle = this.sessions.find((session: NativeSession): boolean =>
      session.id === current.parentSessionId)?.title || '父会话';
    this.select(current.parentSessionId, parentAddress, nextTrail, parentTitle);
  }
  private async exitPlanMode(): Promise<void> {
    if (!this.selected || this.planLeaving) return;
    this.planLeaving = true;
    this.planError = '';
    try {
      await this.client.planOff(this.selected);
    } catch (_) {
      if (this.mounted) {
        this.planError = '退出计划模式失败';
        setTimeout((): void => {
          if (this.mounted && this.planError === '退出计划模式失败') this.planError = '';
        }, 2200);
      }
    } finally {
      if (this.mounted) this.planLeaving = false;
    }
  }
  aboutToAppear(): void {
    this.mounted = true;
    this.reload();
    const showcaseScreen = AppStorage.get<string>('storeShowcaseScreen') || '';
    if (showcaseScreen === 'sidebar') {
      setTimeout((): void => {
        if (this.mounted) this.openDrawer(false);
      }, 700);
    } else if (showcaseScreen === 'browser') {
      setTimeout((): void => {
        if (!this.mounted) return;
        const request = new NativeFileViewRequest();
        request.kind = 'browser';
        request.sessionId = 'showcase-release';
        request.path = '';
        this.fileView = request;
        this.fileViewOpen = true;
        this.navigationChanged();
      }, 700);
    }
  }
  aboutToDisappear(): void {
    this.mounted = false; this.generation++; this.client.pause();
    clearTimeout(this.paintTimer); clearTimeout(this.reconnectTimer); clearTimeout(this.widgetTimer);
    this.stopHistoryDrain();
    clearTimeout(this.widgetEventTimer);
    clearTimeout(this.backgroundTimer); clearTimeout(this.preloadTimer);
    clearTimeout(this.cacheTimer); clearTimeout(this.backToBottomTimer);
    clearTimeout(this.returnToBottomTimer);
    clearTimeout(this.scrollMotionSettleTimer); clearTimeout(this.scrollTailTimer);
    clearTimeout(this.processEntranceTimer);
    clearTimeout(this.processTailTimer);
    clearTimeout(this.drawerSettleTimer);
    clearTimeout(this.destinationTimer);
    this.persistCache();
    this.stopBackground();
    AppStorage.setOrCreate<boolean>('nativeWorkspaceCanGoBack', false);
    AppStorage.setOrCreate<boolean>('nativeWorkspaceHasSelection', false);
  }
  private async reload(): Promise<void> {
    const generation = ++this.generation;
    await this.client.prepareCacheKey();
    this.interactionTimes = NativeMetadataCache.interactions(
      this.context, this.client.cacheKey());
    const cached = NativeMetadataCache.read(this.context, this.client.cacheKey());
    if (cached.sessions.length) {
      this.sessions = cached.sessions;
      this.hydrateModeProjections();
      if (cached.workspaces) this.workspaces = cached.workspaces;
      this.sessionsChanged();
      // Paint the remembered conversation from the encrypted cache before the
      // navigation refresh or live socket becomes available.
      const cachedRequested = this.requestedSession ||
        await NativeTranscriptCache.loadRoute(this.context, this.client.cacheKey()) ||
        NativeMetadataCache.readLastSession(this.context, this.client.cacheKey());
      if (cachedRequested && !this.selected) {
        const available = this.sessions.some((item: NativeSession): boolean =>
          item.id === cachedRequested && item.blank !== true && item.origin !== 'subagent' &&
          !this.workspaces.archivedSessionIds.includes(item.id));
        if (available) {
          this.requestedSession = '';
          this.select(cachedRequested);
        }
      }
      if (!this.selected) this.openDrawer(false);
      if (generation === this.generation) {
        this.loading = false;
        this.notifyWorkspaceReady(generation);
      }
    } else this.loading = true;
    this.error = '';
    try {
      const statePending = this.client.state();
      const sessionsPending = this.client.sessions();
      const workspacesPending = this.client.workspaces();
      sessionsPending.catch(() => {});
      workspacesPending.catch(() => {});
      const state = await statePending;
      if (!this.mounted || generation !== this.generation) return;
      if (!state.authenticated) { this.onLogin(); return; }
      const value = await sessionsPending;
      const nextWorkspaces = await workspacesPending;
      if (!this.mounted || generation !== this.generation) return;
      if (value.protocol !== 2) throw new Error('请升级 DSH Harmony 插件或网关');
      this.sessions = value.items;
      this.hydrateModeProjections();
      if (nextWorkspaces.available) {
        this.workspaces = nextWorkspaces;
        if (!this.workspaceOrderBusy) this.workspaceOrderConfirmed = cloneWorkspaceSnapshot(nextWorkspaces);
      }
      this.client.hostSettings.refresh().catch(() => {});
      NativeMetadataCache.save(this.context, this.client.cacheKey(), this.sessions,
        nextWorkspaces.available ? nextWorkspaces : this.workspaces);
      this.preloadMetadata();
      this.updateWidget();
      const requested = this.requestedSession || await NativeTranscriptCache.loadRoute(this.context, this.client.cacheKey()) ||
        NativeMetadataCache.readLastSession(this.context, this.client.cacheKey()) || this.client.selectedId;
      if (requested) {
        this.requestedSession = '';
        const available = value.items.some((item: NativeSession): boolean =>
          item.id === requested && item.blank !== true && item.origin !== 'subagent' &&
          !nextWorkspaces.archivedSessionIds.includes(item.id));
        if (!available) NativeMetadataCache.forgetSession(this.context, this.client.cacheKey());
        if (available && requested === this.selected) {
          const session = this.sessions.find((item: NativeSession) => item.id === requested);
          if (session) this.title = session.title.trim() || '未命名会话';
          if (this.connectionPhase !== 'opening' && this.connectionPhase !== 'syncing' &&
            this.connectionPhase !== 'live') this.follow();
          this.notifyWorkspaceReady(generation);
        } else if (available) {
          this.select(requested);
          this.notifyWorkspaceReady(generation);
        } else {
          this.openDrawer(false);
          this.notifyWorkspaceReady(generation);
        }
      } else {
        this.openDrawer(false);
        this.notifyWorkspaceReady(generation);
      }
    } catch (error) {
      if (!this.sessions.length) this.handleError(error as Error);
      if (!(error instanceof NativeHttpError && error.status === 401)) {
        if (!this.sessions.length) {
          this.connectionPhase = 'retrying';
          this.scheduleReconnect('');
          this.notifyWorkspaceReady(generation);
        } else {
          this.connectionPhase = this.selected ? 'syncing' : 'idle';
          if (!this.selected) this.openDrawer(false);
          if (!this.selected) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = setTimeout((): void => {
              if (this.mounted && this.active) this.reload();
            }, 5000);
          }
        }
      }
    }
    finally {
      if (this.mounted && generation === this.generation && this.selected) this.loading = false;
    }
  }
  private preloadMetadata(): void {
    clearTimeout(this.preloadTimer);
    const ids = this.sessions.filter((session: NativeSession): boolean => session.blank !== true)
      .slice(0, 3).map((session: NativeSession): string => session.id);
    const generation = this.generation;
    this.preloadTimer = setTimeout((): void => {
      const next = (index: number): void => {
        if (!this.mounted || index >= ids.length) return;
        const id = ids[index];
        this.client.modelDirectory.load(id).catch(() => {}).finally((): void => {
          if (!this.mounted || generation !== this.generation) return;
          if (this.client.models.has(id)) { next(index + 1); return; }
          NativeTranscriptCache.loadSession(this.context, this.client.cacheKey(), id)
            .then((cached): void => {
              if (!this.mounted || generation !== this.generation || !cached ||
                !cached.messages.length || this.client.models.has(id)) return;
              const model = new NativeSessionModel();
              model.restore(cached);
              this.client.models.set(id, model);
            }).catch((): void => {}).finally((): void => {
              if (this.mounted && generation === this.generation) next(index + 1);
            });
        });
      };
      next(0);
    }, 160);
  }
  private handleError(error: Error): void {
    if (!this.mounted) return;
    if (error instanceof NativeHttpError && error.status === 401) { this.onLogin(); return; }
    this.error = error.message || '连接失败，请刷新后重试';
  }
  private activityChanged(): void {
    this.reconnectInFlight = false;
    clearTimeout(this.reconnectTimer); clearTimeout(this.widgetTimer);
    clearTimeout(this.followWatchdogTimer); clearTimeout(this.settlementTimer);
    clearTimeout(this.widgetEventTimer);
    if (!this.active) {
      this.pauseHistoryDrain();
      this.persistCache();
      const keepBackgroundLive = !this.active && this.backgroundMonitor &&
        !this.supportsPush && this.selected.length > 0;
      if (keepBackgroundLive) {
        this.connectionPhase = 'syncing';
        this.follow(true);
        this.pollBackground(true);
      } else {
        this.interactions = []; this.client.pause(); this.connectionPhase = 'paused';
        this.stopBackground();
      }
      return;
    }
    this.stopBackground();
    this.updateWidget();
    if (this.selected) this.follow(); else this.reload();
  }
  private clearFollowTimers(): void {
    clearTimeout(this.followWatchdogTimer); this.followWatchdogTimer = -1;
    clearTimeout(this.settlementTimer); this.settlementTimer = -1;
  }
  private liveAllowed(id: string = ''): boolean {
    if (!this.mounted || (id && this.selected !== id)) return false;
    return this.active || (this.backgroundMonitor && !this.supportsPush && this.selected.length > 0);
  }
  private touchFollow(id: string): void {
    if (!this.liveAllowed(id)) return;
    this.followActivityAt = Date.now();
    if (this.followWatchdogTimer < 0) this.scheduleFollowHealth(id);
  }
  private scheduleFollowHealth(id: string): void {
    if (this.followWatchdogTimer >= 0 || !this.liveAllowed(id)) return;
    const delay = this.active ? 2500 : 5000;
    this.followWatchdogTimer = setTimeout((): void => {
      this.followWatchdogTimer = -1;
      if (!this.liveAllowed(id)) return;
      const backgrounded = !this.active;
      const reason = nativeStreamHealthRepairReason(Date.now(), this.followActivityAt,
        this.assistantProgressAt, this.deliveryMismatchAt, this.followOpened, backgrounded,
        this.followStateKnown, this.followRunning, this.followWaiting, this.followAttemptId);
      if (reason) {
        console.error('DSH Harmony stream repair: ' + reason);
        this.reconnect(id);
        return;
      }
      this.scheduleFollowHealth(id);
    }, delay);
  }
  private acceptHeartbeat(id: string, frame: NativeFrame): void {
    if (frame.generation) {
      if (!this.followConnectionGeneration) this.followConnectionGeneration = frame.generation;
      else if (this.followConnectionGeneration !== frame.generation) return;
    }
    this.touchFollow(id);
    if (frame.stateKnown) {
      this.followStateKnown = true;
      this.followRunning = frame.running === true;
      this.followWaiting = frame.waiting === true;
    }
    if (!this.followOpened || !frame.stateKnown) return;
    const now = Date.now();
    this.followAttemptId = frame.attemptId || '';
    const gatewayKey = nativeAssistantProgressKey(this.followAttemptId, frame.revision,
      frame.nextIndex, frame.cursor);
    const reducerKey = nativeAssistantProgressKey(this.model.activityAttemptId(),
      this.model.activityRevision(), this.model.activityNextIndex(), this.model.activityCursor());
    if (gatewayKey && gatewayKey !== this.followProgressKey) {
      this.followProgressKey = gatewayKey;
      this.assistantProgressAt = now;
    } else if (!gatewayKey) {
      this.assistantProgressAt = now;
    }
    if (this.followRunning && !this.followWaiting && gatewayKey !== reducerKey) {
      if (this.deliveryMismatchAt <= 0) this.deliveryMismatchAt = now;
      this.deliveryMismatchKey = gatewayKey;
    } else {
      this.deliveryMismatchKey = '';
      this.deliveryMismatchAt = 0;
    }
  }
  private trackAppliedProgress(id: string, frame: NativeFrame): void {
    this.touchFollow(id);
    if (frame.type === 'state') {
      this.followStateKnown = true;
      this.followRunning = frame.running === true;
      this.followWaiting = frame.waiting === true;
    }
    if (!this.followOpened) return;
    const now = Date.now();
    const attemptId = this.model.activityAttemptId();
    const reducerKey = nativeAssistantProgressKey(attemptId, this.model.activityRevision(),
      this.model.activityNextIndex(), this.model.activityCursor());
    if (attemptId) this.assistantProgressAt = now;
    if (!attemptId) {
      this.followAttemptId = '';
      this.assistantProgressAt = now;
    }
    if (reducerKey && (reducerKey === this.followProgressKey || this.deliveryMismatchAt > 0)) {
      this.deliveryMismatchKey = '';
      this.deliveryMismatchAt = 0;
    }
  }
  private armSettlementWatchdog(id: string): void {
    clearTimeout(this.settlementTimer);
    if (!this.model.settlementPending()) return;
    this.settlementTimer = setTimeout((): void => {
      if (this.liveAllowed(id) && this.model.settlementPending()) this.reconnect(id);
    }, 8000);
  }
  private animatePane(action: () => void): void {
    NativeMotion.animate(this.getUIContext(), 'surface', action);
  }
  private mobileDrawerWidth(): number {
    return Math.max(240, Math.min(380, this.windowWidth * 0.86, this.windowWidth - 48));
  }
  private setDrawerState(open: boolean): void {
    this.drawerFollowing = false;
    this.drawerTranslation = open ? 0 : -this.mobileDrawerWidth();
    this.showSessions = open;
  }
  private openDrawer(refresh: boolean = true): void {
    if (this.showSessions || this.drawerFollowing) {
      if (refresh) this.refreshSessionList().catch((): void => {});
      return;
    }
    clearTimeout(this.backToBottomTimer);
    clearTimeout(this.returnToBottomTimer);
    clearTimeout(this.drawerSettleTimer);
    const width = this.mobileDrawerWidth();
    this.drawerFollowing = true;
    this.showSessions = false;
    this.drawerTranslation = -width;
    this.backToBottomVisible = false;
    this.returningToBottom = false;
    NativeMotion.animate(this.getUIContext(), 'drawer', (): void => {
      this.drawerTranslation = 0;
    });
    this.drawerSettleTimer = setTimeout((): void => {
      if (!this.mounted) return;
      this.showSessions = true;
      this.drawerFollowing = false;
      this.navigationChanged();
    }, NativeMotion.enabled() ? NativeMotion.duration('drawer') : 0);
    if (refresh) this.refreshSessionList().catch((): void => {});
  }
  private closeDrawer(): void {
    clearTimeout(this.drawerSettleTimer);
    this.drawerFollowing = true;
    const width = this.mobileDrawerWidth();
    NativeMotion.animate(this.getUIContext(), 'drawer', (): void => {
      this.drawerTranslation = -width;
    });
    this.drawerSettleTimer = setTimeout((): void => {
      if (!this.mounted) return;
      this.showSessions = false;
      this.drawerFollowing = false;
      this.drawerTranslation = -width;
      this.navigationChanged();
    }, NativeMotion.enabled() ? NativeMotion.duration('drawer') : 0);
    this.restoreScrollTailAfterDrawer();
  }
  private openDrawerDestination(): void {
    clearTimeout(this.destinationTimer);
    this.closeDrawer();
    this.getUIContext().getPromptAction().showToast({
      message: '功能未开放',
      duration: 1600
    });
  }
  private toggleWorkspaceGroup(id: string): void {
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.collapsedGroups = this.collapsedGroups.includes(id) ?
        this.collapsedGroups.filter((value: string): boolean => value !== id) :
        this.collapsedGroups.concat([id]);
      this.sessionsChanged();
    });
  }
  private restoreScrollTailAfterDrawer(): void {
    setTimeout((): void => {
      if (this.mounted && !this.showSessions) this.updateScrollTail();
    }, NativeMotion.enabled() ? NativeMotion.duration('drawer') + 10 : 0);
  }
  private drawerProgress(width: number): number {
    return Math.max(0, Math.min(1, (this.drawerTranslation + width) / Math.max(1, width)));
  }
  private beginDrawerPan(): void {
    clearTimeout(this.drawerSettleTimer);
    clearTimeout(this.backToBottomTimer);
    this.backToBottomVisible = false;
    this.drawerFollowing = true;
    this.drawerTranslation = this.showSessions ? 0 : -this.mobileDrawerWidth();
  }
  private updateDrawerPan(event: GestureEvent): void {
    const width = this.mobileDrawerWidth();
    const start = this.showSessions ? 0 : -width;
    this.drawerFollowing = true;
    this.drawerTranslation = Math.max(-width, Math.min(0, start + event.offsetX));
  }
  private settleDrawerPan(event: GestureEvent): void {
    const width = this.mobileDrawerWidth();
    const progress = this.drawerProgress(width);
    clearTimeout(this.drawerSettleTimer);
    if (this.showSessions) {
      const dismiss = progress < 0.62 || event.offsetX < -48;
      NativeMotion.animate(this.getUIContext(), 'drawer', (): void => {
        this.drawerTranslation = dismiss ? -width : 0;
      });
      this.drawerSettleTimer = setTimeout((): void => {
        if (!this.mounted) return;
        if (dismiss) {
          this.showSessions = false;
          this.drawerTranslation = -width;
        }
        this.drawerFollowing = false;
        this.navigationChanged();
        if (dismiss) this.restoreScrollTailAfterDrawer();
      }, NativeMotion.enabled() ? NativeMotion.duration('drawer') : 0);
      return;
    }
    const open = progress > 0.38 || event.offsetX > 44;
    NativeMotion.animate(this.getUIContext(), 'drawer', (): void => {
      this.drawerTranslation = open ? 0 : -width;
    });
    this.drawerSettleTimer = setTimeout((): void => {
      if (!this.mounted) return;
      if (open) this.showSessions = true;
      else this.drawerTranslation = -width;
      this.drawerFollowing = false;
      this.navigationChanged();
      if (!open) this.restoreScrollTailAfterDrawer();
    }, NativeMotion.enabled() ? NativeMotion.duration('drawer') : 0);
  }
  private cancelDrawerPan(): void {
    const width = this.mobileDrawerWidth();
    clearTimeout(this.drawerSettleTimer);
    NativeMotion.animate(this.getUIContext(), 'surface', (): void => {
      this.drawerTranslation = this.showSessions ? 0 : -width;
    });
    this.drawerSettleTimer = setTimeout((): void => {
      if (!this.mounted) return;
      this.drawerFollowing = false;
      if (!this.showSessions) this.drawerTranslation = -width;
      if (!this.showSessions) this.restoreScrollTailAfterDrawer();
    }, NativeMotion.enabled() ? NativeMotion.duration('surface') : 0);
  }
  private backToSessions(): void {
    if (this.imagePreviewOpen) { this.closeImagePreview(); return; }
    if (this.fileViewOpen) return;
    if (this.lineageOpen) {
      this.lineageOpen = false;
      this.navigationChanged();
      return;
    }
    if (this.menuId || this.utilityOpen) { this.menuId = ''; this.utilityOpen = false; return; }
    if (this.modelPickerOpen) { this.modelPickerOpen = false; return; }
    if (this.workspacePickerOpen) {
      if (this.workspacePickerPage !== 'root') this.setWorkspacePickerPage('root');
      else this.closeWorkspacePicker();
      return;
    }
    if (this.newSessionOpen) { this.newSessionOpen = false; return; }
    if (this.toolsOpen) {
      const parent = nativeToolsParent(AppStorage.get<string>('nativeSessionToolsPage') || 'root');
      if (parent) AppStorage.setOrCreate<string>('nativeSessionToolsPage', parent);
      else this.toolsOpen = false;
      return;
    }
    if (this.subagentPath.length > 0 && this.activeAddress.kind === 'subagent') {
      this.backToParentSession();
      return;
    }
    if (this.showSessions) this.closeDrawer();
    this.sessionsChanged();
    this.navigationChanged();
  }
  private openWorkspacePicker(): void {
    this.workspacePickerPage = 'root';
    this.workspacePickerDirection = 1;
    NativeMotion.animate(this.getUIContext(), 'navigation', (): void => { this.workspacePickerOpen = true; });
  }
  private setWorkspacePickerPage(page: string): void {
    this.workspacePickerDirection = page === 'root' ? -1 : 1;
    NativeMotion.animate(this.getUIContext(), 'navigation', (): void => { this.workspacePickerPage = page; });
  }
  private closeWorkspacePicker(): void {
    NativeMotion.animate(this.getUIContext(), 'navigation', (): void => { this.workspacePickerOpen = false; });
  }
  private openTools(page: string, id: string = this.selected): void {
    this.toolsId = id; AppStorage.setOrCreate<string>('nativeSessionToolsPage', page); this.toolsOpen = true;
  }
  private async refreshSessionList(workspaceOrderGeneration: number = -1): Promise<void> {
    const expectedGeneration = workspaceOrderGeneration >= 0 ?
      workspaceOrderGeneration : this.workspaceOrderGeneration;
    const rows = await this.client.sessions();
    if (!this.mounted || expectedGeneration !== this.workspaceOrderGeneration) return;
    this.sessions = rows.items;
    this.hydrateModeProjections();
    const nextWorkspaces = await this.client.workspaces();
    if (!this.mounted || expectedGeneration !== this.workspaceOrderGeneration) return;
    if (nextWorkspaces.available) {
      this.workspaces = nextWorkspaces;
      if (!this.workspaceOrderBusy) this.workspaceOrderConfirmed = cloneWorkspaceSnapshot(nextWorkspaces);
      this.workspaceError = '';
    } else {
      this.workspaceError = '工作区加载失败';
    }
    NativeMetadataCache.save(this.context, this.client.cacheKey(), this.sessions,
      this.workspaces.available ? this.workspaces : null);
  }
  private async sessionAction(action: string): Promise<void> {
    const id = this.menuTarget; this.menuId = '';
    if (!id || this.menuBusy || this.workspaceOrderBusy) return;
    if (action === 'rename') { this.openTools('rename', id); return; }
    if (action === 'copyId') {
      pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, id))
        .then(() => { this.getUIContext().getPromptAction().showToast({ message: '已复制' }); }).catch(() => { this.error = '复制失败'; });
      return;
    }
    this.menuBusy = true;
    let pinRollback: NativeWorkspaceSnapshot | null = null;
    try {
      if (action === 'fork') {
        const reply = JSON.parse(await this.client.operation(JSON.stringify({ operation: 'fork', sessionId: id }))) as Record<string, Object>;
        const source = this.sessions.find((item: NativeSession) => item.id === id);
        try {
          if (source?.titleKnown && typeof reply.sessionId === 'string') await this.client.operation(JSON.stringify({ operation: 'rename', sessionId: reply.sessionId, title: nativeForkTitle(source.title) }));
        } catch (_) { this.error = '分支已创建，标题更新失败'; }
        await this.refreshSessionList(); return;
      }
      if (action === 'pin' || action === 'unpin') {
        const previous = cloneWorkspaceSnapshot(this.workspaces);
        pinRollback = previous;
        const next = cloneWorkspaceSnapshot(previous);
        const ids = new Set<string>(previous.pinnedSessionIds);
        if (action === 'pin') ids.add(id); else ids.delete(id);
        next.pinnedSessionIds = Array.from(ids);
        NativeMotion.animate(this.getUIContext(), 'micro', (): void => {
          this.workspaces = next; this.sessionsChanged();
        });
      }
      try { await this.client.operation(JSON.stringify({ operation: action, sessionId: id })); }
      catch (error) {
        if (action !== 'archive' || !(error instanceof NativeHttpError) || error.code !== 'workspace/session-active') throw error as Error;
        const choice = await this.getUIContext().getPromptAction().showDialog({ title: '停止活动并归档？',
          buttons: [{ text: '取消', color: NativeDesign.textTertiary(this.dark) },
            { text: '停止并归档', color: NativeDesign.danger(this.dark) }] });
        if (choice.index !== 1) return;
        await this.client.operation(JSON.stringify({ operation: 'archive', sessionId: id, stopActivity: true }));
      }
      if (action === 'pin' || action === 'unpin') {
        pinRollback = null;
        this.workspaceOrderConfirmed = null;
      }
      if (!this.mounted) return;
      if (action === 'archive') {
        this.archivedUndo = id;
        if (this.selected === id) {
          this.client.pause(); this.selected = ''; this.client.selectedId = ''; this.setDrawerState(true);
          NativeMetadataCache.forgetSession(this.context, this.client.cacheKey());
          NativeTranscriptCache.forgetSession(this.context, this.client.cacheKey(), id).catch(() => {});
          NativeWorkspaceCache.clearSession(this.context, this.client.cacheKey(), id).catch(() => {});
        }
      }
      await this.refreshSessionList();
    } catch (error) {
      if (pinRollback && this.mounted) {
        this.workspaces = pinRollback;
        this.sessionsChanged();
        this.getUIContext().getPromptAction().showToast({
          message: action === 'pin' ? '置顶未保存' : '取消置顶未保存', duration: 1500
        });
      }
      this.handleError(error as Error);
    }
    finally { this.menuBusy = false; }
  }
  private beginWorkspaceDrag(id: string): CustomBuilder | DragItemInfo {
    if (id && id !== 'other' && id !== 'pinned') this.dragWorkspaceId = id;
    return this.workspaceDragBuilder;
  }
  private cancelWorkspaceDrag(): void {
    this.dragWorkspaceId = '';
    this.dropWorkspaceId = '';
    this.dropWorkspaceAfter = false;
  }
  private async drainWorkspaceOrders(first: NativeWorkspaceOrderOperation): Promise<void> {
    if (this.workspaceOrderBusy) return;
    this.workspaceOrderBusy = true;
    let operation: NativeWorkspaceOrderOperation | null = first;
    let lastSuccessfulGeneration = -1;
    try {
      while (operation && this.mounted) {
        try {
          await this.client.operation(JSON.stringify(operation.request));
          this.workspaceOrderConfirmed = cloneWorkspaceSnapshot(operation.next);
          lastSuccessfulGeneration = operation.generation;
        } catch (error) {
          this.workspaceOrderQueue = [];
          if (this.mounted) {
            if (this.workspaceOrderConfirmed) {
              this.workspaces = cloneWorkspaceSnapshot(this.workspaceOrderConfirmed);
              this.sessionsChanged();
            }
            this.getUIContext().getPromptAction().showToast({
              message: '工作区顺序未保存', duration: 1500
            });
            this.handleError(error as Error);
          }
          break;
        }
        const nextOperation = this.workspaceOrderQueue.shift();
        operation = nextOperation || null;
      }
    } finally {
      if (!this.mounted) this.workspaceOrderQueue = [];
      this.workspaceOrderBusy = false;
    }
    if (this.mounted && lastSuccessfulGeneration >= 0) {
      try {
        await this.refreshSessionList(lastSuccessfulGeneration);
      } catch (_) {
        if (this.mounted) this.workspaceError = '工作区顺序已保存，刷新失败';
      }
    }
  }
  private dropWorkspace(target: string, event: DragEvent): void {
    const sourceId = this.dragWorkspaceId;
    this.cancelWorkspaceDrag();
    if (!sourceId || !target || sourceId === target || target === 'other' || target === 'pinned' ||
      this.menuBusy || this.query.trim()) {
      event.setResult(DragResult.DROP_DISABLED);
      return;
    }
    event.setResult(DragResult.DROP_ENABLED);
    const rect = this.workspaceRowRects.get(target) || [];
    const after = rect.length >= 2 && event.getWindowY() > rect[0] + rect[1] / 2;
    const order = this.workspaces.items.map((item: NativeWorkspaceItem): string => item.workspaceId);
    const nextOrder = nativeWorkspaceDragOrder(order, sourceId, target, after);
    if (!nextOrder) return;
    const byId: Map<string, NativeWorkspaceItem> = new Map<string, NativeWorkspaceItem>();
    this.workspaces.items.forEach((item: NativeWorkspaceItem): void => { byId.set(item.workspaceId, item); });
    const previous = this.workspaces;
    const next = cloneWorkspaceSnapshot(previous);
    next.items = nextOrder.map((id: string): NativeWorkspaceItem => {
      const source = byId.get(id) as NativeWorkspaceItem;
      const row = new NativeWorkspaceItem();
      row.workspaceId = source.workspaceId; row.path = source.path; row.title = source.title;
      row.sessionIds = source.sessionIds.slice();
      return row;
    });
    const generation = ++this.workspaceOrderGeneration;
    NativeMotion.spring(this.getUIContext(), (): void => {
      this.workspaces = next; this.sessionsChanged();
    });
    const sourceIndex = nextOrder.indexOf(sourceId);
    const beforeWorkspaceId = sourceIndex >= 0 ? nextOrder[sourceIndex + 1] || '' : '';
    const request = new NativeWorkspaceOrderRequest(sourceId);
    if (beforeWorkspaceId) request.beforeWorkspaceId = beforeWorkspaceId;
    const operation = new NativeWorkspaceOrderOperation(request, next, generation);
    if (this.workspaceOrderBusy) {
      this.workspaceOrderQueue.push(operation);
      return;
    }
    this.workspaceOrderConfirmed = cloneWorkspaceSnapshot(previous);
    this.drainWorkspaceOrders(operation);
  }
  @Builder
  private workspaceDragBuilder() {
    Row({ space: 7 }) {
      DSHIcon({ glyph: 'drag-handle-outline', glyphSize: 14,
        color: this.primaryText() })
      Text(this.workspaces.items.find((item: NativeWorkspaceItem): boolean =>
        item.workspaceId === this.dragWorkspaceId)?.title || '工作区')
        .fontSize(13).maxLines(1).fontColor(this.primaryText())
    }.padding({ left: 12, right: 12, top: 9, bottom: 9 }).borderRadius(10)
      .backgroundColor(this.selectionSurface())
      .border({ width: 0.5, color: this.semanticBorderColor() })
  }
  private async copyMarkdown(): Promise<void> {
    this.utilityOpen = false; if (this.copying) return;
    const id = this.selected; this.copying = true;
    try {
      const parts: Uint8Array[] = []; let size = 0;
      await this.client.exportSession(id, 'markdown', (part: ArrayBuffer): void => { const bytes = new Uint8Array(part); parts.push(bytes); size += bytes.length; });
      const all = new Uint8Array(size); let offset = 0;
      parts.forEach((part: Uint8Array): void => { all.set(part, offset); offset += part.length; });
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, util.TextDecoder.create('utf-8').decodeToString(all)));
      if (this.mounted) this.getUIContext().getPromptAction().showToast({ message: '已复制 Markdown' });
    } catch (_) { if (this.mounted) this.error = '复制失败'; }
    finally { this.copying = false; }
  }
  private async downloadLog(): Promise<void> {
    this.utilityOpen = false; if (this.downloading) return;
    const id = this.selected; this.downloading = true;
    const path = this.context.cacheDir + '/export-' + util.generateRandomUUID() + '.zip';
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      const output = file;
      await this.client.exportSession(id, 'zip', (part: ArrayBuffer): void => { fileIo.writeSync(output.fd, part); });
      fileIo.closeSync(file); file = null;
      if (!this.mounted) return;
      const options = new picker.DocumentSaveOptions(); options.newFileNames = ['dsh-session-' + id + '.zip'];
      const chosen = await new picker.DocumentViewPicker(this.context).save(options);
      if (!chosen.length) return;
      const destination = fileIo.openSync(chosen[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try { fileIo.copyFileSync(path, destination.fd); } finally { fileIo.closeSync(destination); }
      this.getUIContext().getPromptAction().showToast({ message: '日志已保存' });
    } catch (_) { if (this.mounted) this.error = '下载失败'; }
    finally { if (file) fileIo.closeSync(file); try { fileIo.unlinkSync(path); } catch (_) {} this.downloading = false; }
  }
  @Builder
  private sessionMenu() {
    NativeActionMenu({ items: nativeSessionMenu(this.workspaces.pinnedSessionIds.includes(this.menuTarget)), onSelect: (id: string): void => { this.sessionAction(id); } })
  }
  @Builder
  private utilityMenu() {
    NativeActionMenu({ items: this.utilityItems(),
      onSelect: (id: string): void => { this.utilityAction(id); } })
  }
  @Builder
  private utilityOverlay() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(Color.Transparent)
        .onClick((): void => {
          if (Date.now() - this.utilityOpenedAt > 250) this.utilityOpen = false;
        })
      Column() { this.utilityMenu() }
        .width(208).margin({ top: this.safeTop + 40, right: 12 })
        .borderRadius(16)
        .backgroundColor(this.raisedSurface())
        .clip(true)
        .shadow({ radius: 16, color: this.dark ? '#99000000' : '#2E000000', offsetY: 5 })
        .transition(NativeMotion.rowTransition())
    }.width('100%').height('100%')
  }
  @Builder
  private modelPicker() {
    NativeModelPicker({ client: this.client, sessionId: this.selected, currentCaption: this.modelCaption,
      onClose: (): void => { this.modelPickerOpen = false; } })
  }
  private utilityItems(): NativeMenuItem[] {
    return nativeUtilityMenu(this.utilityKnown, this.exportCapabilities.copyMarkdown,
      this.exportCapabilities.downloadLog, this.copying, this.downloading);
  }
  private utilityAction(id: string): void {
    if (id === 'files') {
      if (!this.selected) return;
      this.utilityOpen = false;
      const request = new NativeFileViewRequest();
      request.kind = 'browser';
      request.sessionId = this.selected;
      request.path = this.client.lastBrowsePath(this.selected);
      this.fileView = request;
      this.fileViewOpen = true;
      this.navigationChanged();
      return;
    }
    if (id === 'copy') this.copyMarkdown();
    else if (id === 'download') this.downloadLog();
  }
  private openUtilities(): void {
    this.modelPickerOpen = false;
    const next = !this.utilityOpen;
    if (next) this.utilityOpenedAt = Date.now();
    // Conditional presentation layers must commit on the first frame. Their
    // NativeMotion transitions animate the inserted menu without delaying state.
    this.utilityOpen = next;
    if (!next) return;
    // The action list is complete on the first frame. Capabilities only refine
    // availability and never gate whether the menu can appear immediately.
    this.prefetchUtilities(this.selected);
  }
  private async prefetchUtilities(id: string): Promise<void> {
    if (!id || this.utilityCapabilities.has(id) || this.utilityRequests.has(id)) return;
    this.utilityRequests.add(id);
    try {
      const value = JSON.parse(await this.client.operation(JSON.stringify({ operation: 'capabilities', sessionId: id }))) as NativeExportCapabilities;
      this.utilityCapabilities.set(id, value);
      if (this.mounted && this.selected === id) {
        this.exportCapabilities = value;
        this.utilityKnown = true;
      }
    } catch (_) {
      const unsupported = new NativeExportCapabilities();
      this.utilityCapabilities.set(id, unsupported);
      if (this.mounted && this.selected === id) {
        this.exportCapabilities = unsupported;
        this.utilityKnown = true;
      }
    } finally {
      this.utilityRequests.delete(id);
    }
  }
  private async refreshWorkspaces(): Promise<void> {
    if (this.workspaceLoading) return;
    this.workspaceLoading = true; this.workspaceError = '';
    try {
      const value = await this.client.workspaces();
      if (!value.available) throw new Error('Workspace unavailable');
      if (this.mounted) {
        this.workspaces = value;
        if (!this.workspaceOrderBusy) this.workspaceOrderConfirmed = cloneWorkspaceSnapshot(value);
      }
    } catch (error) {
      if (this.mounted) {
        this.workspaceError = '工作区加载失败';
        if (error instanceof NativeHttpError && error.status === 401) this.onLogin();
      }
    } finally { if (this.mounted) this.workspaceLoading = false; }
  }
  private openNewSession(): void {
    if (this.workspaceId && this.workspaceId !== 'other') {
      this.createQuickSession(this.workspaceId);
      return;
    }
    if (this.workspaces.items.length === 1) {
      this.createQuickSession(this.workspaces.items[0].workspaceId);
      return;
    }
    this.openWorkspacePicker();
  }
  private async createQuickSession(workspaceId: string): Promise<void> {
    if (this.loading || !workspaceId) return;
    this.loading = true; this.error = '';
    try {
      const workspace = this.workspaces.items.find((item: NativeWorkspaceItem) =>
        item.workspaceId === workspaceId);
      const reusable = workspace ? this.sessions.find((item: NativeSession) =>
        item.blank === true && workspace.sessionIds.includes(item.id) &&
        !this.workspaces.archivedSessionIds.includes(item.id)) : undefined;
      const id = await this.client.create('', '', workspaceId, reusable?.id || '');
      if (!this.mounted) return;
      const value = await this.client.sessions();
      if (!this.mounted) return;
      this.sessions = value.items;
      const refreshed = await this.client.workspaces();
      if (this.mounted && refreshed.available) this.workspaces = refreshed;
      this.workspaceId = workspaceId;
      this.select(id);
    } catch (error) { this.handleError(error as Error); }
    finally { if (this.mounted) this.loading = false; }
  }
  private async updateWidget(): Promise<void> {
    clearTimeout(this.widgetTimer);
    if (!this.mounted || !this.active) return;
    let delay = 60000;
    try {
      const value = await this.client.request('/pocket/api/overview');
      try {
        const overview = JSON.parse(value) as Record<string, Object>;
        const running = Number(overview.running || 0);
        const waiting = Number(overview.waiting || 0);
        if (running + waiting > 0) delay = 30000;
      } catch (_) {}
      if (this.mounted && this.active) {
        this.rememberBackgroundStates(value);
        await this.onSnapshot(value);
      }
    } catch (_) {}
    finally {
      if (this.mounted && this.active) {
        this.widgetTimer = setTimeout(() => { this.updateWidget(); }, delay);
      }
    }
  }
  private scheduleWidgetUpdate(): void {
    clearTimeout(this.widgetEventTimer);
    this.widgetEventTimer = setTimeout((): void => {
      this.widgetEventTimer = -1;
      this.updateWidget();
    }, 1200);
  }
  private rememberBackgroundStates(raw: string): void {
    try {
      const data = JSON.parse(raw) as Record<string, Object>;
      const tasks = data.tasks as Array<Record<string, Object>>;
      if (!Array.isArray(tasks)) return;
      for (const task of tasks) {
        if (typeof task.sessionId === 'string' && typeof task.state === 'string') {
          this.backgroundStates.set(task.sessionId, task.state);
        }
      }
    } catch (_) {}
  }
  private knownActiveSession(): string {
    let sessionId = '';
    this.backgroundStates.forEach((state: string, id: string) => {
      if (!sessionId && (state === 'running' || state === 'waiting')) sessionId = id;
    });
    return sessionId;
  }
  private async pollBackground(initial: boolean): Promise<void> {
    if (!this.mounted || this.active || !this.backgroundMonitor || this.supportsPush || this.backgroundBusy) return;
    this.backgroundBusy = true;
    try {
      if (initial && !this.backgroundActive) {
        const known = this.knownActiveSession() || this.selected;
        if (known) {
          try { await BackgroundMonitor.start(this.context, known); this.backgroundActive = true; } catch (_) {}
        }
      }
      const raw = await this.client.request('/pocket/api/overview');
      if (!this.mounted || this.active || !this.backgroundMonitor) return;
      const data = JSON.parse(raw) as Record<string, Object>;
      const tasks = data.tasks as Array<Record<string, Object>>;
      if (!Array.isArray(tasks)) return;
      for (const task of tasks) {
        if (typeof task.sessionId !== 'string' || typeof task.state !== 'string') continue;
        const id = task.sessionId;
        const state = task.state;
        const previous = this.backgroundStates.get(id) || '';
        if (previous && previous !== state && (state === 'waiting' || state === 'completed' || state === 'failed') &&
          (previous === 'running' || previous === 'waiting')) {
          const title = typeof task.title === 'string' ? task.title : '任务';
          await this.onLocalNotification(id, title, state);
        }
        this.backgroundStates.set(id, state);
      }
      const active = tasks.filter((task: Record<string, Object>) => task.state === 'running' || task.state === 'waiting');
      if (!active.length) { this.stopBackground(); return; }
      if (!this.backgroundActive) {
        const first = active[0].sessionId as string;
        await BackgroundMonitor.start(this.context, first);
        this.backgroundActive = true;
      }
      clearTimeout(this.backgroundTimer);
      this.backgroundTimer = setTimeout(() => { this.pollBackground(false); }, 30000);
    } catch (_) {
      if (this.backgroundActive && this.mounted && !this.active && this.backgroundMonitor) {
        clearTimeout(this.backgroundTimer);
        this.backgroundTimer = setTimeout(() => { this.pollBackground(false); }, 30000);
      }
    } finally { this.backgroundBusy = false; }
  }
  private stopBackground(): void {
    clearTimeout(this.backgroundTimer); this.backgroundTimer = -1;
    if (!this.backgroundActive) return;
    this.backgroundActive = false;
    BackgroundMonitor.stop(this.context).catch(() => {});
  }
  private openRequested(): void {
    if (!this.requestedSession) return;
    const id = this.requestedSession; this.requestedSession = '';
    this.openRequestedSession(id);
  }
  private async openRequestedSession(id: string): Promise<void> {
    const valid = (session: NativeSession): boolean =>
      session.id === id && session.blank !== true && session.origin !== 'subagent' &&
      !this.workspaces.archivedSessionIds.includes(id);
    if (!this.sessions.some(valid)) {
      try { await this.refreshSessionList(); } catch (_) {}
    }
    if (!this.mounted || !this.sessions.some(valid)) {
      if (this.mounted) {
        this.workspaceError = '会话不可用';
        this.openDrawer(false);
        this.navigationChanged();
      }
      return;
    }
    this.select(id);
  }
  private select(id: string, address: NativeSessionAddress | null = null,
    trail: NativeSessionAddress[] = [], displayTitle: string = ''): void {
    if (!id) return;
    const resolvedAddress = address || nativeSessionAddress(id);
    if (resolvedAddress.kind === 'session') {
      this.activeAddress = resolvedAddress;
      this.subagentPath = [];
    } else {
      this.activeAddress = resolvedAddress;
      this.subagentPath = trail.length ? trail.slice() : [resolvedAddress];
    }
    this.stopHistoryDrain();
    const selection = ++this.selectionGeneration;
    this.paging = false;
    if (this.selected) {
      const previousId = this.selected;
      this.client.models.set(previousId, this.model);
      NativeTranscriptCache.saveSession(this.context, this.client.cacheKey(), previousId, this.model)
        .then((): void => { this.enforceCacheLimit(previousId); })
        .catch((): void => {});
    }
    this.client.drafts.set(this.selected, this.draft);
    this.continued = []; this.interactions = []; this.queue = []; this.pendingQueue = [];
    this.processEntranceIds = []; this.toolsOpen = false; this.modelPickerOpen = false; this.client.selectedId = id;
    this.suppressProcessEntrance = true;
    this.processEntranceBaselinePending = false;
    const session = this.sessions.find((item: NativeSession) => item.id === id);
    if (session) this.mergeSessionProjection(session);
    this.title = displayTitle || (session ? session.title.trim() || '未命名会话' : '会话');
    this.draft = this.client.drafts.get(id) || '';
    this.attachments = this.client.attachments.get(id) || [];
    this.uncertain = this.client.uncertain.has(id);
    this.connectionNotified = false;
    this.animatePane(() => { this.selected = id; this.setDrawerState(false); });
    this.refreshSelectedProjection();
    this.followTail = true;
    this.interactionTimes = NativeMetadataCache.rememberInteraction(
      this.context, this.client.cacheKey(), id);
    this.sessionsChanged();
    if (resolvedAddress.kind === 'session') {
      NativeMetadataCache.rememberSession(this.context, this.client.cacheKey(), id);
      NativeTranscriptCache.saveRoute(this.context, this.client.cacheKey(), id).catch(() => {});
    }
    this.navigationChanged();
    this.model = this.client.models.get(id) || new NativeSessionModel();
    this.client.models.set(id, this.model);
    this.queue = (this.model.queue || []).slice();
    const capabilities = this.utilityCapabilities.get(id);
    this.utilityKnown = capabilities !== undefined;
    this.exportCapabilities = capabilities || new NativeExportCapabilities();
    this.prefetchUtilities(id);
    this.turnChanges = [];
    this.turnChangesInputSignature = '';
    this.officialTurnChanges = [];
    this.officialTurnChangeSequences.clear();
    this.officialTurnChangeRequests.clear();
    this.officialTurnChangeQueue = [];
    this.officialTurnChangeActive = 0;
    this.officialTurnChangeGeneration++;
    this.rememberTurnChangeReferences(Array.from(this.model.journal.values()));
    this.liveTurnChanges = new NativeTurnChangeSummary();
    this.liveTurnChangesVisible = false;
    this.visibleRows = [];
    this.source.set([], (row: NativeMessage): string => row.id);
    this.renderTranscript();
    this.running = false; this.waiting = false; this.retries = 0;
    this.connectionPhase = 'syncing'; this.userHasScrolled = false;
    clearTimeout(this.backToBottomTimer);
    clearTimeout(this.returnToBottomTimer);
    this.backToBottomVisible = false; this.backToBottomNew = false;
    this.returningToBottom = false;
    if (this.model.messages.length) {
      this.paint();
      this.follow();
    } else {
      this.restoreAndFollow(id, selection);
    }
    this.client.modelDirectory.load(id).catch(() => {});
  }
  private async restoreAndFollow(id: string, selection: number): Promise<void> {
    try {
      const cached = await NativeTranscriptCache.loadSession(this.context, this.client.cacheKey(), id);
      if (!this.mounted || selection !== this.selectionGeneration || this.selected !== id) return;
      if (cached !== null && cached.messages.length) {
        this.model.restore(cached);
        this.queue = (this.model.queue || []).slice();
        this.rememberTurnChangeReferences(Array.from(this.model.journal.values()));
        this.followTail = true;
        this.paint();
      }
    } catch (_) {}
    if (this.mounted && selection === this.selectionGeneration && this.selected === id) {
      this.follow();
    }
  }
  private follow(background: boolean = false): void {
    if (!this.liveAllowed() || !this.selected) return;
    this.reconnectInFlight = false;
    clearTimeout(this.reconnectTimer);
    clearTimeout(this.followWatchdogTimer); this.followWatchdogTimer = -1;
    clearTimeout(this.settlementTimer); this.settlementTimer = -1;
    const id = this.selected;
    const address = this.activeAddress;
    this.projectionSeq.clear();
    this.followActivityAt = Date.now();
    this.assistantProgressAt = 0;
    this.followProgressKey = '';
    this.deliveryMismatchKey = '';
    this.deliveryMismatchAt = 0;
    this.followConnectionGeneration = '';
    this.followOpened = false;
    this.followStateKnown = false;
    this.followRunning = false;
    this.followWaiting = false;
    this.followAttemptId = '';
    this.scheduleFollowHealth(id);
    this.connectionPhase = 'syncing';
    this.client.follow(id, (frame: NativeFrame): void => {
      if (!this.mounted || this.selected !== id) return;
      if (frame.type === 'heartbeat') {
        this.acceptHeartbeat(id, frame);
        return;
      }
      this.touchFollow(id);
      if (frame.type === 'questions') {
        this.continued = frame.questions.map((question: NativePendingQuestion) => {
          const value = new NativeFrame(); value.eventId = 'continued-' + question.callId;
          value.callId = question.callId; value.connectionId = id;
          value.interaction = 'user-questions/request'; value.request.questions = question.questions;
          return value;
        }); return;
      }
      if (frame.type === 'interaction') {
        this.interactions = this.interactions.filter((item: NativeFrame) => item.eventId !== frame.eventId).concat([frame]); return;
      }
      if (frame.type === 'interaction-ended') {
        this.interactions = this.interactions.filter((item: NativeFrame) => item.eventId !== frame.eventId); return;
      }
      if (frame.type === 'title') {
        this.applyLiveTitle(id, frame.title);
        return;
      }
      if (frame.type === 'plan' || frame.type === 'subagent-catalog' ||
        frame.type === 'subagent-identity' || frame.type === 'subagent-timing') {
        this.applyModeProjectionFrame(id, frame);
        return;
      }
      if (frame.type === 'error') {
        // Preserve the server's close/reconnect lifecycle instead of throwing
        // through the WebSocket parser and misreporting an invalid JSON frame.
        console.error('DSH Harmony live stream returned an error frame');
        this.notifyConnectionFailure(id);
        this.reconnect(id);
        return;
      }
      const wasActive = this.running || this.waiting;
      this.model.apply(frame);
      if (frame.type === 'snapshot') {
        this.followOpened = true;
        this.assistantProgressAt = Date.now();
        this.processEntranceBaselinePending = true;
      }
      if (['snapshot', 'event', 'start', 'delta', 'end', 'state'].includes(frame.type)) {
        this.trackAppliedProgress(id, frame);
      }
      if (frame.type === 'state' && frame.queueKnown === true) this.syncAuthoritativeQueue();
      if (frame.type === 'delta') {
        this.streamTextPatchDirty = frame.text.length > 0 &&
          !frame.reasoning && !(frame.toolUpdates || []).length;
      } else if (['snapshot', 'event', 'start', 'end', 'state'].includes(frame.type)) {
        this.streamTextPatchDirty = false;
      }
      if (frame.type === 'event') {
        this.rememberTurnChangeReferences((frame.journal || []).map((entry: NativeJournalEntry): string => entry.raw));
      } else if (frame.type === 'snapshot') {
        this.rememberTurnChangeReferences(Array.from(this.model.journal.values()));
      }
      if (frame.type === 'snapshot') {
        clearTimeout(this.settlementTimer); this.settlementTimer = -1;
      } else if (frame.type === 'end' && this.model.settlementPending()) {
        this.armSettlementWatchdog(id);
      } else if (frame.type === 'event' && !this.model.settlementPending()) {
        clearTimeout(this.settlementTimer); this.settlementTimer = -1;
      }
      if (nativeBackToBottomHasNewContent(this.followTail, frame.type)) {
        this.backToBottomNew = true;
      }
      if (frame.type === 'state' && wasActive !== (this.model.running || this.model.waiting)) {
        this.scheduleWidgetUpdate();
      }
      this.scheduleCache();
      if (frame.type === 'snapshot') {
        this.connectionPhase = 'live'; this.error = ''; this.retries = 0;
        this.connectionNotified = false;
        // Let the first snapshot paint, then keep draining history until the
        // Host says it is exhausted. Manual scrolling only prioritizes the
        // same pump; it is no longer required to restart a failed page.
        setTimeout((): void => { this.startHistoryDrain(true); }, 80);
      }
      if (this.paintTimer < 0) {
        this.paintTimer = setTimeout(() => {
          this.paintTimer = -1;
          this.paint();
        }, frame.type === 'delta' ? (this.scrollMotionActive ? 64 : 32) : 0);
      }
    }, (reason: string): void => {
      console.error('DSH Harmony live socket ended: ' + reason);
      this.reconnect(id);
    }, background, address).catch((): void => { this.scheduleReconnect(id); });
  }
  private async reconnect(id: string): Promise<void> {
    if (!this.liveAllowed(id) || this.reconnectInFlight) return;
    this.reconnectInFlight = true;
    this.notifyConnectionFailure(id);
    this.connectionPhase = 'syncing';
    try {
      const state = await this.client.state();
      if (!this.liveAllowed(id)) { this.reconnectInFlight = false; return; }
      if (!state.authenticated) { this.reconnectInFlight = false; this.onLogin(); return; }
    } catch (_) {}
    if (!this.liveAllowed(id)) { this.reconnectInFlight = false; return; }
    this.scheduleReconnect(id);
  }
  private scheduleReconnect(id: string): void {
    if (!this.liveAllowed(id) || (id && this.selected !== id)) { this.reconnectInFlight = false; return; }
    this.pauseHistoryDrain();
    clearTimeout(this.reconnectTimer);
    clearTimeout(this.followWatchdogTimer); clearTimeout(this.settlementTimer);
    this.interactions = [];
    this.notifyConnectionFailure(id);
    const exposeFailure = this.connectionPhase === 'live' || this.retries > 0;
    if (exposeFailure) this.connectionPhase = 'retrying';
    else this.connectionPhase = 'syncing';
    this.error = '';
    const attempt = this.retries;
    this.retries++;
    const delay = attempt === 0 ? 250 : Math.min(30000, 1000 * Math.pow(2, Math.min(attempt, 5)));
    this.reconnectTimer = setTimeout(() => { if (id) this.follow(); else this.reload(); }, delay);
  }
  private notifyConnectionFailure(id: string): void {
    if (!id || this.connectionPhase !== 'live' || this.connectionNotified) return;
    this.connectionNotified = true;
    const title = this.sessions.find((item: NativeSession): boolean => item.id === id)?.title ||
      this.title || 'DSH Harmony';
    this.onLocalNotification(id, title, 'connection').catch(() => {});
  }
  private queueItems(): NativeQueueItem[] {
    const admitted: Set<string> = new Set<string>();
    this.queue.forEach((item: NativeQueueItem): void => {
      if (item.rpcId) admitted.add(item.rpcId);
    });
    return this.queue.concat(this.pendingQueue.filter((item: NativeQueueItem): boolean =>
      !item.rpcId || !admitted.has(item.rpcId)));
  }
  private queueStructureKey(items: NativeQueueItem[]): string {
    return items.map((item: NativeQueueItem): string => item.id).join('|');
  }
  private syncAuthoritativeQueue(): void {
    const nextQueue = this.model.queue || [];
    const admitted: Set<string> = new Set<string>();
    nextQueue.forEach((item: NativeQueueItem): void => {
      if (item.rpcId) admitted.add(item.rpcId);
    });
    const nextPending = this.pendingQueue.filter((item: NativeQueueItem): boolean =>
      !item.rpcId || !admitted.has(item.rpcId));
    const changed = this.queueStructureKey(this.queue) !==
      this.queueStructureKey(nextQueue) ||
      this.queueStructureKey(this.pendingQueue) !==
      this.queueStructureKey(nextPending);
    const assign = (): void => {
      this.queue = nextQueue;
      this.pendingQueue = nextPending;
    };
    if (changed && this.mounted) {
      NativeMotion.disclosure(this.getUIContext(), assign);
    } else {
      assign();
    }
  }
  private queuedEcho(requestId: string, text: string, attachments: NativeAttachmentDraft[]): NativeQueueItem {
    const item = new NativeQueueItem();
    item.id = 'pending:' + requestId;
    item.rpcId = requestId;
    item.pending = true;
    attachments.forEach((attachment: NativeAttachmentDraft): void => {
      const block = new NativeQueueBlock();
      block.kind = 'file';
      const file = new NativeQueueFile();
      file.attachmentId = attachment.receiptId || attachment.id;
      file.name = attachment.name || '附件';
      file.bytes = attachment.bytes;
      block.file = file;
      item.blocks.push(block);
    });
    if (text.trim()) {
      const block = new NativeQueueBlock();
      block.kind = 'text';
      block.text = text;
      item.blocks.push(block);
    }
    return item;
  }
  private scheduleProcessTailSettle(): void {
    clearTimeout(this.processTailTimer);
    this.processTailTimer = setTimeout((): void => {
      this.processTailTimer = -1;
      if (!this.mounted || !this.followTail || this.returningToBottom ||
        this.scrollMotionActive) return;
      this.scheduleTailScroll(2800);
    }, NativeMotion.enabled() ? 160 : 0);
  }
  private scheduleTailScroll(velocity: number = 0): void {
    if (!this.mounted || !this.followTail || this.returningToBottom ||
      this.scrollMotionActive || this.scrollTailTimer >= 0) return;
    this.scrollTailTimer = setTimeout((): void => {
      this.scrollTailTimer = -1;
      if (!this.mounted || !this.followTail || this.returningToBottom ||
        this.scrollMotionActive) return;
      this.tailScrollGuardUntil = Date.now() + 180;
      try {
        if (velocity > 0 && NativeMotion.enabled()) {
          this.scroller.scrollEdge(Edge.Bottom, { velocity: velocity });
        } else {
          this.scroller.scrollEdge(Edge.Bottom);
        }
      } catch (_) {}
    }, 0);
  }
  private scheduleScrollMotionSettle(): void {
    clearTimeout(this.scrollMotionSettleTimer);
    this.scrollMotionSettleTimer = setTimeout((): void => {
      this.scrollMotionSettleTimer = -1;
      if (!this.mounted || !this.scrollMotionActive) return;
      this.scrollMotionActive = false;
      // Publish the newest buffered tokens once the list has stopped moving,
      // then decide from the settled viewport whether tail following resumes.
      this.paint();
      this.updateScrollTail();
    }, 96);
  }
  private markScrollActivity(force: boolean = false): void {
    if (!this.mounted || this.returningToBottom) return;
    if (!force && Date.now() < this.tailScrollGuardUntil) return;
    this.tailScrollGuardUntil = 0;
    this.scrollMotionActive = true;
    this.userHasScrolled = true;
    this.followTail = false;
    clearTimeout(this.scrollTailTimer);
    this.scrollTailTimer = -1;
    this.scheduleScrollMotionSettle();
  }
  private paint(): void {
    if (!this.mounted) return;
    this.running = this.model.running; this.waiting = this.model.waiting; this.hasMore = this.model.hasMore;
    this.syncAuthoritativeQueue();
    this.renderTranscript();
    this.scheduleTailScroll();
  }
  private projectedTurnChange(turnKey: string): NativeTurnChangeSummary | null {
    return nativeTurnChangeFor(this.turnChanges, turnKey);
  }
  private turnChangeOutcome(turnKey: string): string {
    const projected = this.projectedTurnChange(turnKey);
    if (projected) return projected.outcome;
    const footer = this.model.messages.find((row: NativeMessage): boolean =>
      row.role === 'turn' && row.turnKey === turnKey);
    return footer?.footerOutcome || footer?.outcome || '';
  }
  private rememberTurnChangeReferences(raws: string[]): void {
    const id = this.selected;
    if (!id || !raws.length) return;
    nativeTurnChangeReferences(raws).forEach((reference: NativeTurnChangeReference): void => {
      const current = this.officialTurnChangeSequences.get(reference.turnKey) || -1;
      if (current > reference.seq) return;
      this.officialTurnChangeSequences.set(reference.turnKey, reference.seq);
      const key = id + '\n' + reference.turnKey + '\n' + reference.seq;
      if (this.officialTurnChangeRequests.has(key)) return;
      if (current === reference.seq &&
          this.officialTurnChanges.some((summary: NativeTurnChangeSummary): boolean =>
            summary.turnKey === reference.turnKey)) return;
      this.officialTurnChangeRequests.add(key);
      this.officialTurnChangeQueue.push(reference);
    });
    this.pumpOfficialTurnChanges();
  }
  private pumpOfficialTurnChanges(): void {
    const id = this.selected;
    if (!id) return;
    while (this.officialTurnChangeActive < 3 && this.officialTurnChangeQueue.length) {
      const reference = this.officialTurnChangeQueue.shift() as NativeTurnChangeReference;
      if (this.officialTurnChangeSequences.get(reference.turnKey) !== reference.seq) continue;
      const key = id + '\n' + reference.turnKey + '\n' + reference.seq;
      const generation = this.officialTurnChangeGeneration;
      this.officialTurnChangeActive++;
      this.client.turnChangeSummary(id, reference.seq)
        .then((body: string): void => {
          if (!this.mounted || this.selected !== id ||
              generation !== this.officialTurnChangeGeneration ||
              this.officialTurnChangeSequences.get(reference.turnKey) !== reference.seq) return;
          const summary = nativeTurnChangeSummaryFromJson(body, reference.turnKey,
            this.turnChangeOutcome(reference.turnKey));
          if (!summary) {
            this.officialTurnChangeRequests.delete(key);
            return;
          }
          this.officialTurnChangeRequests.delete(key);
          this.officialTurnChanges = this.officialTurnChanges.filter((item: NativeTurnChangeSummary): boolean =>
            item.turnKey !== reference.turnKey).concat([summary]);
          this.paint();
        })
        .catch((): void => {
          if (this.mounted && this.selected === id &&
              generation === this.officialTurnChangeGeneration) {
            this.officialTurnChangeRequests.delete(key);
          }
        })
        .finally((): void => {
          if (generation === this.officialTurnChangeGeneration) {
            this.officialTurnChangeActive = Math.max(0, this.officialTurnChangeActive - 1);
            this.pumpOfficialTurnChanges();
          }
        });
    }
  }
  private projectTranscriptRows(): NativeMessage[] {
    const workspaceRoot = this.workspaceRootFor(this.selected);
    const hasLiveProcess = this.model.streamTools.length > 0 || !!this.model.streamReasoning.trim();
    if (hasLiveProcess) {
      this.textProjectionCacheHit = false;
      return nativeTranscript(this.model.messages, this.model.running,
        this.model.streamTools, this.model.streamReasoning, this.model.streamText,
        workspaceRoot);
    }
    if (this.transcriptBaseSource !== this.model.messages ||
        this.transcriptBaseRoot !== workspaceRoot) {
      this.textProjectionCacheHit = false;
      this.transcriptBaseSource = this.model.messages;
      this.transcriptBaseRoot = workspaceRoot;
      this.transcriptBaseRows = nativeTranscript(this.model.messages, this.model.running, [],
        '', '', workspaceRoot);
    } else {
      this.textProjectionCacheHit = true;
    }
    return nativeWithLiveText(this.transcriptBaseRows, this.model.streamText);
  }
  private renderTranscript(forceFull: boolean = false): void {
    const patched: NativeMessage[] | null = !forceFull && this.streamTextPatchDirty ?
      nativeUpdateLiveAssistant(this.visibleRows, this.model.streamText) : null;
    this.streamTextPatchDirty = false;
    let rows: NativeMessage[];
    let visible: NativeMessage[];
    if (patched) {
      rows = patched;
      visible = patched;
    } else {
      rows = this.projectTranscriptRows();
      visible = nativePresentTranscript(rows, this.client.hostSettings.chat(),
        this.model.turnDisclosure, this.model.collapseThrough,
        this.workspaceRootFor(this.selected));
    }
    const processStructure = nativeProcessStructureChange(this.visibleRows, visible);
    if (!this.suppressProcessEntrance && processStructure.changed()) {
      const appeared = processStructure.addedGroupIds.concat(processStructure.growingGroupIds);
      this.processEntranceIds = Array.from(new Set<string>(this.processEntranceIds.concat(appeared)));
      clearTimeout(this.processEntranceTimer);
      this.processEntranceTimer = setTimeout((): void => {
        this.processEntranceTimer = -1;
        if (this.mounted) this.processEntranceIds = [];
      }, NativeMotion.enabled() ? 620 : 0);
      if (this.followTail) this.scheduleProcessTailSettle();
    } else if (this.suppressProcessEntrance &&
      (visible.length > 0 || this.processEntranceBaselinePending)) {
      // Seed cache/history directly into the list. Entrance motion belongs only
      // to structure added after this first complete projection.
      this.suppressProcessEntrance = false;
      this.processEntranceBaselinePending = false;
    }
    const tailOnlyTextUpdate = patched !== null ||
      (this.textProjectionCacheHit &&
        this.lastRenderedStreamText !== this.model.streamText);
    this.lastRenderedStreamText = this.model.streamText;
    const changeSignature = nativeTurnChangeInputSignature(rows, this.model.streamTools);
    if (changeSignature !== this.turnChangesInputSignature) {
      this.turnChangesInputSignature = changeSignature;
      this.turnChanges = nativeTurnChanges(rows);
    }
    // Activity can change without a tool/footer signature change. Resolve
    // visibility on every projection so a completed/stopped turn hides the
    // live pill immediately and never leaks into the next state.
    const live = nativeLiveTurnChange(rows, this.model.running || this.model.waiting);
    if (live) {
      if (!this.liveTurnChangesVisible) {
        NativeMotion.disclosure(this.getUIContext(), (): void => {
          this.liveTurnChanges = live;
          this.liveTurnChangesVisible = true;
        });
      } else {
        this.liveTurnChanges = live;
      }
    } else if (this.liveTurnChangesVisible) {
      NativeMotion.disclosure(this.getUIContext(), (): void => {
        this.liveTurnChangesVisible = false;
      });
    }
    const plan = nativeLatestPlan(rows);
    const planSignature = nativePlanSignature(plan);
    if (planSignature !== this.taskPlanSignature || plan.parsed !== this.taskPlan.parsed) {
      this.taskPlanSignature = planSignature;
      if (!this.taskPlan.items.length && plan.items.length) {
        NativeMotion.disclosure(this.getUIContext(), (): void => { this.taskPlan = plan; });
      } else {
        this.taskPlan = plan;
      }
    }
    this.visibleRows = visible;
    if (tailOnlyTextUpdate) {
      this.source.setTail(visible, 2);
    } else {
      this.source.set(visible, (row: NativeMessage): string => row.id);
    }
  }
  private turnChangeFor(turnKey: string): NativeTurnChangeSummary {
    const official = this.officialTurnChanges.find((summary: NativeTurnChangeSummary): boolean =>
      summary.turnKey === turnKey);
    if (official) {
      const value = new NativeTurnChangeSummary();
      value.turnKey = official.turnKey;
      value.files = official.files;
      value.fileCount = official.fileCount;
      value.added = official.added;
      value.removed = official.removed;
      value.running = false;
      value.outcome = this.turnChangeOutcome(turnKey) || official.outcome;
      return value;
    }
    return this.projectedTurnChange(turnKey) || new NativeTurnChangeSummary();
  }
  private openTurnChangeFile(path: string): void {
    if (!this.selected || !path) return;
    const request = new NativeFileViewRequest();
    request.kind = 'file';
    request.sessionId = this.selected;
    request.path = nativeFileTarget(path, this.workspaceRootFor(this.selected));
    request.requestId = util.generateRandomUUID();
    request.previewOnly = true;
    const clean = request.path.replace(/\\/g, '/');
    const slash = clean.lastIndexOf('/');
    this.client.rememberBrowsePath(this.selected, slash >= 0 ? clean.slice(0, slash) : '');
    this.fileView = request;
    this.fileViewOpen = true;
    this.navigationChanged();
  }
  private copyFooter(text: string, id: string): void {
    if (!text) return;
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text))
      .then((): void => {
        this.footerCopiedId = id;
        setTimeout((): void => {
          if (this.footerCopiedId === id) this.footerCopiedId = '';
        }, 1000);
      }).catch((): void => {});
  }
  private async createSession(): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    try {
      const workspace = this.workspaces.items.find((item: NativeWorkspaceItem) => item.workspaceId === this.newWorkspaceId);
      const reusable = !this.newPreset && workspace ? this.sessions.find((item: NativeSession) => item.blank === true && workspace.sessionIds.includes(item.id) && !this.workspaces.archivedSessionIds.includes(item.id)) : undefined;
      const id = await this.client.create(this.newCwd, this.newPreset, this.newWorkspaceId, reusable?.id || '');
      this.workspaceId = this.newWorkspaceId;
      this.newSessionOpen = false;
      if (!this.mounted) return;
      const value = await this.client.sessions();
      this.sessions = value.items; this.refreshWorkspaces(); this.select(id);
    } catch (error) { this.handleError(error as Error); }
    finally { this.loading = false; }
  }
  private async send(): Promise<void> {
    if (this.sending || (!this.draft.trim() && !this.attachments.length) || !this.selected ||
        this.uncertain || !this.attachmentsReady() || !this.currentSubagentInputEnabled()) return;
    const id = this.selected; const text = this.draft; const attachmentSnapshot = this.attachments.slice();
    const mode = this.steer ? 'steer' : 'queue';
    const expectQueuedEcho = this.running && mode === 'queue';
    const requestId = util.generateRandomUUID();
    if (!this.running && this.client.hostSettings.chat().collapseTiming === 'next-input') { this.model.collapseThrough = this.model.lastSeq(); this.renderTranscript(); }
    this.sending = true; this.error = '';
    this.client.drafts.set(id, text);
    if (expectQueuedEcho && this.selected === id) {
      NativeMotion.disclosure(this.getUIContext(), (): void => {
        this.pendingQueue = this.pendingQueue.concat([
          this.queuedEcho(requestId, text, attachmentSnapshot)
        ]);
      });
    }
    try {
      const admittedRequestId = await this.client.prompt(
        id, text, mode, attachmentSnapshot, requestId,
        this.activeAddress.kind === 'subagent' ? this.activeAddress : null);
      if (admittedRequestId !== requestId) {
        this.pendingQueue = this.pendingQueue.filter((item: NativeQueueItem): boolean =>
          item.rpcId !== requestId);
      }
      this.interactionTimes = NativeMetadataCache.rememberInteraction(
        this.context, this.client.cacheKey(), id);
      this.sessionsChanged();
      this.client.drafts.set(id, ''); this.client.attachments.delete(id);
      if (this.selected === id) this.attachments = [];
      if (this.selected === id) this.draft = '';
    } catch (error) {
      const uncertain = this.client.uncertain.has(id);
      if (!uncertain) {
        this.pendingQueue = this.pendingQueue.filter((item: NativeQueueItem): boolean =>
          item.rpcId !== requestId);
      }
      if (this.selected === id) {
        this.uncertain = uncertain;
        this.handleError(error as Error);
      }
    }
    finally { this.sending = false; }
  }
  private async sendDshUiReply(text: string): Promise<boolean> {
    const id = this.selected;
    if (!id || !text.trim() || this.sending || this.running || this.waiting || this.uncertain ||
      !this.currentSubagentInputEnabled()) {
      return false;
    }
    const requestId = util.generateRandomUUID();
    this.sending = true;
    this.error = '';
    try {
      const admittedRequestId = await this.client.prompt(id, text, 'queue', [], requestId,
        this.activeAddress.kind === 'subagent' ? this.activeAddress : null);
      if (admittedRequestId !== requestId) return false;
      this.interactionTimes = NativeMetadataCache.rememberInteraction(
        this.context, this.client.cacheKey(), id);
      this.sessionsChanged();
      if (this.selected === id) this.followTail = true;
      return true;
    } catch (error) {
      if (this.selected === id) this.handleError(error as Error);
      return false;
    } finally {
      this.sending = false;
    }
  }
  private attachmentsReady(): boolean {
    return this.attachments.every((item: NativeAttachmentDraft): boolean => item.status === 'ready');
  }
  private publishAttachments(id: string, items: NativeAttachmentDraft[]): void {
    this.client.attachments.set(id, items);
    if (this.selected === id) {
      NativeMotion.disclosure(this.getUIContext(), (): void => {
        this.attachments = items;
      });
    }
  }
  private updateAttachment(id: string, attachmentId: string, status: string,
    receiptId: string = '', error: string = '', retryable: boolean = true): void {
    const items = this.client.attachments.get(id) || [];
    const updated = items.map((item: NativeAttachmentDraft): NativeAttachmentDraft => {
      if (item.id !== attachmentId) return item;
      const next = new NativeAttachmentDraft();
      next.id = item.id; next.kind = item.kind; next.name = item.name; next.mediaType = item.mediaType;
      next.uri = item.uri; next.bytes = item.bytes;
      // Retain bytes only while retry is possible. Ready drafts keep the local preview, not a second copy.
      next.data = status === 'ready' ? new Uint8Array(0) : item.data;
      next.status = status; next.receiptId = receiptId; next.error = error; next.retryable = retryable;
      return next;
    });
    this.publishAttachments(id, updated);
  }
  private fileName(uri: string): string {
    const raw = uri.slice(uri.lastIndexOf('/') + 1);
    try { return decodeURIComponent(raw); } catch (_) { return raw || '附件'; }
  }
  private imageMediaType(bytes: Uint8Array, name: string): string {
    if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) return 'image/png';
    if (bytes[0] === 0xFF && bytes[1] === 0xD8) return 'image/jpeg';
    if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return 'image/gif';
    if (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[8] === 0x57 &&
        bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return 'image/webp';
    const lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return '';
  }
  private async readAttachment(uri: string, kind: string): Promise<NativeAttachmentDraft> {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const chunks: Uint8Array[] = []; let size: number = 0;
    try {
      while (true) {
        const buffer = new ArrayBuffer(65536);
        const count = fileIo.readSync(file.fd, buffer);
        if (count === 0) break;
        chunks.push(new Uint8Array(buffer, 0, count)); size += count;
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 0); });
      }
    } finally { fileIo.closeSync(file); }
    const bytes = new Uint8Array(size); let offset: number = 0;
    chunks.forEach((part: Uint8Array): void => { bytes.set(part, offset); offset += part.byteLength; });
    const draft = new NativeAttachmentDraft();
    draft.id = util.generateRandomUUID(); draft.kind = kind; draft.name = this.fileName(uri);
    draft.uri = uri; draft.bytes = size; draft.data = bytes; draft.status = 'uploading';
    if (kind === 'image') {
      draft.mediaType = this.imageMediaType(bytes, draft.name);
      if (!draft.mediaType) throw new Error('不支持的图片格式');
    }
    return draft;
  }
  private async uploadAttachment(id: string, item: NativeAttachmentDraft): Promise<void> {
    try {
      const result = await this.client.uploadAttachment(id, item.name, item.data, item.mediaType);
      this.updateAttachment(id, item.id, 'ready', result.receiptId);
    } catch (error) {
      this.updateAttachment(id, item.id, 'error',
        '', error instanceof Error ? error.message : '附件上传失败', true);
    }
  }
  private async addAttachments(uris: string[], kind: string): Promise<void> {
    if (this.attaching || !this.selected) return;
    const id = this.selected; this.attaching = true; this.error = '';
    try {
      if (!uris.length || !this.mounted) return;
      const added: NativeAttachmentDraft[] = [];
      for (const uri of uris) {
        if (!this.mounted || this.selected !== id) return;
        added.push(await this.readAttachment(uri, kind));
      }
      const items = (this.client.attachments.get(id) || []).concat(added);
      this.publishAttachments(id, items);
      this.attaching = false;
      // Reading and uploading are independent. Each chip converges on its own so
      // one slow request cannot keep both picker actions blocked.
      added.forEach((item: NativeAttachmentDraft): void => { this.uploadAttachment(id, item); });
    } catch (error) { this.handleError(error as Error); }
    finally { this.attaching = false; }
  }
  private async attachImages(): Promise<void> {
    if (this.attaching || !this.selected) return;
    try {
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 8;
      const result = await new picker.PhotoViewPicker().select(options);
      await this.addAttachments(result.photoUris, 'image');
    } catch (error) {
      if ((error as Error)?.message !== 'User cancelled') this.handleError(error as Error);
    }
  }
  private async attachFiles(): Promise<void> {
    if (this.attaching || !this.selected) return;
    try {
      const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = 8;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      await this.addAttachments(uris, 'file');
    } catch (error) { this.handleError(error as Error); }
  }
  private removeAttachment(id: string): void {
    if (this.sending) return;
    this.publishAttachments(this.selected,
      (this.client.attachments.get(this.selected) || []).filter((item: NativeAttachmentDraft): boolean => item.id !== id));
  }
  private retryAttachment(item: NativeAttachmentDraft): void {
    if (!item.retryable || item.status !== 'error') return;
    this.updateAttachment(this.selected, item.id, 'uploading');
    this.uploadAttachment(this.selected, item);
  }
  private startHistoryDrain(resetRetry: boolean = false): void {
    if (!this.mounted || !this.selected || this.connectionPhase !== 'live' ||
      !this.model.hasMore || this.model.historyBefore < 0) {
      if (!this.model.hasMore || this.model.historyBefore < 0) this.stopHistoryDrain();
      return;
    }
    clearTimeout(this.historyRetryTimer);
    this.historyRetryTimer = -1;
    if (resetRetry) this.historyRetry.reset();
    this.historyDraining = true;
    this.pumpHistoryDrain();
  }
  private pauseHistoryDrain(): void {
    clearTimeout(this.historyRetryTimer);
    this.historyRetryTimer = -1;
    this.historyDraining = false;
  }
  private stopHistoryDrain(): void {
    this.pauseHistoryDrain();
    this.historyRetry.reset();
  }
  private scheduleHistoryPump(delay: number): void {
    if (this.historyRetryTimer >= 0) return;
    this.historyRetryTimer = setTimeout((): void => {
      this.historyRetryTimer = -1;
      this.pumpHistoryDrain();
    }, Math.max(0, delay));
  }
  private scheduleCache(): void {
    clearTimeout(this.cacheTimer);
    this.cacheTimer = setTimeout((): void => {
      this.cacheTimer = -1;
      this.persistCache();
    }, 500);
  }
  private enforceCacheLimit(activeSessionId: string): void {
    const protectedSessions: string[] = Array.from(this.client.drafts.keys())
      .concat(Array.from(this.client.uncertain.values()));
    NativeStorageManager.enforceDefaultLimit(this.context, this.client.cacheKey(),
      activeSessionId, protectedSessions).catch((): void => {});
  }
  private persistCache(): void {
    const id = this.selected;
    if (!id || !this.model.messages.length) return;
    const scope = this.client.cacheKey();
    NativeTranscriptCache.saveSession(this.context, scope, id, this.model)
      .then((): void => {
        this.enforceCacheLimit(id);
      }).catch(() => {});
  }
  private async pumpHistoryDrain(): Promise<void> {
    if (this.historyPumpRunning || !this.historyDraining || !this.mounted || !this.selected ||
      this.connectionPhase !== 'live' || !this.model.hasMore || this.model.historyBefore < 0) return;
    const id = this.selected;
    const generation = this.selectionGeneration;
    this.historyPumpRunning = true;
    const advanced = await this.older(true);
    this.historyPumpRunning = false;
    if (!this.mounted) return;
    if (this.selected !== id || this.selectionGeneration !== generation ||
      !this.historyDraining || this.connectionPhase !== 'live') {
      if (this.historyDraining) this.scheduleHistoryPump(0);
      return;
    }
    if (!this.model.hasMore || this.model.historyBefore < 0) {
      this.stopHistoryDrain();
      return;
    }
    if (advanced) {
      this.historyRetry.succeed();
      this.scheduleHistoryPump(40);
      return;
    }
    this.scheduleHistoryPump(this.historyRetry.nextDelay());
  }
  private async older(prefetch: boolean = false): Promise<boolean> {
    if (this.paging || !this.model.hasMore || this.model.historyBefore < 0) return false;
    const id = this.selected;
    const generation = this.selectionGeneration;
    const scope = this.client.cacheKey();
    const historyBefore = this.model.historyBefore;
    const historyCut = this.model.historyCut;
    const previousRows = this.model.messages.length;
    this.paging = true;
    if (!prefetch) this.followTail = false;
    try {
      const page = await this.client.page(id, historyBefore, historyCut, this.activeAddress);
      if (this.selected !== id || this.selectionGeneration !== generation || !this.mounted) return false;
      const offset = this.hasMore ? 1 : 0;
      let anchorIndex = Math.max(0, this.firstVisible - offset);
      const anchor = this.visibleRows[anchorIndex]?.id || '';
      let top = 0;
      try {
        top = this.scroller.getItemRect(anchorIndex + offset).y;
      } catch (_) {
        // LazyForEach can leave the anchor unmeasured during a fast fling.
        // Prepend the page without forcing a scroll correction in that case.
      }
      this.model.prepend(page);
      this.rememberTurnChangeReferences(Array.from(this.model.journal.values()));
      this.paint();
      if (!nativeHistoryPageAdvanced(historyBefore, page.beforeSeq, previousRows,
        this.model.messages.length, page.hasMore)) {
        throw new Error('History page did not advance');
      }
      NativeTranscriptCache.saveSession(this.context, scope, id, this.model)
        .then((): void => { this.enforceCacheLimit(id); }).catch(() => {});
      const next = this.visibleRows.findIndex((row: NativeMessage) => row.id === anchor);
      if (next >= 0 && top !== 0) setTimeout(() => { if (!this.mounted || this.selected !== id) return;
        try {
          this.scroller.scrollToIndex(next + (this.hasMore ? 1 : 0), false, ScrollAlign.START);
          this.scroller.scrollBy(0, -top);
        } catch (_) {}
      }, 0);
      return true;
    } catch (error) {
      if (this.selected === id && this.selectionGeneration === generation &&
        error instanceof NativeHttpError && error.status === 401) this.handleError(error as Error);
      return false;
    } finally {
      if (this.selectionGeneration === generation) this.paging = false;
    }
  }
  private isScrollAtEnd(): boolean {
    let atEnd = false;
    try { atEnd = this.scroller.isAtEnd(); } catch (_) {}
    return atEnd;
  }
  private settleScrollTail(): void {
    clearTimeout(this.returnToBottomTimer);
    const atEnd = this.isScrollAtEnd();
    this.returningToBottom = false;
    if (atEnd) {
      clearTimeout(this.backToBottomTimer);
      this.backToBottomVisible = false;
      this.backToBottomNew = false;
      this.followTail = true;
      return;
    }
    this.userHasScrolled = true;
    this.followTail = false;
    this.backToBottomVisible = true;
  }
  private updateScrollTail(): void {
    const atEnd = this.isScrollAtEnd();
    if (atEnd) {
      clearTimeout(this.backToBottomTimer);
      this.backToBottomVisible = false;
      this.backToBottomNew = false;
      this.followTail = true;
      this.returningToBottom = false;
      return;
    }
    if (!nativeBackToBottomAvailable(atEnd, this.userHasScrolled, this.returningToBottom)) return;
    this.followTail = false;
    clearTimeout(this.backToBottomTimer);
    this.backToBottomTimer = setTimeout((): void => {
      if (this.mounted && !this.followTail) this.backToBottomVisible = true;
    }, 100);
  }
  private transcriptIndex(message: NativeMessage): number {
    const index = this.visibleRows.findIndex((row: NativeMessage): boolean => row.id === message.id);
    return index < 0 ? -1 : index + (this.hasMore ? 1 : 0);
  }
  private terminalCardNearBottom(message: NativeMessage): boolean {
    const rowIndex = this.visibleRows.findIndex((row: NativeMessage): boolean => row.id === message.id);
    if (rowIndex < 0 || rowIndex !== this.visibleRows.length - 1) return false;
    if (this.isScrollAtEnd()) return true;
    try {
      const rect = this.scroller.getItemRect(this.transcriptIndex(message));
      const viewport = Math.max(1, this.transcriptViewportHeight);
      return rect.y < viewport && rect.y + rect.height >= viewport - 96;
    } catch (_) {
      return false;
    }
  }
  private followTerminalCardExpansion(message: NativeMessage): void {
    if (!this.terminalCardNearBottom(message)) return;
    clearTimeout(this.returnToBottomTimer);
    this.followTail = true;
    this.returningToBottom = true;
    setTimeout((): void => {
      if (!this.mounted || !this.returningToBottom ||
        this.visibleRows[this.visibleRows.length - 1]?.id !== message.id) return;
      try {
        if (NativeMotion.enabled()) this.scroller.scrollEdge(Edge.Bottom, { velocity: 5200 });
        else this.scroller.scrollToIndex(this.transcriptIndex(message), false, ScrollAlign.END);
      } catch (_) {}
    }, 0);
    this.returnToBottomTimer = setTimeout((): void => {
      if (this.mounted && this.returningToBottom) this.settleScrollTail();
    }, NativeMotion.enabled() ? 900 : 0);
  }
  private returnToBottom(): void {
    if (!this.selected || !this.visibleRows.length) return;
    clearTimeout(this.backToBottomTimer);
    this.backToBottomVisible = false;
    this.backToBottomNew = false;
    this.followTail = true;
    this.returningToBottom = true;
    const lastIndex = this.visibleRows.length - 1 + (this.hasMore ? 1 : 0);
    if (!NativeMotion.enabled()) {
      try { this.scroller.scrollToIndex(lastIndex, false, ScrollAlign.END); } catch (_) {}
      try { this.scroller.scrollEdge(Edge.Bottom); } catch (_) {}
      this.returnToBottomTimer = setTimeout((): void => {
        if (this.mounted && this.returningToBottom) this.settleScrollTail();
      }, 0);
      return;
    }
    try { this.scroller.scrollEdge(Edge.Bottom, { velocity: 6000 }); } catch (_) {}
    this.returnToBottomTimer = setTimeout((): void => {
      if (this.mounted && this.returningToBottom) this.settleScrollTail();
    }, 1400);
  }

  @Builder
  private sessionRow(row: NativeWorkspaceRow) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(row.session.title.trim() || '未命名会话').fontSize(14).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          .fontColor(this.primaryText())
        if (row.section === 'pinnedSession' && row.workspaceTitle) {
          Text(row.workspaceTitle).fontSize(10).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            .fontColor(this.tertiaryText())
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (row.session.running) {
        Text('运行中').fontSize(10).fontColor(NativeDesign.accent(this.dark))
      }
      if (row.pinned) {
        DSHIcon({ glyph: 'pin-fill', glyphSize: 12, color: this.tertiaryText() })
      }
      if (row.session.blank !== true) {
        Button({ type: ButtonType.Normal }) {
          Stack({ alignContent: Alignment.Center }) {
            DSHIcon({ glyph: 'ellipsis-outline',
              color: this.menuId === row.session.id ? this.primaryText() : this.tertiaryText() })
          }.width(NativeDesign.visualIconContainer).height(NativeDesign.visualIconContainer)
            .borderRadius(NativeDesign.radiusControl)
            .backgroundColor(this.menuId === row.session.id ? this.selectionSurface() : Color.Transparent)
        }
          .width(NativeDesign.hitTarget).height(NativeDesign.hitTarget).padding(4)
          .borderRadius(NativeDesign.radiusRow)
          .backgroundColor(Color.Transparent).enabled(!this.menuBusy)
          .accessibilityText(row.session.title + '，会话操作')
          .onClick(() => { this.menuTarget = row.session.id; this.menuId = row.session.id; })
          .bindPopup(this.menuId === row.session.id, { builder: this.sessionMenu, placement: Placement.BottomRight,
            enableArrow: false, targetSpace: 4, radius: 16, mask: false,
            popupColor: NativeDesign.overlay(this.dark), backgroundBlurStyle: BlurStyle.NONE,
            onStateChange: (event): void => {
              if (!event.isVisible && this.menuId === row.session.id) this.menuId = '';
            } })
      }
    }.padding({ left: 10, right: 4, top: 2, bottom: 2 }).width('100%')
      .constraintSize({ minHeight: NativeDesign.standardRow }).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.selected === row.session.id ?
        this.selectionSurface() : Color.Transparent)
      .animation(NativeMotion.implicit('micro'))
      .transition(NativeMotion.workspaceChildrenTransition())
  }

  @Builder
  private workspaceHeader(entry: NativeWorkspaceRow) {
    Row({ space: 6 }) {
      DSHIcon({ glyph: entry.section === 'pinnedHeader' ? 'pin-fill' : 'chevron-left-outline',
        glyphSize: 12, color: this.tertiaryText() })
        .rotate({ angle: entry.section === 'pinnedHeader' ? 0 :
          this.collapsedGroups.includes(entry.workspaceId) ? 180 : -90 })
        .animation(NativeMotion.disclosureParam())
      Text(entry.title).fontSize(12).fontWeight(FontWeight.Medium).layoutWeight(1)
        .fontColor(this.secondaryText())
      Text(String(entry.count)).fontSize(11).fontColor(this.tertiaryText())
      if (entry.section === 'pinnedHeader') {
        DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 12,
          color: this.tertiaryText() })
          .rotate({ angle: this.collapsedGroups.includes(entry.workspaceId) ? 180 : -90 })
          .animation(NativeMotion.disclosureParam())
      }
      if (entry.section === 'workspaceHeader') {
        DSHIcon({ glyph: 'drag-handle-outline', glyphSize: 13,
          color: this.dragWorkspaceId === entry.workspaceId ?
            this.accentColor() : this.tertiaryText() })
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'plus-outline', glyphSize: 13,
            color: this.secondaryText() })
        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
          .accessibilityText('在工作区新建会话')
          .onClick(() => { this.createQuickSession(entry.workspaceId); })
      }
    }.width('100%').constraintSize({ minHeight: 44 }).padding({ left: 6, right: 6 })
      .border({
        width: {
          top: this.dropWorkspaceId === entry.workspaceId && !this.dropWorkspaceAfter ? 2 : 0,
          bottom: this.dropWorkspaceId === entry.workspaceId && this.dropWorkspaceAfter ? 2 : 0
        },
        color: this.accentColor()
      })
      .opacity(this.dragWorkspaceId === entry.workspaceId ? 0.72 : 1)
      .scale({ x: this.dragWorkspaceId === entry.workspaceId ? 1.01 : 1,
        y: this.dragWorkspaceId === entry.workspaceId ? 1.01 : 1 })
      .animation(NativeMotion.implicit('micro'))
      .draggable(entry.section === 'workspaceHeader' && !this.menuBusy && !this.query.trim())
      .onDragStart((): CustomBuilder | DragItemInfo => this.beginWorkspaceDrag(entry.workspaceId))
      .onDragEnter((): void => {
        if (entry.section !== 'workspaceHeader' || entry.workspaceId === this.dragWorkspaceId) return;
        this.dropWorkspaceId = entry.workspaceId;
        this.dropWorkspaceAfter = false;
      })
      .onDragMove((event: DragEvent): void => {
        if (entry.section !== 'workspaceHeader' || entry.workspaceId === this.dragWorkspaceId) return;
        const rect = this.workspaceRowRects.get(entry.workspaceId) || [];
        this.dropWorkspaceId = entry.workspaceId;
        this.dropWorkspaceAfter = rect.length >= 2 &&
          event.getWindowY() > rect[0] + rect[1] / 2;
      })
      .onDragLeave((): void => {
        if (this.dropWorkspaceId === entry.workspaceId) this.dropWorkspaceId = '';
      })
      .onDrop((event: DragEvent): void => { this.dropWorkspace(entry.workspaceId, event); })
      .onDragEnd((): void => { this.cancelWorkspaceDrag(); })
      .onAreaChange((_old: Area, area: Area): void => {
        this.workspaceRowRects.set(entry.workspaceId,
          [Number(area.globalPosition.y), Number(area.height)]);
      })
      .transition(NativeMotion.rowTransition())
  }

  @Builder
  private sessionList(inMobileDrawer: boolean = false) {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        Text('DSH Harmony').fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1)
          .fontColor(this.primaryText())
        NativeIconButton({
          glyph: 'search-outline',
          label: this.searchOpen ? '关闭搜索' : '搜索工作区和会话',
          active: this.searchOpen,
          glyphSize: 17,
          onPressed: (): void => {
            if (this.searchOpen) this.query = '';
            NativeMotion.animate(this.getUIContext(), 'micro', (): void => {
              this.searchOpen = !this.searchOpen;
            });
          }
        })
        if (!this.wide) {
          NativeIconButton({ glyph: 'close-outline', label: '关闭侧边栏', glyphSize: 16,
            onPressed: (): void => { this.closeDrawer(); } })
        }
      }.width('100%').height(NativeDesign.headerHeight)
      Button({ type: ButtonType.Normal }) {
        Row({ space: 9 }) {
          DSHIcon({ glyph: 'new-chat-outline', glyphSize: 17, color: this.primaryText() })
          Text('新会话').fontSize(14).fontWeight(FontWeight.Medium)
          Blank()
        }.width('100%').padding({ left: 10, right: 10 })
      }.width('100%').height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusRow)
        .backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).enabled(!this.loading)
        .onClick(() => { this.openNewSession(); })
      Column({ space: 1 }) {
        Row({ space: 10 }) {
          DSHIcon({ glyph: 'code-outline', glyphSize: 17, color: this.secondaryText() })
          Text('插件').fontSize(14).layoutWeight(1).fontColor(this.primaryText())
        }.width('100%').height(NativeDesign.hitTarget).padding({ left: 10, right: 10 })
          .onClick(() => { this.openDrawerDestination(); })
        Row({ space: 10 }) {
          DSHIcon({ glyph: 'plan-outline', glyphSize: 17, color: this.secondaryText() })
          Text('自动化任务').fontSize(14).layoutWeight(1).fontColor(this.primaryText())
        }.width('100%').height(NativeDesign.hitTarget).padding({ left: 10, right: 10 })
          .onClick(() => { this.openDrawerDestination(); })
        Row({ space: 10 }) {
          DSHIcon({ glyph: 'ellipsis-outline', glyphSize: 17, color: this.secondaryText() })
          Text('更多').fontSize(14).layoutWeight(1).fontColor(this.primaryText())
        }.width('100%').height(NativeDesign.hitTarget).padding({ left: 10, right: 10 })
          .onClick(() => { this.openDrawerDestination(); })
      }.width('100%')
      if (this.searchOpen) {
        TextInput({ text: this.query, placeholder: '搜索工作区和会话' })
          .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCompact)
          .borderRadius(NativeDesign.radiusControl)
          .placeholderColor(this.tertiaryText())
          .backgroundColor(this.fieldSurface()).fontColor(this.primaryText())
          .onChange((value: string) => { this.query = value; })
          .transition(NativeMotion.rowTransition())
      }
      Row() {
        Text('工作区').fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.secondaryText())
        Blank()
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            DSHIcon({ glyph: 'browse-outline', glyphSize: 14, color: this.tertiaryText() })
            Text(this.workspaces.items.find((item: NativeWorkspaceItem) => item.workspaceId === this.workspaceId)?.title || '全部')
              .fontSize(11).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 110 })
              .textAlign(TextAlign.End)
              .fontColor(this.tertiaryText())
          }
        }.height(NativeDesign.hitTarget).padding({ left: 8, right: 0 })
          .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
          .onClick(() => { this.openWorkspacePicker(); })
      }.width('100%').padding({ left: 4, right: 0, top: 4 })
      List({ space: 2 }) {
        LazyForEach(this.sessionSource, (entry: NativeWorkspaceRow) => {
          ListItem() {
            Column() {
              if (entry.group) this.workspaceHeader(entry)
              else this.sessionRow(entry)
            }.width('100%').padding({ right: 8 })
          }.onClick(() => {
            if (!entry.group) this.select(entry.session.id);
            else this.toggleWorkspaceGroup(entry.workspaceId);
          }).accessibilityText(entry.group ? entry.title :
            entry.session.title + (entry.pinned ? '，已置顶' : '') +
            (entry.section === 'pinnedSession' && entry.workspaceTitle ?
              '，工作区 ' + entry.workspaceTitle : '') +
            (entry.session.running ? '，运行中' : ''))
        }, (entry: NativeWorkspaceRow) => entry.key)
      }.layoutWeight(1).width('100%').margin({ right: -8 }).cachedCount(8).scrollBar(BarState.Auto)
      if (this.workspaceError) {
        Row() {
          Text(this.workspaceError).fontSize(12).layoutWeight(1).fontColor(this.dangerText())
          Button('重试', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).fontSize(12)
            .onClick(() => { this.refreshWorkspaces(); })
        }.width('100%')
      }
      if (this.connectionPhase === 'retrying' && !this.selected) {
        Text('连接中断，正在尝试重连').fontSize(11).padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .width('100%').borderRadius(9).fontColor(this.secondaryText())
          .backgroundColor(this.selectionSurface())
      }
      if (this.loading) { Text('正在连接…').fontSize(13).fontColor(this.secondaryText()) }
      if (!this.loading && !this.visibleSessionCount) { Text('新建会话，开始你的任务').fontSize(13).fontColor(this.secondaryText()) }
      Divider().strokeWidth(0.5).color(this.dividerColor())
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          DSHIcon({ glyph: 'settings-outline', glyphSize: 17, color: this.secondaryText() })
          Text('设置').fontSize(14).layoutWeight(1).fontColor(this.primaryText())
        }.width('100%').padding({ left: 10, right: 10 })
      }.width('100%').height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusRow)
        .backgroundColor(Color.Transparent)
        .accessibilityText('应用设置').onClick(() => {
          this.onSettings();
        })
    }.padding({ left: 12, right: 12, top: this.safeTop + (inMobileDrawer ? 6 : 8),
      bottom: this.safeBottom + 8 }).height('100%').width('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private subagentReadOnlyComposer() {
    Row({ space: 8 }) {
      DSHIcon({ glyph: 'branch-outline', glyphSize: 15, color: this.tertiaryText() })
      Column({ space: 2 }) {
        Text(this.currentSubagentReadOnlyReason() === 'one-shot' ?
          '一次性子智能体记录' : '此子智能体暂时只读')
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
        Text(this.currentSubagentReadOnlyReason() === 'one-shot' ?
          '可查看完整执行记录' : '确认子会话模式后可继续')
          .fontSize(10).fontColor(this.tertiaryText())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: NativeDesign.hitTarget })
    .padding({ left: 10, right: 10 })
    .borderRadius(14)
    .backgroundColor(this.fieldSurface())
  }

  @Builder
  private subagentEditableComposer() {
    Column({ space: 8 }) {
      TextArea({ text: this.draft, placeholder: '发送消息…' }).height(44)
        .enabled(!this.sending && this.currentSubagentInputEnabled())
        .placeholderColor(this.tertiaryText())
        .fontSize(14).borderRadius(0).padding({ left: 7, right: 7, top: 3, bottom: 3 })
        .backgroundColor(Color.Transparent).fontColor(this.primaryText())
        .onChange((value: string) => { this.draft = value; this.client.drafts.set(this.selected, value); })
      Row({ space: 6 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 4 }) {
            Text(this.modelCaption).fontSize(11).maxLines(1).constraintSize({ maxWidth: 160 })
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.constraintSize({ maxWidth: 168 })
        }.height(NativeDesign.hitTarget).padding({ left: 4, right: 4 })
          .backgroundColor(Color.Transparent)
          .fontColor(this.secondaryText()).accessibilityText('模型与推理')
          .onClick(() => { this.utilityOpen = false; this.modelPickerOpen = true; })
          .bindPopup(this.modelPickerOpen, { builder: this.modelPicker, placement: Placement.Top,
            enableArrow: false, targetSpace: 8, radius: 16, mask: false,
            popupColor: NativeDesign.overlay(this.dark), backgroundBlurStyle: BlurStyle.NONE,
            onStateChange: (event): void => { if (!event.isVisible) this.modelPickerOpen = false; } })
        Blank()
        if (this.activeAddress.kind !== 'subagent') {
          Button({ type: ButtonType.Normal }) {
            if (this.attaching) { LoadingProgress().width(14).height(14).color(this.primaryText()) }
            else { DSHIcon({ glyph: 'image-outline', color: this.primaryText() }) }
          }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
            .borderRadius(NativeDesign.hitTarget / 2)
            .backgroundColor(this.fieldSurface()).fontColor(this.primaryText())
            .accessibilityText(this.attaching ? '读取中' : '添加图片')
            .enabled(!this.attaching && !this.sending).onClick(() => { this.attachImages(); })
          Button({ type: ButtonType.Normal }) {
            DSHIcon({ glyph: 'file-outline', color: this.secondaryText() })
          }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
            .borderRadius(NativeDesign.hitTarget / 2)
            .backgroundColor(this.fieldSurface()).fontColor(this.primaryText())
            .accessibilityText('添加文件')
            .enabled(!this.attaching && !this.sending).onClick(() => { this.attachFiles(); })
        }
        if (this.running) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 5 }) {
              DSHIcon({ glyph: this.steer ? 'paper-plane-outline' : 'queue-outline',
                color: this.secondaryText(), glyphSize: 14 })
              Text(this.steer ? '接管' : '排队').fontSize(11).fontColor(this.secondaryText())
            }
          }.height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(Color.Transparent)
            .accessibilityText(this.steer ? '发送模式：接管' : '发送模式：排队，点击切换')
            .onClick(() => { this.steer = !this.steer; })
        }
        if (this.running && !this.sending && !this.draft.trim() && !this.attachments.length) {
          Button({ type: ButtonType.Normal }) {
            DSHIcon({ glyph: 'stop-fill', color: NativeDesign.textInverse(this.dark) })
          }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
            .borderRadius(NativeDesign.hitTarget / 2)
            .backgroundColor(NativeDesign.accentStrong(this.dark)).accessibilityText('停止任务')
            .onClick(() => {
              this.client.cancel(this.selected,
                this.activeAddress.kind === 'subagent' ? this.activeAddress : null)
                .catch((error: Error) => this.handleError(error));
            })
        } else {
          Button({ type: ButtonType.Normal }) {
            if (this.sending) {
              LoadingProgress().width(16).height(16)
                .color(NativeDesign.textInverse(this.dark))
            } else {
              DSHIcon({ glyph: 'send-arrow', color: NativeDesign.textInverse(this.dark) })
            }
          }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
            .borderRadius(NativeDesign.hitTarget / 2)
            .backgroundColor(NativeDesign.accentStrong(this.dark))
            .enabled(this.connectionPhase === 'live' && !this.sending && !this.uncertain &&
              this.attachmentsReady() && (this.draft.trim().length > 0 || this.attachments.length > 0))
            .opacity(this.connectionPhase === 'live' && !this.sending && !this.uncertain &&
              this.attachmentsReady() && (this.draft.trim().length > 0 || this.attachments.length > 0) ?
              1 : 0.4)
            .accessibilityText(this.sending ? '发送中' : '发送')
            .onClick(() => { this.followTail = true; this.send(); })
        }
      }.width('100%')
    }.padding(8).width('100%').borderRadius(16)
      .border({ width: 0.5, color: this.semanticBorderColor() })
      .backgroundColor(this.raisedSurface())
      .onAreaChange((_old: Area, area: Area): void => {
        const height = Number(area.height);
        if (height > 0 && height !== this.composerHeight) this.composerHeight = height;
      })
  }

  @Builder
  private conversation() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        if (this.activeAddress.kind === 'subagent') {
          NativeIconButton({ glyph: 'chevron-left-outline', label: '返回父会话', tone: 'primary',
            onPressed: (): void => { this.backToParentSession(); } })
        }
        if (!this.wide) {
          NativeIconButton({ glyph: 'panel-left-outline', label: '打开侧边栏', tone: 'primary',
            onPressed: (): void => { this.openDrawer(); } })
        }
        Column({ space: 1 }) {
          if (this.activeAddress.kind === 'subagent') {
            Text(this.currentParentTitle()).fontSize(10).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              .fontColor(this.tertiaryText())
          }
          Text(this.title).fontSize(15).fontWeight(FontWeight.Medium)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            .fontColor(this.primaryText())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          .onClick(() => {
            this.getUIContext().getPromptAction().showDialog({
              title: this.activeAddress.kind === 'subagent' ? '子智能体会话' : '会话标题',
              message: this.title,
              buttons: [{ text: '关闭', color: this.accentColor() }]
            });
          })
        if ((this.connectionPhase === 'opening' || this.connectionPhase === 'syncing') &&
          !this.model.messages.length) {
          LoadingProgress().width(14).height(14).color(this.accentColor())
            .accessibilityText('正在加载会话')
        }
        NativeIconButton({ glyph: 'ellipsis-outline', label: '更多操作',
          active: this.utilityOpen, glyphSize: 16,
          onPressed: (): void => { this.openUtilities(); } })
      }.width('100%')
      if (nativePlanTargetActive(this.planProjection) || this.planError ||
        ((this.subagentCatalog?.length || 0) > 0)) {
        Row({ space: 6 }) {
          if (nativePlanTargetActive(this.planProjection)) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 5 }) {
                DSHIcon({ glyph: 'plan-outline', glyphSize: 14, color: this.accentColor() })
                Text('计划').fontSize(11).fontColor(this.accentColor())
                if (this.planLeaving) LoadingProgress().width(11).height(11).color(this.accentColor())
              }
            }
            .height(28)
            .padding({ left: 9, right: 9 })
            .borderRadius(14)
            .backgroundColor(this.selectionSurface())
            .border({ width: 0.5, color: this.semanticBorderColor() })
            .enabled(!this.planLeaving)
            .accessibilityText('计划模式已开启，点击关闭')
            .onClick((): void => { this.exitPlanMode(); })
          }
          if (this.planError) {
            Text(this.planError).fontSize(10).fontColor(this.dangerText())
              .transition(NativeMotion.rowTransition())
          }
          Blank()
          if ((this.subagentCatalog?.length || 0) > 0) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 5 }) {
                if (this.runningSubagentCount() > 0) {
                  Text('').width(6).height(6).borderRadius(3)
                    .backgroundColor(this.accentColor())
                } else {
                  DSHIcon({ glyph: 'branch-outline', glyphSize: 13, color: this.secondaryText() })
                }
                Text((this.subagentCatalog?.length || 0).toString() + ' 个子智能体')
                  .fontSize(11).fontColor(this.secondaryText())
                DSHIcon({ glyph: 'chevron-down-outline', glyphSize: 12, color: this.tertiaryText() })
              }
            }
            .height(28)
            .padding({ left: 9, right: 8 })
            .borderRadius(14)
            .backgroundColor(this.fieldSurface())
            .border({ width: 0.5, color: this.semanticBorderColor() })
            .accessibilityText((this.subagentCatalog?.length || 0).toString() +
              ' 个子智能体' + (this.runningSubagentCount() > 0 ? '，正在运行' : ''))
            .onClick((): void => { this.openLineage(); })
          }
        }.width('100%')
      }
      if (this.connectionPhase === 'retrying') {
        Row({ space: 8 }) {
          Text('•').fontSize(14).fontColor(this.warningText())
          Text('连接中断，正在尝试重连').fontSize(12).fontColor(this.secondaryText())
          Blank()
        }.padding({ left: 10, right: 10, top: 6, bottom: 6 }).width('100%').borderRadius(9)
          .backgroundColor(this.selectionSurface())
      }
      Stack({ alignContent: Alignment.TopStart }) {
        List({ space: 12, scroller: this.scroller }) {
          if (this.hasMore) {
            ListItem() {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 4 }) {
                  if (this.paging) LoadingProgress().width(12).height(12)
                  else DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 12,
                    color: this.tertiaryText() }).rotate({ angle: 90 })
                  Text(this.paging ? '读取中' : '更早').fontSize(11)
                    .fontColor(this.tertiaryText())
                }
              }.enabled(!this.paging).height(NativeDesign.hitTarget).padding({ left: 9, right: 9 })
                .borderRadius(NativeDesign.radiusControl)
                .backgroundColor(Color.Transparent).onClick(() => { this.startHistoryDrain(false); })
            }
          }
          LazyForEach(this.source, (message: NativeMessage) => {
            ListItem() {
              if (message.role === 'process') {
                NativeProcessView({ client: this.client, sessionId: this.selected, message,
                  workspaceRoot: this.workspaceRootFor(this.selected),
                  onOpenFile: (path: string): void => { this.openTurnChangeFile(path); },
                  disclosures: this.model.disclosures,
                  newlyAppeared: this.processEntranceIds.includes(message.id),
                  maxExpandedHeight: Math.max(180, this.transcriptViewportHeight * 0.6),
                  maxChildExpandedHeight: Math.max(120, this.transcriptViewportHeight * 0.36) })
              } else if (message.role === 'turn-footer') {
                if (this.turnChangeFor(message.turnKey).fileCount > 0) {
                  NativeTurnChangesCard({
                    summary: this.turnChangeFor(message.turnKey),
                    workspaceRoot: this.workspaceRootFor(this.selected),
                    maxExpandedHeight: Math.max(180, this.transcriptViewportHeight * 0.45),
                    copied: this.footerCopiedId === message.footerCopyMessageId,
                    canCopy: !!message.footerCopyText,
                    onOpenFile: (path: string): void => { this.openTurnChangeFile(path); },
                    onExpandedChange: (expanded: boolean): void => {
                      if (expanded) this.followTerminalCardExpansion(message);
                    },
                    onCopy: (): void => {
                      this.copyFooter(message.footerCopyText, message.footerCopyMessageId);
                    }
                  })
                } else {
                  Row({ space: 8 }) {
                    Text(message.label + (message.text ? ' · ' + message.text : '')).fontSize(11).layoutWeight(1)
                      .fontColor(message.footerOutcome === 'failed' ?
                        NativeDesign.danger(this.dark) : this.tertiaryText())
                    if (message.footerCopyText) {
                      Button({ type: ButtonType.Normal }) {
                        DSHIcon({ glyph: this.footerCopiedId === message.footerCopyMessageId ?
                          'check-outline' : 'copy-outline', glyphSize: 13,
                          color: this.tertiaryText() })
                      }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
                        .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
                        .accessibilityText(this.footerCopiedId === message.footerCopyMessageId ?
                          '答复已复制' : '复制最终答复')
                        .onClick((): void => {
                          this.copyFooter(message.footerCopyText, message.footerCopyMessageId);
                        })
                    }
                  }.width('100%').constraintSize({ minHeight: NativeDesign.hitTarget })
                }
              } else if (message.role === 'background-notice') {
                NativeBackgroundNoticeView({ message: message })
              } else { Row() {
                if (message.role === 'user') { Blank().layoutWeight(1) }
                NativeMessageView({
                  client: this.client,
                  sessionId: this.selected,
                  message: message,
                  onCompatibility: this.onCompatibility,
                  dshUiCanReply: nativeDshUiCanReply(this.visibleRows, message.id,
                    this.running, this.waiting),
                  onDshUiReply: (text: string): Promise<boolean> => this.sendDshUiReply(text)
                })
              }.width('100%').alignItems(VerticalAlign.Top) }
            }
          }, (message: NativeMessage) => message.id)
        }.contentStartOffset(this.taskPlan.items.length ? this.conversationDockHeight : 0)
          .width('100%').height('100%').cachedCount(6)
          .edgeEffect(NativeExperience.reducedMotion() ? EdgeEffect.None : EdgeEffect.Spring)
          .onReachStart(() => {
            if (this.userHasScrolled && this.hasMore && this.connectionPhase === 'live') this.startHistoryDrain(false);
          })
          .onScrollIndex((first: number) => {
            this.firstVisible = first;
            if (this.userHasScrolled && first <= 20 && this.hasMore && this.connectionPhase === 'live') this.startHistoryDrain(false);
          })
          .onScrollFrameBegin((offset: number, state: ScrollState) => {
            if (state === ScrollState.Scroll && !this.returningToBottom) {
              this.markScrollActivity();
            }
            return { offsetRemain: offset };
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down && this.returningToBottom) {
              clearTimeout(this.returnToBottomTimer);
              this.returningToBottom = false;
              this.userHasScrolled = true;
              this.updateScrollTail();
            } else if (event.type === TouchType.Move) {
              this.markScrollActivity(true);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.scheduleScrollMotionSettle();
            }
          })
          .onScroll(() => { this.markScrollActivity(); })
          .onScrollStop(() => {
            if (this.returningToBottom) this.settleScrollTail();
            else if (this.scrollMotionActive) this.scheduleScrollMotionSettle();
            else this.updateScrollTail();
          })
        if (this.taskPlan.items.length) {
          Column() {
            NativeConversationDock() {
              NativeTaskDock({ document: this.taskPlan, sessionId: this.selected })
            }
          }.width('100%').zIndex(4)
            .onAreaChange((_old: Area, area: Area): void => {
              const height = Number(area.height);
              if (height > 0 && height !== this.conversationDockHeight) this.conversationDockHeight = height;
            })
            .transition(NativeMotion.disclosureTransition())
            .animation(NativeMotion.disclosureParam())
        }
        if (this.backToBottomVisible && !this.menuId && !this.utilityOpen &&
          !this.modelPickerOpen && !this.toolsOpen && !this.workspacePickerOpen &&
          !this.showSessions) {
          Stack({ alignContent: Alignment.Bottom }) {
            Button({ type: ButtonType.Circle }) {
              Stack({ alignContent: Alignment.Center }) {
                DSHIcon({ glyph: 'chevron-down-outline', glyphSize: 17,
                  color: this.primaryText() })
                if (this.backToBottomNew) {
                  Text('').position({ x: 12, y: -12 }).width(6).height(6).borderRadius(6)
                    .backgroundColor(this.accentColor())
                }
              }.width(39).height(39).borderRadius(19.5).clip(true)
                .backgroundColor(this.raisedSurface())
                .opacity(this.backToBottomPressed ? 0.85 : 0.6)
                .border({ width: 0.7, color: this.semanticBorderColor() })
                .shadow({ radius: 12, color: this.dark ? '#40000000' : '#26000000', offsetY: 2 })
            }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
              .padding(2.5).backgroundColor(Color.Transparent)
              .accessibilityText(this.backToBottomNew ? '回到底部，有新内容' : '回到底部')
              .onTouch((event: TouchEvent): void => {
                this.backToBottomPressed = event.type === TouchType.Down;
              })
              .onClick((): void => {
                this.backToBottomPressed = false;
                this.returnToBottom();
              })
              .margin({ bottom: 4 })
              .transition(NativeMotion.rowTransition())
          }.width('100%').height('100%')
            .hitTestBehavior(HitTestMode.Transparent).zIndex(6)
        }
      }.layoutWeight(1).width('100%')
        .onAreaChange((_old: Area, area: Area): void => {
          const height = Number(area.height);
          if (height > 0 && height !== this.transcriptViewportHeight) this.transcriptViewportHeight = height;
        })
      ForEach(this.interactions.concat(this.continued), (frame: NativeFrame) => {
        NativeInteraction({ client: this.client, frame, onDone: (): void => {
          this.interactions = this.interactions.filter((item: NativeFrame) => item.eventId !== frame.eventId);
          this.continued = this.continued.filter((item: NativeFrame) => item.eventId !== frame.eventId);
        } })
      }, (frame: NativeFrame) => frame.eventId)
      if (this.waiting && !this.interactions.length && !this.continued.length) {
          Button('有待处理输入 · 打开完整交互', { type: ButtonType.Normal })
            .height(NativeDesign.hitTarget).fontSize(12).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(this.fieldSurface()).fontColor(this.primaryText())
          .onClick(this.onCompatibility)
      }
      if (this.uncertain) {
        Button('发送结果未确认 · 已检查会话，允许再次发送', { type: ButtonType.Normal })
          .height(NativeDesign.hitTarget).fontSize(11)
          .backgroundColor(Color.Transparent).fontColor(this.secondaryText())
          .onClick(() => { this.client.uncertain.delete(this.selected); this.uncertain = false; })
      }
      NativeBottomConversationDock({
        horizontalBleed: 12,
        contentInset: 0,
        elevated: this.liveTurnChangesVisible || this.attachments.length > 0 ||
          this.queueItems().length > 0 || this.error.length > 0
      }) {
        Column({ space: 8 }) {
          if (this.error) {
            Row({ space: 8 }) {
              Text('!').fontSize(11).fontWeight(FontWeight.Bold)
                .fontColor(this.dangerText())
                .width(18).height(18).borderRadius(9).textAlign(TextAlign.Center)
                .backgroundColor(NativeDesign.dangerSurface(this.dark))
              Text(this.error).fontSize(11).lineHeight(16).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                .fontColor(this.dangerText())
              NativeIconButton({ glyph: 'close-outline', label: '关闭错误', glyphSize: 12,
                onPressed: (): void => { this.error = ''; } })
            }.width('100%').padding({ left: 8, right: 2, top: 5, bottom: 5 })
              .borderRadius(12)
              .backgroundColor(NativeDesign.dangerSurface(this.dark))
              .border({ width: 0.5, color: this.semanticBorderColor() })
              .transition(NativeMotion.disclosureTransition())
          }
          if (this.queueItems().length) {
            NativeQueueDock({
              client: this.client,
              sessionId: this.selected,
              items: this.queueItems(),
              running: this.running,
              onChanged: (): void => {}
            }).transition(NativeMotion.disclosureTransition())
          }
          if (this.liveTurnChangesVisible) {
            Row() {
              NativeTurnChangePill({
                summary: this.liveTurnChanges,
                maxWidth: Math.min(360, Math.max(180, this.windowWidth - 64))
              })
            }.width('100%').height(30).justifyContent(FlexAlign.Center)
              .hitTestBehavior(HitTestMode.None)
              .transition(NativeMotion.disclosureTransition())
          }
          if (this.attachments.length) {
            Row() {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.attachments, (item: NativeAttachmentDraft) => {
                    if (item.kind === 'image') {
                      Stack({ alignContent: Alignment.Center }) {
                        Image(item.uri).width(46).height(46).borderRadius(11).objectFit(ImageFit.Cover)
                        if (item.status === 'uploading') {
                          Stack({ alignContent: Alignment.Center }) {
                            LoadingProgress().width(16).height(16).color('#FFFFFF')
                          }.width(46).height(46).borderRadius(11).backgroundColor('#66000000')
                        } else if (item.status === 'error') {
                          Text('!').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                            .width(22).height(22).borderRadius(11).textAlign(TextAlign.Center)
                            .backgroundColor('#C34B4B')
                        }
                        Button({ type: ButtonType.Circle }) {
                          Stack({ alignContent: Alignment.Center }) {
                            DSHIcon({ glyph: 'close-outline', glyphSize: 9, color: '#FFFFFF' })
                          }.width(20).height(20).borderRadius(10).backgroundColor('#99000000')
                        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
                          .backgroundColor(Color.Transparent).align(Alignment.TopEnd)
                          .accessibilityText('移除附件').onClick(() => { this.removeAttachment(item.id); })
                      }.width(48).height(48).borderRadius(12)
                        .backgroundColor(this.fieldSurface())
                        .shadow({ radius: 7, color: this.dark ? '#66000000' : '#22000000', offsetY: 2 })
                        .accessibilityText(item.status === 'error' ? '图片上传失败，点击重试' : '图片附件')
                        .onClick(() => { if (item.status === 'error') this.retryAttachment(item); })
                        .transition(NativeMotion.disclosureTransition())
                    } else {
                      Row({ space: 6 }) {
                        DSHIcon({ glyph: 'file-outline', glyphSize: 16, color: this.secondaryText() })
                        Text(item.name).fontSize(11).maxLines(1).constraintSize({ maxWidth: 120 })
                          .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.primaryText())
                        if (item.status === 'uploading') LoadingProgress().width(12).height(12)
                        else if (item.status === 'error') {
                          Button(item.retryable ? '重试' : '失败', { type: ButtonType.Normal })
                            .height(NativeDesign.hitTarget).fontSize(10)
                            .fontColor(item.retryable ?
                              NativeDesign.danger(this.dark) : NativeDesign.textTertiary(this.dark))
                            .enabled(item.retryable).onClick(() => { this.retryAttachment(item); })
                        }
                        Button({ type: ButtonType.Circle }) {
                          DSHIcon({ glyph: 'close-outline', glyphSize: 10, color: this.tertiaryText() })
                        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
                          .backgroundColor(Color.Transparent)
                          .accessibilityText('移除附件').onClick(() => { this.removeAttachment(item.id); })
                      }.height(NativeDesign.standardRow).padding({ left: 7, right: 3 })
                        .borderRadius(NativeDesign.radiusControl)
                        .backgroundColor(this.fieldSurface())
                        .transition(NativeMotion.disclosureTransition())
                    }
                  }, (item: NativeAttachmentDraft) => item.id)
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }.width('100%').padding({ left: 8, right: 12 })
              .transition(NativeMotion.disclosureTransition())
          }
          if (this.currentSubagentReadOnlyReason()) {
            this.subagentReadOnlyComposer()
          } else {
            this.subagentEditableComposer()
          }
        }.width('100%')
      }
    }.padding({ left: 12, right: 12, top: this.safeTop + 4,
      bottom: 0 })
      .height('100%').layoutWeight(1)
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private mainSurface() {
    Column() {
      if (this.selected) {
        this.conversation()
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Column({ space: 14 }) {
          Text(this.loading ? '正在恢复会话…' : '开始你的任务').fontSize(22).fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
            if (!this.loading) {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 8 }) {
                  DSHIcon({ glyph: 'new-chat-outline', glyphSize: 17, color: this.baseSurface() })
                  Text('新建会话').fontSize(14)
                }
              }.height(NativeDesign.standardRow).padding({ left: 16, right: 16 })
                .borderRadius(NativeDesign.radiusRow)
                .backgroundColor(this.primaryText())
                .fontColor(this.baseSurface()).onClick(() => { this.openNewSession(); })
            } else {
              LoadingProgress().width(22).height(22).color(this.primaryText())
            }
          }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(24)
          if (!this.wide) {
            Row() {
              NativeIconButton({ glyph: 'panel-left-outline', label: '打开侧边栏',
                tone: 'primary', onPressed: (): void => { this.openDrawer(); } })
            }.margin({ left: 8, top: this.safeTop + 4 })
          }
        }.width('100%').height('100%')
      }
      if (this.archivedUndo) {
        Row() {
          Text('已归档会话').fontSize(12).layoutWeight(1)
          Button('撤销', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).fontSize(12)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              const id = this.archivedUndo; this.archivedUndo = '';
              this.client.operation(JSON.stringify({ operation: 'unarchive', sessionId: id }))
                .then(() => { this.refreshSessionList(); }).catch((error: Error) => this.handleError(error));
            })
          NativeIconButton({ glyph: 'close-outline', label: '关闭归档提示', glyphSize: 12,
            onPressed: (): void => { this.archivedUndo = ''; } })
        }.padding({ left: 12, right: 8 }).width('100%').backgroundColor(this.fieldSurface())
      }
      if (this.error && !this.selected) {
        Text(this.error).fontSize(12).padding(12).width('100%').fontColor(this.dangerText())
      }
    }.width('100%').height('100%').backgroundColor(this.baseSurface())
  }

  @Builder
  private mobileShell() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() { this.mainSurface() }.width('100%').height('100%')
      Column()
        .width('100%').height('100%')
        .backgroundColor(NativeDesign.mask(this.dark))
        .opacity(this.drawerProgress(this.mobileDrawerWidth()))
        .animation(NativeMotion.maskParam())
        .hitTestBehavior(this.showSessions || this.drawerFollowing ? HitTestMode.Default : HitTestMode.None)
        .onClick(() => { this.closeDrawer(); })
      Column() { this.sessionList(true) }.width(this.mobileDrawerWidth()).height('100%')
        .translate({ x: this.showSessions || this.drawerFollowing ? this.drawerTranslation : -this.mobileDrawerWidth() })
        .visibility(this.showSessions || this.drawerFollowing ? Visibility.Visible : Visibility.Hidden)
        .hitTestBehavior(this.showSessions || this.drawerFollowing ? HitTestMode.Default : HitTestMode.None)
        .shadow({
          radius: 28,
          color: this.dark ? '#99000000' : '#33000000',
          offsetX: 5,
          offsetY: 0
        })
        .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 8 })
          .onActionStart((): void => { this.beginDrawerPan(); })
          .onActionUpdate((event: GestureEvent): void => { this.updateDrawerPan(event); })
          .onActionEnd((event: GestureEvent): void => { this.settleDrawerPan(event); })
          .onActionCancel((): void => { this.cancelDrawerPan(); }))
      if (!this.showSessions) {
        Row().position({ x: 0, y: 0 }).width(18).height('100%').backgroundColor(Color.Transparent)
          .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 8 })
            .onActionStart((): void => { this.beginDrawerPan(); })
            .onActionUpdate((event: GestureEvent): void => { this.updateDrawerPan(event); })
            .onActionEnd((event: GestureEvent): void => { this.settleDrawerPan(event); })
            .onActionCancel((): void => { this.cancelDrawerPan(); }))
      }
    }.width('100%').height('100%')
  }

  @Builder
  private lineageOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(NativeDesign.mask(this.dark))
        .onClick((): void => {
          this.lineageOpen = false;
          this.navigationChanged();
        })
      NativeSubagentLineage({
        dark: this.dark,
        title: this.currentSubagentTitle() || this.title,
        entries: this.subagentCatalog || [],
        currentId: this.activeAddress.kind === 'subagent' ?
          this.activeAddress.childSessionId : '',
        loading: this.lineageLoading,
        error: this.lineageError,
        maxHeight: Math.max(280, Math.min(520, this.transcriptViewportHeight * 0.6)),
        bottomInset: this.safeBottom,
        onClose: (): void => {
          this.lineageOpen = false;
          this.navigationChanged();
        },
        onOpen: (entry: NativeSubagentEntry): void => { this.openSubagent(entry); },
        onRetry: (): void => {
          this.lineageLoading = true;
          this.lineageError = '';
          this.loadSelectedProjections();
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.wide) {
        SideBarContainer(SideBarContainerType.Embed) {
          Column() { this.sessionList() }.width('100%').height('100%')
          Column() { this.mainSurface() }.width('100%').height('100%')
        }
        .showSideBar(true)
        .showControlButton(false)
        .autoHide(false)
        .sideBarPosition(SideBarPosition.Start)
        .sideBarWidth(248)
        .minSideBarWidth(248)
        .maxSideBarWidth(248)
        .divider(null)
        .width('100%').height('100%')
        .onAreaChange((_old: Area, area: Area) => {
          this.windowWidth = Number(area.width);
          this.wide = this.windowWidth >= 760;
          this.navigationChanged();
        })
      } else {
        Column() { this.mobileShell() }.width('100%').height('100%')
          .onAreaChange((_old: Area, area: Area) => {
            this.windowWidth = Number(area.width);
            this.wide = this.windowWidth >= 760;
            this.navigationChanged();
          })
      }

      if (this.utilityOpen) { this.utilityOverlay() }
      if (this.lineageOpen) { this.lineageOverlay() }
      if (this.workspacePickerOpen) {
        Column() {
          NativeWorkspacePicker({ client: this.client, snapshot: this.workspaces, sessions: this.sessions,
            selectedId: this.workspaceId, page: this.workspacePickerPage,
            navigationDirection: this.workspacePickerDirection,
            onClose: (): void => { this.closeWorkspacePicker(); },
            onPageChange: (page: string): void => { this.setWorkspacePickerPage(page); },
            onSelect: (id: string): void => {
              this.workspaceId = id; this.closeWorkspacePicker(); this.setDrawerState(true);
            },
            onChanged: (value: NativeWorkspaceSnapshot): void => { this.workspaces = value; } })
        }.width('100%').height('100%').backgroundColor(this.baseSurface())
      }
      if (this.newSessionOpen) {
        Column() { this.newSessionForm() }.width('100%').height('100%')
          .backgroundColor(this.baseSurface())
      }
      if (this.toolsOpen) {
        NativeSessionTools({ client: this.client, sessionId: this.toolsId,
          sessionTitle: this.sessions.find((item: NativeSession) => item.id === this.toolsId)?.title || this.title,
          onClose: (): void => { this.toolsOpen = false; },
          onRename: (title: string): void => {
            if (this.toolsId === this.selected) this.title = title;
            this.toolsOpen = false; this.refreshSessionList();
          } })
      }
      if (this.fileViewOpen) {
        NativeFileBrowser({ client: this.client, sessionId: this.fileView.sessionId,
          workspaceRoot: this.workspaceRootFor(this.fileView.sessionId),
          path: this.fileView.kind === 'browser' ? this.fileView.path : this.browserDirectoryForFile(this.fileView.path),
          initialPreviewPath: this.fileView.kind === 'file' ? this.fileView.path : '',
          previewOnly: this.fileView.previewOnly,
          onClose: (): void => { this.closeFileView(); } })
      }
      if (this.imagePreviewOpen) {
        NativeImageLightbox({ client: this.client, sessionId: this.imagePreview.sessionId,
          attachment: this.imagePreview.attachment,
          onClose: (): void => { this.closeImagePreview(); } })
      }
    }.width('100%').height('100%').backgroundColor(this.baseSurface())
  }
  @Builder
  private newSessionForm() {
    Column({ space: 12 }) {
      Row({ space: 6 }) {
        NativeIconButton({ glyph: 'chevron-left-outline', label: '关闭新建会话', tone: 'primary',
          onPressed: (): void => { this.newSessionOpen = false; } })
        Text('新建会话').fontSize(18).fontWeight(FontWeight.Medium)
      }.width('100%')
      Scroll() {
        Column({ space: 8 }) {
          Text('工作区').fontSize(12).fontColor(this.tertiaryText())
          Button('默认目录', { type: ButtonType.Normal }).width('100%').height(NativeDesign.hitTarget)
            .borderRadius(NativeDesign.radiusControl)
            .backgroundColor(!this.newWorkspaceId ? this.fieldSurface() : Color.Transparent)
            .onClick(() => { this.newWorkspaceId = ''; })
          ForEach(this.workspaces.items, (workspace: NativeWorkspaceItem) => {
            Button(workspace.title, { type: ButtonType.Normal }).height(NativeDesign.hitTarget)
              .width('100%').borderRadius(NativeDesign.radiusControl)
              .backgroundColor(this.newWorkspaceId === workspace.workspaceId ? this.fieldSurface() : Color.Transparent)
              .onClick(() => { this.newWorkspaceId = workspace.workspaceId; })
          }, (workspace: NativeWorkspaceItem) => workspace.workspaceId)
          if (!this.newWorkspaceId) { TextInput({ text: this.newCwd, placeholder: '工作目录' })
            .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCompact)
            .onChange((value: string) => { this.newCwd = value; }) }
          TextInput({ text: this.newPreset, placeholder: '智能体预设 · 默认' })
            .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCompact)
            .onChange((value: string) => { this.newPreset = value; })
          Button(this.loading ? '创建中…' : '创建会话', { type: ButtonType.Normal })
            .height(NativeDesign.hitTarget).width('100%').borderRadius(NativeDesign.radiusControl)
            .backgroundColor(NativeDesign.accentStrong(this.dark))
            .fontColor(NativeDesign.textInverse(this.dark))
            .enabled(!this.loading).onClick(() => { this.createSession(); })
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top)
    }.padding(12).width('100%').height('100%').foregroundColor(this.primaryText())
  }
}
