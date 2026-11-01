export class UiModeResolution {
  mode: string = 'native';
  shouldMigrate: boolean = false;
  shouldPersist: boolean = false;
}

export class UiModePreference {
  static readonly MODE_KEY: string = 'uiMode';
  static readonly MIGRATED_KEY: string = 'uiModeDefaultMigratedV2';

  static valid(value: string): boolean {
    return value === 'native';
  }

  static resolve(savedMode: string, migrated: boolean): UiModeResolution {
    const resolution = new UiModeResolution();
    resolution.mode = 'native';
    resolution.shouldMigrate = !migrated;
    resolution.shouldPersist = !migrated || !UiModePreference.valid(savedMode);
    return resolution;
  }
}

