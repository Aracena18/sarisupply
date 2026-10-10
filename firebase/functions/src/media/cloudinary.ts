import { createHash } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const IMAGE_GRACE_MS = 24 * 60 * 60 * 1000;
export const IMAGE_TRANSFORMATION = 'c_limit,h_1024,w_1024,q_80,fl_strip_profile';
export const IMAGE_EAGER = 'c_limit,h_160,w_160,q_80,f_webp|c_limit,h_640,w_640,q_80,f_webp';
export interface ProductImage {
  assetId: string; publicId: string; version: number;
  secureUrl: string; thumbnailUrl: string;
}
export interface MediaProvider {
  readonly cloudName: string;
  parameters(publicId: string, timestamp: number): Record<string, string>;
  usage(): Promise<number>;
  image(publicId: string): Promise<ProductImage>;
  destroy(publicId: string): Promise<void>;
}

export function cloudinarySignature(parameters: Record<string, string>, secret: string): string {
  const data = Object.keys(parameters).sort().map(key => `${key}=${parameters[key]}`).join('&');
  return createHash('sha256').update(data + secret).digest('hex');
}

export class Cloudinary implements MediaProvider {
  private usageCache?: { at: number; credits: number };
  constructor(readonly cloudName: string, private readonly apiKey: string,
    private readonly secret: string, private readonly preset: string,
    private readonly fetcher: typeof fetch = fetch) {}

  parameters(publicId: string, timestamp: number) {
    const parameters = { public_id: publicId, timestamp: String(timestamp), upload_preset: this.preset,
      overwrite: 'false', allowed_formats: 'jpg,png,webp', transformation: IMAGE_TRANSFORMATION,
      eager: IMAGE_EAGER, backup: 'false', type: 'upload' };
    return { ...parameters, signature: cloudinarySignature(parameters, this.secret), api_key: this.apiKey };
  }

  private async admin(path: string): Promise<Record<string, any>> {
    let response: Response;
    try {
      response = await this.fetcher(`https://api.cloudinary.com/v1_1/${this.cloudName}/${path}`, {
        headers: { authorization: `Basic ${Buffer.from(`${this.apiKey}:${this.secret}`).toString('base64')}` },
        signal: AbortSignal.timeout(15000),
      });
    } catch { throw new HttpsError('unavailable', 'Photo service unavailable; try again'); }
    if (response.status === 404) throw new HttpsError('not-found', 'Photo upload not found; try again');
    if (!response.ok) throw new HttpsError('unavailable', 'Photo service unavailable; try again');
    try { return await response.json() as Record<string, any>; }
    catch { throw new HttpsError('unavailable', 'Invalid photo service response'); }
  }

  async usage(): Promise<number> {
    if (this.usageCache && Date.now() - this.usageCache.at < 15 * 60 * 1000) return this.usageCache.credits;
    const response = await this.admin('usage');
    const credits = response.credits?.usage;
    if (typeof credits !== 'number' || !Number.isFinite(credits) || credits < 0) {
      throw new HttpsError('unavailable', 'Photo usage could not be checked');
    }
    this.usageCache = { at: Date.now(), credits };
    return credits;
  }

  async image(publicId: string): Promise<ProductImage> {
    const asset = await this.admin(`resources/image/upload/${encodeURIComponent(publicId)}?image_metadata=true`);
    if (asset.public_id !== publicId || asset.resource_type !== 'image' || asset.type !== 'upload' ||
        !['jpg', 'png', 'webp'].includes(asset.format) || typeof asset.asset_id !== 'string' || !asset.asset_id ||
        !Number.isSafeInteger(asset.version) || asset.version < 1 ||
        !Number.isSafeInteger(asset.bytes) || asset.bytes < 1 || asset.bytes > MAX_IMAGE_BYTES ||
        !Number.isSafeInteger(asset.width) || asset.width < 1 || asset.width > 1024 ||
        !Number.isSafeInteger(asset.height) || asset.height < 1 || asset.height > 1024 ||
        (asset.pages !== undefined && asset.pages !== 1) ||
        (asset.image_metadata?.['Frame Count'] !== undefined && Number(asset.image_metadata['Frame Count']) > 1)) {
      throw new HttpsError('invalid-argument', 'Use a static JPEG, PNG or WebP photo up to 5 MiB');
    }
    const root = `https://res.cloudinary.com/${this.cloudName}/image/upload`;
    const id = publicId.split('/').map(encodeURIComponent).join('/');
    const variant = (size: number) => `${root}/c_limit,h_${size},w_${size},q_80,f_webp/v${asset.version}/${id}.webp`;
    return { assetId: asset.asset_id, publicId, version: asset.version,
      secureUrl: variant(640), thumbnailUrl: variant(160) };
  }

  async destroy(publicId: string): Promise<void> {
    const parameters = { public_id: publicId, timestamp: String(Math.floor(Date.now() / 1000)), invalidate: 'true' };
    let response: Response;
    try {
      response = await this.fetcher(`https://api.cloudinary.com/v1_1/${this.cloudName}/image/destroy`, {
        method: 'POST', body: new URLSearchParams({ ...parameters, api_key: this.apiKey,
          signature: cloudinarySignature(parameters, this.secret) }), signal: AbortSignal.timeout(15000),
      });
    } catch { throw new HttpsError('unavailable', 'Photo cleanup unavailable'); }
    if (!response.ok) throw new HttpsError('unavailable', 'Photo cleanup unavailable');
    const result = await response.json() as { result?: string };
    if (result.result !== 'ok' && result.result !== 'not found') throw new HttpsError('unavailable', 'Photo cleanup unavailable');
  }
}

export function mediaFromEnvironment(env: Record<string, string | undefined>): MediaProvider | undefined {
  const cloudName = env.CLOUDINARY_CLOUD_NAME?.trim();
  if (!cloudName) {
    if (env.CLOUDINARY_UPLOADS_ENABLED === 'true') throw Error('Missing Cloudinary server settings');
    return undefined;
  }
  const key = env.CLOUDINARY_API_KEY?.trim(), secret = env.CLOUDINARY_API_SECRET?.trim(), preset = env.CLOUDINARY_UPLOAD_PRESET?.trim();
  if (!/^[A-Za-z0-9_-]+$/.test(cloudName) || !key || !secret || !preset) throw Error('Invalid Cloudinary server settings');
  return new Cloudinary(cloudName, key, secret, preset);
}
