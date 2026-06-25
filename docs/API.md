# std/url Guide

`std/url` parses URL components without normalizing away information. It is
currently focused on paths, authorities, and query strings rather than full URL
resolution. Use it when you already have a component string and need decoded,
lossless structure.

This module intentionally does not resolve relative URLs, canonicalize hosts,
remove dot segments, sort query parameters, validate schemes, or join a full
URL back together. Those operations can be layered on top when a caller wants
them, but the parsers here preserve the component details that would otherwise
be easy to lose.

## Quick Start

```doof
import { parseAuthority, parsePath, parseQueryParams } from "std/url"

path := try! parsePath("/api//v1/")
println(path.absolute)        // true
println(path.segmentCount())  // 4
println(path.segment(1))      // ""

query := try! parseQueryParams("tag=doof&flag&tag=stdlib")
println(query.first("tag")!.value!)  // "doof"
println(query.all("tag").length)     // 2
println(query.first("flag")!.value)  // null

authority := try! parseAuthority("user%20name@example.com:443")
println(authority.userinfo!)  // "user name"
println(authority.host)       // "example.com"
println(authority.port!)      // "443"
```

## Component Scope

Each parser accepts only the component it is named for. Do not pass a full URL
to `parsePath`, `parseAuthority`, or `parseQueryParams`.

```doof
path := try! parsePath("/search/results")
authority := try! parseAuthority("example.com:443")
query := try! parseQueryParams("q=doof&page=1")
```

If you are splitting a full URL elsewhere, pass the raw component text without
the separator character:

- path text does not include scheme or authority, but it may start with `/`
- query text does not include the leading `?`
- authority text does not include leading `//`

## Percent Decoding

All parsers decode percent escapes before returning component fields. Malformed
escapes return `Failure<UrlError>` with the error kind, byte index, and message.

Query parsing treats `+` as a space because query strings commonly use
`application/x-www-form-urlencoded` conventions. Path and authority parsing do
not treat `+` specially.

| Component | `%20` | `+` |
| --- | --- | --- |
| path | space | plus sign |
| authority | space | plus sign |
| query | space | space |

```doof
path := try! parsePath("/hello%20world/a+b")
println(path.segment(0))  // "hello world"
println(path.segment(1))  // "a+b"

params := try! parseQueryParams("hello+world=one%20two")
println(params.entries[0].name)    // "hello world"
println(params.entries[0].value!)  // "one two"
```

## Paths

`parsePath(text)` returns `Path { absolute, segments }`. A leading slash is
represented by `absolute`, not by a leading empty segment. Interior and trailing
empty segments are preserved.

```doof
path := try! parsePath("/api//v1/")

println(path.absolute)        // true
println(path.segmentCount())  // 4
println(path.segment(0))      // "api"
println(path.segment(1))      // ""
println(path.segment(2))      // "v1"
println(path.segment(3))      // ""
```

`std/url` does not normalize path segments. A literal `.` or `..` segment is
returned as text, and `%2F` decodes to `/` inside a segment rather than becoming
a path separator.

| Input | `absolute` | `segments` | Notes |
| --- | --- | --- | --- |
| `""` | `false` | `[]` | empty path / no path |
| `"foo"` | `false` | `["foo"]` | relative path |
| `"/"` | `true` | `[""]` | absolute root path |
| `"/foo"` | `true` | `["foo"]` | absolute path to `foo` |
| `"/foo/"` | `true` | `["foo", ""]` | trailing slash is preserved |
| `"/foo//bar"` | `true` | `["foo", "", "bar"]` | interior empty segment is preserved |
| `"/a%2Fb"` | `true` | `["a/b"]` | decoded slash stays inside the segment |
| `"/./../x"` | `true` | `[".", "..", "x"]` | dot segments are not resolved |

### `Path`

| Member | Type | Description |
| --- | --- | --- |
| `absolute` | `bool` | `true` when the input started with `/` |
| `segments` | `readonly string[]` | decoded path segments |

#### `isEmpty(): bool`

Return `true` when the path has no segments. The empty relative path `""` is
empty; the absolute root path `"/"` is not empty because it contains one empty
segment.

#### `segmentCount(): int`

Return the number of decoded segments.

#### `segment(index: int): string`

Return a decoded segment by index.

## Query Strings

`parseQueryParams(text)` returns ordered `QueryParam` entries. Duplicate names
are preserved. Empty entries caused by leading, trailing, or repeated `&` are
discarded.

Entries without `=` have `value: null`; entries with `=` preserve an empty
string value.

```doof
params := try! parseQueryParams("tag=doof&flag&tag=stdlib&empty=")

println(params.size())                // 4
println(params.first("tag")!.value!)  // "doof"
println(params.all("tag").length)     // 2
println(params.first("flag")!.value)  // null
println(params.first("empty")!.value!) // ""
```

| Input | Entries |
| --- | --- |
| `""` | `[]` |
| `"&"` | `[]` |
| `"a"` | `[("a", null)]` |
| `"a="` | `[("a", "")]` |
| `"=x"` | `[("", "x")]` |
| `"="` | `[("", "")]` |
| `"a=1&b=2"` | `[("a", "1"), ("b", "2")]` |
| `"a=1&&b=2&"` | `[("a", "1"), ("b", "2")]` |

### `QueryParam`

| Member | Type | Description |
| --- | --- | --- |
| `name` | `string` | decoded parameter name |
| `value` | <code>string | null</code> | decoded value, or `null` when no `=` was present |

#### `hasValue(): bool`

Return `true` when the entry included an `=` separator. This distinguishes
`flag` from `flag=`.

### `QueryParams`

| Member | Type | Description |
| --- | --- | --- |
| `entries` | `readonly QueryParam[]` | decoded entries in input order |

#### `isEmpty(): bool`

Return `true` when there are no parsed entries.

#### `size(): int`

Return the number of parsed entries.

#### `has(name: string): bool`

Return `true` when at least one entry has the exact decoded name.

#### `first(name: string): QueryParam | null`

Return the first entry with the exact decoded name, or `null` when there is no
match.

#### `all(name: string): readonly QueryParam[]`

Return all entries with the exact decoded name, preserving input order.

## Authorities

`parseAuthority(text)` returns decoded `userinfo`, `host`, and `port` fields.
`userinfo` and `port` are `null` when absent. Empty parts are preserved when the
separator is present, so `example.com:` has an empty port.

```doof
authority := try! parseAuthority("user%20name:pass@example.com:443")

println(authority.userinfo!)  // "user name:pass"
println(authority.host)       // "example.com"
println(authority.port!)      // "443"
```

When userinfo is present, the last `@` separates it from the host and port. This
allows decoded or literal `@` characters to appear earlier in the userinfo
field.

Bracketed hosts are kept bracketed. For example, `[::1]:443` parses as host
`[::1]` and port `443`. Unbracketed hosts with multiple `:` characters are
treated as host-only text, which preserves unbracketed IPv6-like input instead
of guessing at a port.

| Input | `userinfo` | `host` | `port` |
| --- | --- | --- | --- |
| `"example.com"` | `null` | `"example.com"` | `null` |
| `"example.com:443"` | `null` | `"example.com"` | `"443"` |
| `"example.com:"` | `null` | `"example.com"` | `""` |
| `"user@example.com"` | `"user"` | `"example.com"` | `null` |
| `"user%20name@example.com"` | `"user name"` | `"example.com"` | `null` |
| `"[::1]:443"` | `null` | `"[::1]"` | `"443"` |
| `"2001:db8::1"` | `null` | `"2001:db8::1"` | `null` |

### `Authority`

| Member | Type | Description |
| --- | --- | --- |
| `userinfo` | <code>string | null</code> | decoded userinfo before the last `@`, or `null` |
| `host` | `string` | decoded host text |
| `port` | <code>string | null</code> | text after a port separator, or `null` |

#### `hasUserinfo(): bool`

Return `true` when the authority contained userinfo. Empty userinfo is still
considered present when an `@` separator was present.

#### `hasPort(): bool`

Return `true` when the authority contained a port separator. An empty port is
still considered present when the authority ended with `:`.

## Errors

All parse functions return `Result<..., UrlError>`.

```doof
case parseQueryParams("bad=%zz") {
  success: Success -> println("ok")
  failure: Failure -> {
    error := failure.error
    println(error.kind)
    println(error.index)
    println(error.message)
  }
}
```

### `UrlError`

| Field | Type | Description |
| --- | --- | --- |
| `kind` | `string` | stable category such as `"invalid-percent-encoding"` or `"invalid-authority"` |
| `index` | `int` | byte index where parsing detected the problem |
| `message` | `string` | human-readable detail |

Malformed percent escapes fail in all parsers:

- `%` at the end of a component
- `%2` with only one hex digit
- `%zz` or any non-hex digits after `%`

Malformed authority syntax also fails:

- bracketed host without a closing `]`
- extra text after a bracketed host that is not introduced by `:`

## API Summary

```doof
export function parsePath(text: string): Result<Path, UrlError>
export function parseAuthority(text: string): Result<Authority, UrlError>
export function parseQueryParams(text: string): Result<QueryParams, UrlError>

export class UrlError
export class Path
export class Authority
export class QueryParam
export class QueryParams
```

All declarations are defined in [index.do](../index.do).
