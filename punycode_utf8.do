import { BlobBuilder, BlobReader } from "std/blob"

import { PunycodeError, punycodeFailure } from "./punycode_error"

export function decodePunycodeUtf8(text: string): Result<int[], PunycodeError> {
  codepoints: int[] := []
  let index = 0

  while index < text.length {
    first := int(text.charAt(index))
    if first <= 127 {
      codepoints.push(first)
      index += 1
      continue
    }

    if first >= 194 && first <= 223 && index + 1 < text.length {
      second := int(text.charAt(index + 1))
      if isContinuation(second) {
        codepoints.push((first - 192) * 64 + second - 128)
        index += 2
        continue
      }
    }

    if first >= 224 && first <= 239 && index + 2 < text.length {
      second := int(text.charAt(index + 1))
      third := int(text.charAt(index + 2))
      validSecond := isContinuation(second) &&
        (first != 224 || second >= 160) &&
        (first != 237 || second <= 159)
      if validSecond && isContinuation(third) {
        codepoints.push((first - 224) * 4096 + (second - 128) * 64 + third - 128)
        index += 3
        continue
      }
    }

    if first >= 240 && first <= 244 && index + 3 < text.length {
      second := int(text.charAt(index + 1))
      third := int(text.charAt(index + 2))
      fourth := int(text.charAt(index + 3))
      validSecond := isContinuation(second) &&
        (first != 240 || second >= 144) &&
        (first != 244 || second <= 143)
      if validSecond && isContinuation(third) && isContinuation(fourth) {
        codepoints.push(
          (first - 240) * 262144 + (second - 128) * 4096 +
          (third - 128) * 64 + fourth - 128,
        )
        index += 4
        continue
      }
    }

    return punycodeFailure<int[]>("invalid-utf8", index, "Invalid UTF-8 at byte ${index}")
  }

  return Success { value: codepoints }
}

export function encodePunycodeUtf8(codepoints: int[]): Result<string, PunycodeError> {
  builder := BlobBuilder()
  for codepoint of codepoints {
    if codepoint < 0 || codepoint > 1114111 || (codepoint >= 55296 && codepoint <= 57343) {
      return punycodeFailure<string>("invalid-punycode", 0, "Invalid Unicode code point")
    }
    if codepoint <= 127 {
      builder.writeByte(byte(codepoint))
    } else if codepoint <= 2047 {
      builder.writeByte(byte(192 + codepoint \ 64))
      builder.writeByte(byte(128 + codepoint % 64))
    } else if codepoint <= 65535 {
      builder.writeByte(byte(224 + codepoint \ 4096))
      builder.writeByte(byte(128 + (codepoint \ 64) % 64))
      builder.writeByte(byte(128 + codepoint % 64))
    } else {
      builder.writeByte(byte(240 + codepoint \ 262144))
      builder.writeByte(byte(128 + (codepoint \ 4096) % 64))
      builder.writeByte(byte(128 + (codepoint \ 64) % 64))
      builder.writeByte(byte(128 + codepoint % 64))
    }
  }
  bytes := builder.build()
  reader := BlobReader(bytes)
  return Success { value: reader.readString(reader.length()) }
}

function isContinuation(value: int): bool => value >= 128 && value <= 191
