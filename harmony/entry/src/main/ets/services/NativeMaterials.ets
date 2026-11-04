import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';

/** Every surface that can adopt the HarmonyOS immersive system material. */
export class NativeMaterialSurface {
  static readonly BOTTOM_DOCK: string = 'bottom-dock';
  static readonly TASK_DOCK: string = 'task-dock';
}

export class NativeMaterialSpec {
  id: string = '';
  label: string = '';
  /** uiMaterial.ImmersiveStyle numeric value; resolved only behind the API-26 gate. */
  style: number = 2;
  lightEffect: boolean = false;
  interactive: boolean = false;
  applyShadow: boolean = false;
}

function materialSpec(id: string, label: string, style: number, lightEffect: boolean,
  interactive: boolean): NativeMaterialSpec {
  const spec = new NativeMaterialSpec();
  spec.id = id; spec.label = label; spec.style = style;
  spec.lightEffect = lightEffect; spec.interactive = interactive;
  spec.applyShadow = false;
  return spec;
}

/**
 * Maintained component list for the reduce-transparency toggle. Add a spec here
 * and attach the matching modifier in the owning component; the toggle then
 * governs every surface through one gate.
 */
export const NATIVE_MATERIAL_SURFACES: NativeMaterialSpec[] = [
  materialSpec(NativeMaterialSurface.BOTTOM_DOCK, '输入 Dock', 0, true, false),
  materialSpec(NativeMaterialSurface.TASK_DOCK, '任务计划 Dock', 1, true, true)
];

export class NativeMaterials {
  static supported(): boolean {
    return deviceInfo.sdkApiVersion >= 26 && canIUse('SystemCapability.ArkUI.ArkUI.Full');
  }

  static reducedMotion(): boolean {
    return AppStorage.get<boolean>('nativeUserReduceMotion') === true ||
      AppStorage.get<boolean>('nativeSystemReduceMotion') === true;
  }

  /** Single gate for the whole material list and the reduce-transparency toggle. */
  static enabled(): boolean {
    if (!NativeMaterials.supported()) return false;
    if (AppStorage.get<boolean>('nativeReduceTransparency') === true) return false;
    if (AppStorage.get<boolean>('nativePowerSaving') === true) return false;
    if (AppStorage.get<boolean>('nativeAppActive') === false) return false;
    try { return uiMaterial.getMaterialInfo().state !== uiMaterial.MaterialState.DISABLE; }
    catch (_) { return false; }
  }

  static spec(id: string): NativeMaterialSpec | null {
    const found = NATIVE_MATERIAL_SURFACES.find((spec: NativeMaterialSpec): boolean => spec.id === id);
    return found || null;
  }

  static style(value: number): uiMaterial.ImmersiveStyle {
    if (value === 0) return uiMaterial.ImmersiveStyle.ULTRA_THIN;
    if (value === 1) return uiMaterial.ImmersiveStyle.THIN;
    if (value === 3) return uiMaterial.ImmersiveStyle.THICK;
    if (value === 4) return uiMaterial.ImmersiveStyle.ULTRA_THICK;
    return uiMaterial.ImmersiveStyle.REGULAR;
  }

  /** Resolves the material only behind the API-26 gate; undefined means no attribute. */
  static materialFor(id: string): uiMaterial.Material | undefined {
    if (!NativeMaterials.supported()) return undefined;
    if (!NativeMaterials.enabled()) return uiMaterial.Material.empty;
    try {
      if (!uiMaterial.isImmersiveMaterialSupported()) return uiMaterial.Material.empty;
      const spec = NativeMaterials.spec(id);
      if (!spec) return uiMaterial.Material.empty;
      const quiet = NativeMaterials.reducedMotion();
      const options: uiMaterial.ImmersiveOptions = {
        style: NativeMaterials.style(spec.style),
        interactive: spec.interactive && !quiet,
        applyShadow: spec.applyShadow,
        lightEffect: spec.lightEffect && !quiet ? { color: Color.White } : null
      };
      return new uiMaterial.ImmersiveMaterial(options);
    } catch (_) {
      return uiMaterial.Material.empty;
    }
  }
}

export class NativeMaterialColumnModifier implements AttributeModifier<ColumnAttribute> {
  private id: string = '';
  constructor(id: string, _revision: number = 0) { this.id = id; }
  applyNormalAttribute(instance: ColumnAttribute): void {
    if (deviceInfo.sdkApiVersion < 26) return;
    const material = NativeMaterials.materialFor(this.id);
    if (material !== undefined) instance.systemMaterial(material);
  }
}

export class NativeMaterialRowModifier implements AttributeModifier<RowAttribute> {
  private id: string = '';
  constructor(id: string, _revision: number = 0) { this.id = id; }
  applyNormalAttribute(instance: RowAttribute): void {
    if (deviceInfo.sdkApiVersion < 26) return;
    const material = NativeMaterials.materialFor(this.id);
    if (material !== undefined) instance.systemMaterial(material);
  }
}

export class NativeMaterialStackModifier implements AttributeModifier<StackAttribute> {
  private id: string = '';
  constructor(id: string, _revision: number = 0) { this.id = id; }
  applyNormalAttribute(instance: StackAttribute): void {
    if (deviceInfo.sdkApiVersion < 26) return;
    const material = NativeMaterials.materialFor(this.id);
    if (material !== undefined) instance.systemMaterial(material);
  }
}
