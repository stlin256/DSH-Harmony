import { UIAbility, Want, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { WindowAppearance } from '../services/WindowAppearance';
import { NativeExperience } from '../services/NativeExperience';
import { NativeUiFixture } from '../services/NativeUiFixture';
import { accessibility } from '@kit.AccessibilityKit';
import { ProductCapabilities } from 'entry/ProductCapabilities';

export default class EntryAbility extends UIAbility {
  private readonly motionChanged = (enabled: boolean): void => {
    AppStorage.setOrCreate<boolean>('nativeSystemReduceMotion', enabled);
    NativeExperience.changed();
  };
  onCreate(want: Want): void {
    AppStorage.setOrCreate<boolean>('systemDark', this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    AppStorage.setOrCreate<boolean>('pocketPageThemeKnown', false);
    AppStorage.setOrCreate<boolean>('nativeImeVisible', false);
    AppStorage.setOrCreate<number>('nativeImeHeight', 0);
    webview.WebviewController.initializeWebEngine();
    // Debug builds alone expose the standard HDC-forwarded inspection socket.
    if (this.context.applicationInfo.debug) webview.WebviewController.setWebDebuggingAccess(true);
    this.updateTextScale(this.context.config);
    NativeExperience.refresh(this.context);
    try { accessibility.onAnimationReduceStateChange(this.motionChanged); } catch (_) {}
    this.route(want);
  }

  onNewWant(want: Want): void { this.route(want); }

  onForeground(): void {
    AppStorage.setOrCreate<boolean>('nativeAppActive', true);
    NativeExperience.refresh(this.context,
      AppStorage.get<boolean>('storeReviewPresentationActive') === true ||
      AppStorage.get<boolean>('storeShowcase') === true);
    AppStorage.setOrCreate<number>('pocketForegroundRevision', (AppStorage.get<number>('pocketForegroundRevision') || 0) + 1);
  }

  onBackground(): void {
    AppStorage.setOrCreate<boolean>('nativeAppActive', false);
    NativeExperience.changed();
  }

  onWindowStageCreate(stage: window.WindowStage): void {
    const mainWindow = stage.getMainWindowSync();
    WindowAppearance.mainWindow = mainWindow;
    WindowAppearance.observeKeyboard();
    // Keep both system bars visible while painting their background from the
    // active page. Native content handles the corresponding safe-area insets.
    WindowAppearance.fullscreen(true).then(() => {
      WindowAppearance.refreshSafeArea();
      WindowAppearance.apply(this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      stage.loadContent('pages/Index');
    }).catch(() => { stage.loadContent('pages/Index'); });
  }

  private updateTextScale(config: Configuration): void {
    AppStorage.setOrCreate<number>('nativeTitleHeight', Math.min(88, Math.max(56, Math.ceil(56 * (config.fontSizeScale || 1)))));
  }

  onConfigurationUpdate(config: Configuration): void {
    AppStorage.setOrCreate<boolean>('systemDark', config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    this.updateTextScale(config);
    WindowAppearance.refreshSafeArea();
    // A manually selected Harness theme takes precedence over an OS change.
    // System-following pages notify us when their own theme changes.
    if (AppStorage.get<boolean>('pocketPageThemeKnown') !== true) {
      WindowAppearance.apply(config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    }
  }

  onDestroy(): void {
    try { accessibility.offAnimationReduceStateChange(this.motionChanged); } catch (_) {}
    WindowAppearance.stopObservingKeyboard();
    WindowAppearance.mainWindow = null;
  }

  private route(want: Want): void {
    if (ProductCapabilities.supportsMockFixtures) {
      AppStorage.setOrCreate<boolean>('storeShowcase', true);
      const showcaseScreen = want.parameters?.showcaseScreen;
      AppStorage.setOrCreate<string>('storeShowcaseScreen', NativeUiFixture.screen(showcaseScreen));
      AppStorage.setOrCreate<boolean>('storeShowcaseProcessOpen',
        NativeUiFixture.screen(showcaseScreen) === 'process');
      const showcaseState = want.parameters?.showcaseState;
      AppStorage.setOrCreate<string>('storeShowcaseState', NativeUiFixture.state(showcaseState));
      const showcaseTheme = want.parameters?.showcaseTheme;
      AppStorage.setOrCreate<string>('storeShowcaseTheme', NativeUiFixture.theme(showcaseTheme));
      const showcaseReduceMotion = want.parameters?.showcaseReduceMotion;
      AppStorage.setOrCreate<boolean>('showcaseReduceMotion',
        showcaseReduceMotion === true || showcaseReduceMotion === 'true');
      const showcaseReduceTransparency = want.parameters?.showcaseReduceTransparency;
      // Default stays pre-effect (opaque); an explicit false opts into materials.
      AppStorage.setOrCreate<boolean>('showcaseReduceTransparency',
        !(showcaseReduceTransparency === false || showcaseReduceTransparency === 'false'));
    } else {
      // Store review activation must pass through the fixed-origin credential
      // check in Index; exported Want parameters cannot open the showcase.
      AppStorage.setOrCreate<boolean>('storeShowcase', false);
    }
    const route = want.parameters?.pocketRoute;
    if (typeof route === 'string' && ['workspace', 'overview', 'settings'].includes(route)) {
      AppStorage.setOrCreate<string>('requestedPocketRoute', route);
    }
    let sessionId: Object | undefined = want.parameters?.sessionId;
    const data = want.parameters?.data;
    if (typeof sessionId !== 'string' && typeof data === 'string' && data.length <= 4096) {
      try { sessionId = (JSON.parse(data) as Record<string, Object>).sessionId; } catch (_) {}
    } else if (typeof sessionId !== 'string' && data !== undefined && typeof data === 'object' && data !== null) {
      sessionId = (data as Record<string, Object>).sessionId;
    }
    if (typeof sessionId === 'string' && /^[A-Za-z0-9_-]{1,160}$/.test(sessionId)) {
      AppStorage.setOrCreate<string>('requestedSession', sessionId);
    }
  }
}
