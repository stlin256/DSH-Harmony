/**
 * Single source of truth for the native shell's visual primitives.
 *
 * Product UI code should express intent (base, raised, secondary, hitTarget)
 * instead of inventing new literal colors, radii or control dimensions.
 */
export class NativeDesign {
  static base(dark: boolean): string {
    return dark ? '#151517' : '#FFFFFF';
  }

  static subtleSurface(dark: boolean): string {
    return dark ? '#1D1E21' : '#F7F8FA';
  }

  static raised(dark: boolean): string {
    return dark ? '#242527' : '#FFFFFF';
  }

  static overlay(dark: boolean): string {
    return dark ? '#292A2E' : '#FFFFFF';
  }

  static field(dark: boolean): string {
    return dark ? '#313236' : '#F5F6F7';
  }

  static selection(dark: boolean): string {
    return dark ? '#353638' : '#EBEEF2';
  }

  static selectedSurface(dark: boolean): string {
    return dark ? '#30343B' : '#EEF3FF';
  }

  static border(dark: boolean): string {
    return dark ? '#414247' : '#DDE0E5';
  }

  static divider(dark: boolean): string {
    return dark ? '#303136' : '#E9EAEC';
  }

  static textPrimary(dark: boolean): string {
    return dark ? '#F6F7F9' : '#17181B';
  }

  static textSecondary(dark: boolean): string {
    return dark ? '#B5B8BD' : '#61666B';
  }

  static textTertiary(dark: boolean): string {
    return dark ? '#8F9298' : '#777A80';
  }

  static textInverse(dark: boolean): string {
    return dark ? '#17181B' : '#FFFFFF';
  }

  static accent(dark: boolean): string {
    return dark ? '#8AB4FF' : '#3964FE';
  }

  static accentStrong(dark: boolean): string {
    return dark ? '#679EFE' : '#3964FE';
  }

  static accentSurface(dark: boolean): string {
    return dark ? '#202D45' : '#EAF0FF';
  }

  static success(dark: boolean): string {
    return dark ? '#7DE3A2' : '#187940';
  }

  static successSurface(dark: boolean): string {
    return dark ? '#173423' : '#ECF8F0';
  }

  static warning(dark: boolean): string {
    return dark ? '#F0B84A' : '#8A5A00';
  }

  static warningSurface(dark: boolean): string {
    return dark ? '#3C3426' : '#FFF7E7';
  }

  static danger(dark: boolean): string {
    return dark ? '#FF9C9C' : '#B3261E';
  }

  static dangerSurface(dark: boolean): string {
    return dark ? '#3B2022' : '#FDEEEE';
  }

  static mask(dark: boolean): string {
    return dark ? '#66000000' : '#3D000000';
  }

  static blurScrimTop(dark: boolean): string {
    return dark ? '#001D1E20' : '#00FFFFFF';
  }

  static blurScrimMid(dark: boolean): string {
    return dark ? '#241D1E20' : '#24FFFFFF';
  }

  static blurScrimLower(dark: boolean): string {
    return dark ? '#661F2022' : '#70FFFFFF';
  }

  static blurScrimBottom(dark: boolean): string {
    return dark ? '#B3232528' : '#B8FFFFFF';
  }

  static iconTone(color: string, dark: boolean): string {
    const value = color.toUpperCase();
    if (['#F9FAFB', '#F6F7F9', '#0F1115', '#17181B', '#202124', '#24262A',
      '#25262A', '#33353A', '#E7E7E9', '#F4F4F5'].includes(value)) {
      return NativeDesign.textPrimary(dark);
    }
    if (['#CFD3D6', '#B5B8BD', '#A4A7AD', '#A1A1AA', '#61666B', '#8A8D91',
      '#93969B', '#777A80'].includes(value)) {
      return NativeDesign.textSecondary(dark);
    }
    if (['#8AB4FF', '#679EFE', '#3964FE', '#315ECA'].includes(value)) {
      return NativeDesign.accent(dark);
    }
    if (['#7DE3A2', '#9BE2B0', '#187940'].includes(value)) {
      return NativeDesign.success(dark);
    }
    if (['#F0B84A', '#A56A00', '#8A5A00'].includes(value)) {
      return NativeDesign.warning(dark);
    }
    if (['#FF9C9C', '#FFB1B1', '#FF9393', '#D55E5E', '#B3261E'].includes(value)) {
      return NativeDesign.danger(dark);
    }
    return color;
  }

  static hitTarget: number = 44;
  static compactHitTarget: number = 36;
  static compactControl: number = 32;
  static compactChip: number = 30;
  static visualIconContainer: number = 36;
  static compactRow: number = 44;
  static standardRow: number = 48;
  static pickerRow: number = 46;
  static headerHeight: number = 52;

  static radiusControl: number = 10;
  static radiusCompact: number = 8;
  static radiusRow: number = 12;
  static radiusGroup: number = 16;
  static radiusSurface: number = 24;

  static spaceXS: number = 4;
  static spaceS: number = 8;
  static spaceM: number = 12;
  static spaceL: number = 16;
  static pageInset: number = 16;
  static cardPadding: number = 14;

  static fontPageTitle: number = 20;
  static fontHeaderTitle: number = 18;
  static fontSection: number = 12;
  static fontBody: number = 14;
  static fontCompact: number = 13;
  static fontCaption: number = 11;
  static fontMicro: number = 10;
}
