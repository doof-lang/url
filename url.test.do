import { Assert } from "std/assert"
import { parsePath, parseQueryParams } from "./index"

function isFailure<T, E>(result: Result<T, E>): bool {
  return case result {
    _: Success -> false,
    _: Failure -> true
  }
}

export function testParseEmptyPathHasNoSegments(): void {
  path := try! parsePath("")

  Assert.isFalse(path.absolute)
  Assert.isTrue(path.isEmpty())
  Assert.equal(path.segmentCount(), 0)
}

export function testParsePathPreservesEmptySegments(): void {
  path := try! parsePath("/api//v1/")

  Assert.isTrue(path.absolute)
  Assert.equal(path.segmentCount(), 4)
  Assert.equal(path.segment(0), "api")
  Assert.equal(path.segment(1), "")
  Assert.equal(path.segment(2), "v1")
  Assert.equal(path.segment(3), "")
}

export function testParseAbsoluteRootPathHasOnlyTrailingEmptySegment(): void {
  path := try! parsePath("/")

  Assert.isTrue(path.absolute)
  Assert.equal(path.segmentCount(), 1)
  Assert.equal(path.segment(0), "")
}

export function testParsePathDecodesPercentEncodingWithoutTreatingPlusAsSpace(): void {
  path := try! parsePath("/hello%20world/a+b/%2F")

  Assert.equal(path.segment(0), "hello world")
  Assert.equal(path.segment(1), "a+b")
  Assert.equal(path.segment(2), "/")
}

export function testParsePathRejectsMalformedPercentEncoding(): void {
  Assert.isTrue(isFailure(parsePath("/bad/%")))
  Assert.isTrue(isFailure(parsePath("/bad/%2")))
  Assert.isTrue(isFailure(parsePath("/bad/%zz")))
}

export function testParseEmptyQueryHasNoEntries(): void {
  params := try! parseQueryParams("")

  Assert.isTrue(params.isEmpty())
  Assert.equal(params.size(), 0)
}

export function testParseQueryParamsPreservesOrderDuplicatesAndMissingValues(): void {
  params := try! parseQueryParams("tag=doof&flag&tag=stdlib&empty=&")

  Assert.equal(params.size(), 5)
  Assert.equal(params.entries[0].name, "tag")
  Assert.equal(params.entries[0].value!, "doof")
  Assert.equal(params.entries[1].name, "flag")
  Assert.isFalse(params.entries[1].hasValue())
  Assert.equal(params.entries[2].name, "tag")
  Assert.equal(params.entries[2].value!, "stdlib")
  Assert.equal(params.entries[3].name, "empty")
  Assert.equal(params.entries[3].value!, "")
  Assert.equal(params.entries[4].name, "")
  Assert.isFalse(params.entries[4].hasValue())
}

export function testParseQueryParamsDecodesNamesValuesAndPlus(): void {
  params := try! parseQueryParams("hello+world=one%20two&encoded%2Bkey=%2B")

  Assert.equal(params.entries[0].name, "hello world")
  Assert.equal(params.entries[0].value!, "one two")
  Assert.equal(params.entries[1].name, "encoded+key")
  Assert.equal(params.entries[1].value!, "+")
}

export function testQueryParamsConvenienceMethodsRemainLossless(): void {
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

export function testParseQueryParamsRejectsMalformedPercentEncoding(): void {
  Assert.isTrue(isFailure(parseQueryParams("bad=%")))
  Assert.isTrue(isFailure(parseQueryParams("bad=%2")))
  Assert.isTrue(isFailure(parseQueryParams("bad=%zz")))
}
