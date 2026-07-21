import { Assert } from "std/assert"
import { parseAuthority, parsePath, parseQueryParams } from "./index"

function isFailure<T, E>(result: Result<T, E>): bool {
  return case result {
    _: Success -> false,
    _: Failure -> true
  }
}

export function testParseEmptyPathHasNoSegments(): none {
  path := try! parsePath("")

  Assert.isFalse(path.absolute)
  Assert.isTrue(path.isEmpty())
  Assert.equal(path.segmentCount(), 0)
}

export function testParsePathPreservesEmptySegments(): none {
  path := try! parsePath("/api//v1/")

  Assert.isTrue(path.absolute)
  Assert.equal(path.segmentCount(), 4)
  Assert.equal(path.segment(0), "api")
  Assert.equal(path.segment(1), "")
  Assert.equal(path.segment(2), "v1")
  Assert.equal(path.segment(3), "")
}

export function testParseAbsoluteRootPathHasOnlyTrailingEmptySegment(): none {
  path := try! parsePath("/")

  Assert.isTrue(path.absolute)
  Assert.equal(path.segmentCount(), 1)
  Assert.equal(path.segment(0), "")
}

export function testParsePathDecodesPercentEncodingWithoutTreatingPlusAsSpace(): none {
  path := try! parsePath("/hello%20world/a+b/%2F")

  Assert.equal(path.segment(0), "hello world")
  Assert.equal(path.segment(1), "a+b")
  Assert.equal(path.segment(2), "/")
}

export function testParsePathRejectsMalformedPercentEncoding(): none {
  Assert.isTrue(isFailure(parsePath("/bad/%")))
  Assert.isTrue(isFailure(parsePath("/bad/%2")))
  Assert.isTrue(isFailure(parsePath("/bad/%zz")))
}

export function testParseAuthorityHostOnly(): none {
  authority := try! parseAuthority("example.com")

  Assert.isFalse(authority.hasUserinfo())
  Assert.equal(authority.host, "example.com")
  Assert.isFalse(authority.hasPort())
}

export function testParseAuthorityUserinfoHostAndPort(): none {
  authority := try! parseAuthority("user%20name:pass@example.com:443")

  Assert.equal(authority.userinfo!, "user name:pass")
  Assert.equal(authority.host, "example.com")
  Assert.equal(authority.port!, "443")
}

export function testParseAuthorityBracketedHostAndEmptyPort(): none {
  authority := try! parseAuthority("[::1]:")

  Assert.isFalse(authority.hasUserinfo())
  Assert.equal(authority.host, "[::1]")
  Assert.equal(authority.port!, "")
}

export function testParseAuthorityKeepsUnbracketedIpv6AsHost(): none {
  authority := try! parseAuthority("2001:db8::1")

  Assert.equal(authority.host, "2001:db8::1")
  Assert.isFalse(authority.hasPort())
}

export function testParseAuthorityRejectsMalformedPercentEncodingAndBrackets(): none {
  Assert.isTrue(isFailure(parseAuthority("bad%zz.example")))
  Assert.isTrue(isFailure(parseAuthority("[::1")))
  Assert.isTrue(isFailure(parseAuthority("[::1]extra")))
}

export function testParseEmptyQueryHasNoEntries(): none {
  params := try! parseQueryParams("")

  Assert.isTrue(params.isEmpty())
  Assert.equal(params.size(), 0)
}

export function testParseQueryParamsPreservesOrderDuplicatesAndMissingValues(): none {
  params := try! parseQueryParams("tag=doof&flag&tag=stdlib&empty=&")

  Assert.equal(params.size(), 4)
  Assert.equal(params.entries[0].name, "tag")
  Assert.equal(params.entries[0].value!, "doof")
  Assert.equal(params.entries[1].name, "flag")
  Assert.isFalse(params.entries[1].hasValue())
  Assert.equal(params.entries[2].name, "tag")
  Assert.equal(params.entries[2].value!, "stdlib")
  Assert.equal(params.entries[3].name, "empty")
  Assert.equal(params.entries[3].value!, "")
}

export function testParseQueryParamsDiscardsEmptyEntries(): none {
  empty := try! parseQueryParams("&")
  params := try! parseQueryParams("a=1&&b=2&")

  Assert.equal(empty.size(), 0)
  Assert.equal(params.size(), 2)
  Assert.equal(params.entries[0].name, "a")
  Assert.equal(params.entries[0].value!, "1")
  Assert.equal(params.entries[1].name, "b")
  Assert.equal(params.entries[1].value!, "2")
}

export function testParseQueryParamsKeepsEmptyNamesAndValues(): none {
  missingValue := try! parseQueryParams("a")
  emptyValue := try! parseQueryParams("a=")
  emptyName := try! parseQueryParams("=x")
  emptyNameAndValue := try! parseQueryParams("=")

  Assert.equal(missingValue.size(), 1)
  Assert.equal(missingValue.entries[0].name, "a")
  Assert.isFalse(missingValue.entries[0].hasValue())
  Assert.equal(emptyValue.entries[0].name, "a")
  Assert.equal(emptyValue.entries[0].value!, "")
  Assert.equal(emptyName.entries[0].name, "")
  Assert.equal(emptyName.entries[0].value!, "x")
  Assert.equal(emptyNameAndValue.entries[0].name, "")
  Assert.equal(emptyNameAndValue.entries[0].value!, "")
}

export function testParseQueryParamsDecodesNamesValuesAndPlus(): none {
  params := try! parseQueryParams("hello+world=one%20two&encoded%2Bkey=%2B")

  Assert.equal(params.entries[0].name, "hello world")
  Assert.equal(params.entries[0].value!, "one two")
  Assert.equal(params.entries[1].name, "encoded+key")
  Assert.equal(params.entries[1].value!, "+")
}

export function testQueryParamsConvenienceMethodsRemainLossless(): none {
  params := try! parseQueryParams("tag=doof&flag&tag=stdlib")
  firstTag := params.first("tag")
  allTags := params.all("tag")

  Assert.isTrue(params.has("flag"))
  Assert.isFalse(params.has("missing"))
  Assert.equal(firstTag!.value!, "doof")
  Assert.equal(allTags.length, 2)
  Assert.equal(allTags[0].value!, "doof")
  Assert.equal(allTags[1].value!, "stdlib")
}

export function testParseQueryParamsRejectsMalformedPercentEncoding(): none {
  Assert.isTrue(isFailure(parseQueryParams("bad=%")))
  Assert.isTrue(isFailure(parseQueryParams("bad=%2")))
  Assert.isTrue(isFailure(parseQueryParams("bad=%zz")))
}
