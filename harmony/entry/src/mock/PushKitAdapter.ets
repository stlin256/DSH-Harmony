import { common } from '@kit.AbilityKit';

/** Mock builds never register for or exercise a real Push Kit identity. */
export class PushKitAdapter {
  static readonly supported: boolean = false;
  static async getToken(_context: common.UIAbilityContext): Promise<string> {
    throw new Error('Push Kit is disabled in the mock build');
  }
  static async deleteToken(): Promise<void> {}
}
