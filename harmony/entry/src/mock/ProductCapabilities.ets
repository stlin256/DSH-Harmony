/** Deterministic frontend test build. It never connects to a real Host by default. */
export class ProductCapabilities {
  static readonly supportsPasskey: boolean = true;
  static readonly supportsMockFixtures: boolean = true;
}
