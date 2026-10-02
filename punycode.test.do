import { BlobReader } from "std/blob"
import { Assert } from "std/assert"

import {
  PunycodeError,
  decodePunycodeLabel,
  encodePunycodeLabel,
  hostnameToAscii,
  hostnameToUnicode,
} from "./index"

function assertErrorKind(result: Result<string, PunycodeError>, kind: string): none {
  case result {
    _: Success -> Assert.fail("expected Punycode operation to fail")
    f: Failure -> Assert.equal(f.error.kind, kind)
  }
}

export function testPunycodeRfcVectors(): none {
  Assert.equal(encodePunycodeLabel("bücher")!, "bcher-kva")
  Assert.equal(decodePunycodeLabel("bcher-kva")!, "bücher")
  Assert.equal(encodePunycodeLabel("mañana")!, "maana-pta")
  Assert.equal(decodePunycodeLabel("maana-pta")!, "mañana")
  Assert.equal(encodePunycodeLabel("😀")!, "e28h")
  Assert.equal(decodePunycodeLabel("e28h")!, "😀")
}

export function testPunycodePreservesBasicCodepointsAndCase(): none {
  Assert.equal(encodePunycodeLabel("abc")!, "abc-")
  Assert.equal(decodePunycodeLabel("abc-")!, "abc")
  Assert.equal(encodePunycodeLabel("Bücher")!, "Bcher-kva")
  Assert.equal(decodePunycodeLabel("Bcher-kva")!, "Bücher")
}

export function testPunycodeRoundTripsMixedAndAstralText(): none {
  labels := readonly ["", "hello", "☃-⌘", "Go-例", "😀rocket🚀"]
  for label of labels {
    encoded := encodePunycodeLabel(label)!
    Assert.equal(decodePunycodeLabel(encoded)!, label)
  }
}

export function testHostnameConversionHandlesLabelsAndTrailingDots(): none {
  Assert.equal(hostnameToAscii("例え.テスト")!, "xn--r8jz45g.xn--zckzah")
  Assert.equal(hostnameToUnicode("xn--r8jz45g.xn--zckzah")!, "例え.テスト")
  Assert.equal(hostnameToAscii("www.例え..")!, "www.xn--r8jz45g..")
  Assert.equal(hostnameToUnicode("www.xn--r8jz45g..")!, "www.例え..")
}

export function testHostnameToAsciiPreservesAsciiAndIpLiterals(): none {
  Assert.equal(hostnameToAscii("Example.COM")!, "Example.COM")
  Assert.equal(hostnameToAscii("xn--r8jz45g.example")!, "xn--r8jz45g.example")
  Assert.equal(hostnameToAscii("127.0.0.1")!, "127.0.0.1")
  Assert.equal(hostnameToAscii("[2001:db8::1]")!, "[2001:db8::1]")
  Assert.equal(hostnameToUnicode("[2001:db8::1]")!, "[2001:db8::1]")
}

export function testHostnameToUnicodeAcceptsCaseInsensitivePrefix(): none {
  Assert.equal(hostnameToUnicode("XN--R8JZ45G.example")!, "例え.example")
}

export function testPunycodeRejectsMalformedUtf8DigitsAndOverflow(): none {
  malformedUtf8 := BlobReader([255]).readString(1L)
  assertErrorKind(encodePunycodeLabel(malformedUtf8), "invalid-utf8")
  assertErrorKind(decodePunycodeLabel("abc$"), "invalid-punycode")
  assertErrorKind(decodePunycodeLabel("999999999999999999999999"), "overflow")
}
