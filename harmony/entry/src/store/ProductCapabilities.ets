/** AppGallery build: ordinary store Profiles cannot claim the FIDO2 ACL here. */
export class ProductCapabilities {
  static readonly appDisplayName: string = 'DSH Mobile';
  static readonly supportsPasskey: boolean = false;
  static readonly supportsMockFixtures: boolean = false;
  static readonly supportsStoreReview: boolean = true;
  static readonly storeReviewOrigin: string = 'https://dsh.dshoh.com';
  static readonly storeReviewCredentialSha256: string =
    '121101C4D6652D089DBED9904A2D3C07E9C4DC28503B92027178493696ECC51F';
}
