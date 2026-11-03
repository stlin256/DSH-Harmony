/** Self-signed build: the development Profile includes the FIDO2 ACL. */
export class ProductCapabilities {
  static readonly appDisplayName: string = 'DSH Harmony';
  static readonly supportsPasskey: boolean = true;
  static readonly supportsMockFixtures: boolean = false;
  static readonly supportsStoreReview: boolean = false;
  static readonly storeReviewOrigin: string = '';
  static readonly storeReviewCredentialSha256: string = '';
}
