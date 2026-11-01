import { curves, UIContext } from '@kit.ArkUI';
import { NativeExperience } from './NativeExperience';

export type NativeMotionToken = 'press' | 'micro' | 'overlay' | 'navigation' | 'surface' | 'brand';

/**
 * Semantic motion entry point for the native shell.
 *
 * Timing is intentionally expressed as perception budgets, not network waits.
 * Reduced motion, power saving and background execution resolve directly to
 * the final state.
 */
export class NativeMotion {
  static enabled(): boolean {
    return !NativeExperience.reducedMotion() &&
      AppStorage.get<boolean>('nativePowerSaving') !== true &&
      AppStorage.get<boolean>('nativeAppActive') !== false;
  }

  static duration(token: NativeMotionToken): number {
    switch (token) {
      case 'press': return 90;
      case 'micro': return 140;
      case 'overlay': return 190;
      case 'navigation': return 220;
      case 'surface': return 260;
      case 'brand': return 560;
      default: return 190;
    }
  }

  static animate(context: UIContext, token: NativeMotionToken, action: () => void): void {
    if (!NativeMotion.enabled()) {
      action();
      return;
    }
    context.animateTo({
      duration: NativeMotion.duration(token),
      curve: Curve.FastOutSlowIn
    }, action);
  }

  static implicit(token: NativeMotionToken): AnimateParam {
    if (!NativeMotion.enabled()) return { duration: 0 };
    return { duration: NativeMotion.duration(token), curve: Curve.FastOutSlowIn };
  }

  static spring(context: UIContext, action: () => void): void {
    if (!NativeMotion.enabled()) {
      action();
      return;
    }
    context.animateTo({
      curve: curves.springMotion(0.32, 0.90, 0.25)
    }, action);
  }

  /**
   * Disclosure surfaces share one damped spring so both expansion and collapse
   * decelerate naturally. The model remains interruptible because state is the
   * destination while ArkUI owns the in-flight presentation.
   */
  static disclosure(context: UIContext, action: () => void): void {
    if (!NativeMotion.enabled()) {
      action();
      return;
    }
    context.animateTo({
      curve: curves.springMotion(0.21, 0.90, 0.22)
    }, action);
  }

  static disclosureParam(): AnimateParam {
    if (!NativeMotion.enabled()) return { duration: 0 };
    return { curve: curves.springMotion(0.21, 0.90, 0.22) };
  }

  static rowTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    return TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 5 }))
      .animation(NativeMotion.implicit('micro'));
  }

  static disclosureTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: -4 }))
      .animation(NativeMotion.disclosureParam());
  }

  /** One-shot entrance for a genuinely new structural process row. */
  static processEntranceTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 5 }))
      .animation(NativeMotion.disclosureParam());
  }

  /**
   * Workspace children unfold down from the header. Their exit retracts toward
   * the same anchor before the list closes the space.
   */
  static workspaceChildrenTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    const motion = NativeMotion.disclosureParam();
    const enter = TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: -6 }))
      .animation(motion);
    const leave = TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: -4 }))
      .animation(motion);
    return TransitionEffect.asymmetric(enter, leave);
  }

  static overlayTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    return TransitionEffect.OPACITY.combine(
      TransitionEffect.scale({ x: 0.98, y: 0.98 }))
      .animation(NativeMotion.implicit('overlay'));
  }

  static navigationTransition(direction: number = 1): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    const enterOffset = direction < 0 ? -10 : 10;
    const enter = TransitionEffect.OPACITY.combine(
      TransitionEffect.translate({ x: enterOffset }))
      .animation({ duration: NativeMotion.duration('navigation'), curve: Curve.FastOutSlowIn });
    const leave = TransitionEffect.OPACITY.combine(
      TransitionEffect.translate({ x: 0 - enterOffset })).animation({
      duration: Math.max(120, NativeMotion.duration('navigation') - 40),
      curve: Curve.FastOutSlowIn
    });
    return TransitionEffect.asymmetric(enter, leave);
  }

  static drawerTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    return TransitionEffect.OPACITY.combine(
      TransitionEffect.translate({ x: -28 }))
      .animation(NativeMotion.implicit('surface'));
  }

  static previewTransition(): TransitionEffect {
    if (!NativeMotion.enabled()) return TransitionEffect.IDENTITY;
    return TransitionEffect.OPACITY.combine(
      TransitionEffect.scale({ x: 0.97, y: 0.97 })).combine(
      TransitionEffect.translate({ y: 6 }))
      .animation(NativeMotion.implicit('surface'));
  }
}

