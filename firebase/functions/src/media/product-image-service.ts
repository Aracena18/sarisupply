import { createHash } from 'node:crypto';
import { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';
import { IMAGE_GRACE_MS, MAX_IMAGE_BYTES, MediaProvider, ProductImage } from './cloudinary';

type Input = Record<string, unknown>;
export const uploadKey = (merchantId: string, uploadId: string) =>
  createHash('sha256').update(JSON.stringify([merchantId, uploadId])).digest('hex');
const authorization = (db: Firestore, tx: Transaction) =>
  new AuthorizationService(async path => (await tx.get(db.doc(path))).data() ?? null);

export interface ImageChange { action: 'keep' | 'set' | 'remove'; uploadId?: string; url?: string }
export function imageChangeInput(input: Input): ImageChange {
  if (input.imageChange === undefined) return { action: 'keep' };
  const value = input.imageChange as Input;
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpsError('invalid-argument', 'Invalid photo action');
  if (value.action === 'set') return { action: 'set', uploadId: requireDocumentId(value.uploadId, 'upload ID') };
  if (value.action === 'keep' || value.action === 'remove') return { action: value.action };
  // Existing preset/custom URL controls remain supported without acquiring managed ownership.
  if (value.action === 'url') return { action: 'set', url: externalImageUrl(value.url) };
  throw new HttpsError('invalid-argument', 'Invalid photo action');
}

export function externalImageUrl(raw: unknown): string {
  if (typeof raw !== 'string' || raw.length > 2048) throw new HttpsError('invalid-argument', 'Invalid photo URL');
  let url: URL;
  try { url = new URL(raw); } catch { throw new HttpsError('invalid-argument', 'Use an HTTPS photo URL'); }
  if (url.protocol !== 'https:' || url.username || url.password) throw new HttpsError('invalid-argument', 'Use an HTTPS photo URL');
  return url.href;
}

export class ProductImageService {
  constructor(private readonly db: Firestore, private readonly environment: 'dev' | 'prod',
    private readonly provider?: MediaProvider, private readonly enabled = false,
    private readonly clock: () => number = Date.now) {}

  async prepare(request: AuthRequest, input: Input) {
    const uid = requireHuman(request);
    const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
    const productId = requireDocumentId(input.productId, 'product ID');
    const uploadId = requireDocumentId(input.uploadId, 'upload ID');
    const bytes = input.bytes;
    if (!Number.isSafeInteger(bytes) || (bytes as number) < 1 || (bytes as number) > MAX_IMAGE_BYTES ||
        !['jpg', 'png', 'webp'].includes(String(input.format))) throw new HttpsError('invalid-argument', 'Use a JPEG, PNG or WebP photo up to 5 MiB');
    await new AuthorizationService(async path => (await this.db.doc(path).get()).data() ?? null).requireOwner(uid, merchantId);
    const setting = await this.db.doc('mediaSettings/cloudinary').get();
    if (!this.provider || !this.enabled || setting.get('uploadsEnabled') === false) {
      throw new HttpsError('failed-precondition', 'Photo uploads are unavailable. Existing photos are retained.');
    }
    const credits = await this.provider.usage();
    if (credits >= 20) throw new HttpsError('resource-exhausted', 'Photo allowance reached. Existing photos are retained.');
    const now = this.clock();
    const key = uploadKey(merchantId, uploadId);
    const publicId = `sarisupply/${this.environment}/${uploadKey(merchantId, productId)}/${key}`;
    const fingerprint = createHash('sha256').update(JSON.stringify([uid, productId, bytes, input.format])).digest('hex');
    const ref = this.db.doc(`productImageUploads/${key}`);
    await this.db.runTransaction(async tx => {
      await authorization(this.db, tx).requireOwner(uid, merchantId);
      const currentSetting = await tx.get(this.db.doc('mediaSettings/cloudinary'));
      if (currentSetting.get('uploadsEnabled') === false) {
        throw new HttpsError('failed-precondition', 'Photo uploads are unavailable. Existing photos are retained.');
      }
      const upload = await tx.get(ref);
      if (upload.exists) {
        if (upload.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists', 'Upload ID has another photo');
        if (!['pending', 'verified'].includes(upload.get('status')) || upload.get('cleanupAfter') <= now) {
          throw new HttpsError('failed-precondition', 'Photo draft expired; choose the photo again');
        }
        return;
      }
      const day = new Date(now).toISOString().slice(0, 10);
      const globalRef = this.db.doc(`mediaDaily/${day}`);
      const merchantRef = this.db.doc(`merchants/${merchantId}/mediaDaily/${day}`);
      const global = await tx.get(globalRef), merchant = await tx.get(merchantRef);
      const globalCount = global.get('count') ?? 0, merchantCount = merchant.get('count') ?? 0;
      // Reserve conservatively for unreported uploads within the cached usage window.
      const windowRef = this.db.doc(`mediaDaily/window-${Math.floor(now / (15 * 60 * 1000))}`);
      const window = await tx.get(windowRef);
      const pendingCost = (window.get('count') ?? 0) * 0.02;
      if (globalCount >= 200 || merchantCount >= 50 || credits + pendingCost + 0.02 >= 20) {
        throw new HttpsError('resource-exhausted', 'Photo allowance reached. Try again later.');
      }
      tx.set(globalRef, { count: globalCount + 1 });
      tx.set(merchantRef, { count: merchantCount + 1 });
      tx.set(windowRef, { count: (window.get('count') ?? 0) + 1 });
      tx.create(ref, { merchantId, productId, uploadId, publicId, fingerprint, actor: uid,
        status: 'pending', createdAt: now, cleanupAfter: now + IMAGE_GRACE_MS });
    });
    if (credits >= 17.5) console.warn('Cloudinary product-photo usage warning', { credits });
    return { uploadId, publicId, uploadUrl: `https://api.cloudinary.com/v1_1/${this.provider.cloudName}/image/upload`,
      parameters: this.provider.parameters(publicId, Math.floor(now / 1000)),
      warning: credits >= 17.5 ? 'Photo allowance is running low' : null };
  }

  async complete(request: AuthRequest, input: Input) {
    const uid = requireHuman(request);
    const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
    const productId = requireDocumentId(input.productId, 'product ID');
    const uploadId = requireDocumentId(input.uploadId, 'upload ID');
    if (!this.provider) throw new HttpsError('unavailable', 'Photo service unavailable');
    const ref = this.db.doc(`productImageUploads/${uploadKey(merchantId, uploadId)}`);
    const read = async (tx: Transaction) => {
      await authorization(this.db, tx).requireOwner(uid, merchantId);
      const upload = await tx.get(ref);
      if (!upload.exists || upload.get('actor') !== uid || upload.get('productId') !== productId ||
          !['pending', 'verified'].includes(upload.get('status')) || upload.get('cleanupAfter') <= this.clock()) {
        throw new HttpsError('failed-precondition', 'Photo draft unavailable; choose the photo again');
      }
      return upload;
    };
    const upload = await this.db.runTransaction(read);
    // Read authoritative provider metadata, never trust the client's upload response.
    const image = await this.provider.image(upload.get('publicId'));
    await this.db.runTransaction(async tx => {
      await read(tx);
      tx.update(ref, { status: 'verified', image });
    });
    return { uploadId, image };
  }
}

export async function resolveImageChange(db: Firestore, tx: Transaction, merchantId: string,
  productId: string, uid: string, change: ImageChange,
  existing?: { imageUrl?: string; image?: ProductImage }, legacyUrl?: string) {
  if (change.action === 'keep') return { imageUrl: existing?.imageUrl ?? legacyUrl, image: existing?.image };
  if (change.action === 'remove') return {};
  if (change.url) return { imageUrl: change.url, ...(change.url === existing?.imageUrl ? { image: existing.image } : {}) };
  const ref = db.doc(`productImageUploads/${uploadKey(merchantId, change.uploadId!)}`);
  const upload = await tx.get(ref);
  if (upload.get('merchantId') !== merchantId || upload.get('productId') !== productId || upload.get('actor') !== uid ||
      upload.get('status') !== 'verified' || upload.get('cleanupAfter') <= Date.now() || !upload.get('image')) {
    throw new HttpsError('failed-precondition', 'Photo draft unavailable; choose the photo again');
  }
  const image = upload.get('image') as ProductImage;
  return { imageUrl: image.secureUrl, image };
}

// Call only after all transaction reads. Claiming during cleanup prevents concurrent attachment.
export function commitImageChange(db: Firestore, tx: Transaction, merchantId: string, productId: string,
  change: ImageChange, before?: ProductImage, after?: ProductImage) {
  if (after && change.uploadId) tx.update(db.doc(`productImageUploads/${uploadKey(merchantId, change.uploadId)}`), {
    status: 'attached', cleanupAfter: null,
  });
  if (before && before.assetId !== after?.assetId) {
    tx.set(db.doc(`productImageUploads/${before.publicId.split('/').at(-1)}`), {
      merchantId, productId, publicId: before.publicId, status: 'superseded', cleanupAfter: Date.now() + IMAGE_GRACE_MS,
    }, { merge: true });
  }
}

export async function cleanupProductImages(db: Firestore, provider: MediaProvider, now = Date.now(), limit = 50) {
  const page = await db.collection('productImageUploads').where('cleanupAfter', '<=', now).orderBy('cleanupAfter').limit(limit).get();
  let deleted = 0, retained = 0, failed = 0;
  for (const candidate of page.docs) {
    const claimed = await db.runTransaction(async tx => {
      const current = await tx.get(candidate.ref);
      if (!current.exists || typeof current.get('cleanupAfter') !== 'number' || current.get('cleanupAfter') > now ||
          !['pending', 'verified', 'superseded', 'deleting'].includes(current.get('status'))) return null;
      const merchantId = requireDocumentId(current.get('merchantId'), 'merchant ID');
      const productId = requireDocumentId(current.get('productId'), 'product ID');
      const publicId = current.get('publicId') as string;
      const expectedSuffix = uploadKey(merchantId, productId);
      if (!/^sarisupply\/(dev|prod)\//.test(publicId) || !publicId.includes(`/${expectedSuffix}/`) || publicId.split('/').at(-1) !== candidate.id) {
        throw new HttpsError('data-loss', 'Invalid photo cleanup scope');
      }
      const product = await tx.get(db.doc(`merchants/${merchantId}/products/${productId}`));
      if (product.get('image')?.publicId === publicId) {
        tx.update(candidate.ref, { status: 'attached', cleanupAfter: null });
        return null;
      }
      tx.update(candidate.ref, { status: 'deleting' });
      return publicId;
    }).catch(() => { failed++; return null; });
    if (!claimed) { retained++; continue; }
    try {
      await provider.destroy(claimed);
      await candidate.ref.update({ status: 'deleted', cleanupAfter: null, image: null });
      deleted++;
    } catch { failed++; }
  }
  return { scanned: page.size, deleted, retained, failed, hasMore: page.size === limit };
}
