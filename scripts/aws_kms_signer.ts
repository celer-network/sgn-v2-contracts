// An ethers v6 Signer backed by an AWS KMS asymmetric ECC_SECG_P256K1 key, i.e. the kind of key
// an SGN validator signer uses (see sgn.toml `eth_signer_keystore = "awskms:<region>:alias/<name>"`).
//
// The repo already wires KMS into hardhat through `hardhat-signer-kms` (see the `kmsKeyId` field in
// hardhat.config.ts), but that path only works for chains that have a network entry in the config.
// This signer is standalone: give it a key id and any ethers Provider and it signs.
//
// Requires AWS credentials with `kms:GetPublicKey` and `kms:Sign` on the key, resolved the usual way
// (instance role, AWS_PROFILE, AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, ...).
import { GetPublicKeyCommand, KMSClient, SignCommand } from '@aws-sdk/client-kms';
import {
  AbstractSigner,
  Signature,
  Transaction,
  TypedDataEncoder,
  computeAddress,
  copyRequest,
  getAddress,
  getBytes,
  hashMessage,
  hexlify,
  recoverAddress,
  resolveAddress,
  resolveProperties,
  toBeHex,
  toBigInt
} from 'ethers';

import type { Provider, TransactionLike, TransactionRequest, TypedDataDomain, TypedDataField } from 'ethers';

// Order of the secp256k1 group. KMS is free to return either s or N - s, while Ethereum only accepts
// the lower of the two (EIP-2), so a "high" s has to be flipped.
const SECP256K1_N = toBigInt('0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141');

const DER_INTEGER = 0x02;
const DER_BIT_STRING = 0x03;
const DER_SEQUENCE = 0x30;

interface DerNode {
  tag: number;
  value: Uint8Array;
  next: number;
}

// Reads one DER tag-length-value node. Only the subset needed for the two structures KMS returns is
// supported: SubjectPublicKeyInfo (GetPublicKey) and ECDSA-Sig-Value (Sign).
function readDerNode(bytes: Uint8Array, offset: number): DerNode {
  if (offset + 2 > bytes.length) {
    throw new Error('malformed DER: truncated header');
  }
  const tag = bytes[offset];
  let length = bytes[offset + 1];
  let cursor = offset + 2;
  if (length & 0x80) {
    const numLengthBytes = length & 0x7f;
    length = 0;
    for (let i = 0; i < numLengthBytes; i++) {
      length = length * 256 + bytes[cursor + i];
    }
    cursor += numLengthBytes;
  }
  if (cursor + length > bytes.length) {
    throw new Error('malformed DER: truncated value');
  }
  return { tag, value: bytes.subarray(cursor, cursor + length), next: cursor + length };
}

// SubjectPublicKeyInfo ::= SEQUENCE { algorithm AlgorithmIdentifier, subjectPublicKey BIT STRING }
export function publicKeyFromDer(der: Uint8Array): string {
  const spki = readDerNode(der, 0);
  if (spki.tag !== DER_SEQUENCE) {
    throw new Error('malformed public key: expecting a SEQUENCE');
  }
  const algorithm = readDerNode(spki.value, 0);
  const subjectPublicKey = readDerNode(spki.value, algorithm.next);
  if (subjectPublicKey.tag !== DER_BIT_STRING) {
    throw new Error('malformed public key: expecting a BIT STRING');
  }
  // The leading byte of a BIT STRING counts the unused trailing bits, always 0 for a public key.
  const point = subjectPublicKey.value.subarray(1);
  if (point.length !== 65 || point[0] !== 0x04) {
    throw new Error('malformed public key: expecting an uncompressed secp256k1 point');
  }
  return hexlify(point);
}

// ECDSA-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER }
export function signatureFromDer(der: Uint8Array): { r: bigint; s: bigint } {
  const sequence = readDerNode(der, 0);
  if (sequence.tag !== DER_SEQUENCE) {
    throw new Error('malformed signature: expecting a SEQUENCE');
  }
  const rNode = readDerNode(sequence.value, 0);
  const sNode = readDerNode(sequence.value, rNode.next);
  if (rNode.tag !== DER_INTEGER || sNode.tag !== DER_INTEGER) {
    throw new Error('malformed signature: expecting two INTEGERs');
  }
  const s = toBigInt(sNode.value);
  return { r: toBigInt(rNode.value), s: s > SECP256K1_N / 2n ? SECP256K1_N - s : s };
}

export class AwsKmsSigner extends AbstractSigner {
  readonly keyId: string;
  readonly region?: string;

  private readonly kms: KMSClient;
  private cachedAddress?: string;

  // keyId is anything KMS accepts: a key id, a key ARN, `alias/<name>` or an alias ARN.
  constructor(keyId: string, provider?: null | Provider, region?: string) {
    super(provider);
    this.keyId = keyId;
    this.region = region;
    this.kms = new KMSClient(region ? { region } : {});
  }

  connect(provider: null | Provider): AwsKmsSigner {
    return new AwsKmsSigner(this.keyId, provider, this.region);
  }

  async getAddress(): Promise<string> {
    if (!this.cachedAddress) {
      const res = await this.kms.send(new GetPublicKeyCommand({ KeyId: this.keyId }));
      if (!res.PublicKey) {
        throw new Error(`kms key ${this.keyId} returned an empty public key`);
      }
      this.cachedAddress = computeAddress(publicKeyFromDer(res.PublicKey));
    }
    return this.cachedAddress;
  }

  async signDigest(digest: string): Promise<Signature> {
    const address = await this.getAddress();
    const res = await this.kms.send(
      new SignCommand({
        KeyId: this.keyId,
        Message: getBytes(digest),
        MessageType: 'DIGEST',
        SigningAlgorithm: 'ECDSA_SHA_256'
      })
    );
    if (!res.Signature) {
      throw new Error(`kms key ${this.keyId} returned an empty signature`);
    }
    const { r, s } = signatureFromDer(res.Signature);
    // KMS does not return the recovery bit, so find it by elimination.
    for (const yParity of [0, 1] as const) {
      const signature = Signature.from({ r: toBeHex(r, 32), s: toBeHex(s, 32), yParity });
      if (recoverAddress(digest, signature) === address) {
        return signature;
      }
    }
    throw new Error(`unable to recover ${address} from the signature made by kms key ${this.keyId}`);
  }

  async signTransaction(tx: TransactionRequest): Promise<string> {
    const request = copyRequest(tx);
    // Replace any Addressable or ENS name with an address
    const { to, from } = await resolveProperties({
      to: request.to ? resolveAddress(request.to, this.provider) : undefined,
      from: request.from ? resolveAddress(request.from, this.provider) : undefined
    });
    if (to != null) {
      request.to = to;
    }
    if (from != null) {
      const address = await this.getAddress();
      if (getAddress(from) !== address) {
        throw new Error(`transaction from address mismatch: ${from} is not the kms address ${address}`);
      }
      delete request.from;
    }
    const transaction = Transaction.from(request as unknown as TransactionLike<string>);
    transaction.signature = await this.signDigest(transaction.unsignedHash);
    return transaction.serialized;
  }

  async signMessage(message: string | Uint8Array): Promise<string> {
    return (await this.signDigest(hashMessage(message))).serialized;
  }

  async signTypedData(
    domain: TypedDataDomain,
    types: Record<string, Array<TypedDataField>>,
    value: Record<string, unknown>
  ): Promise<string> {
    return (await this.signDigest(TypedDataEncoder.hash(domain, types, value))).serialized;
  }
}
