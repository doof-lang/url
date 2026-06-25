# std/url

Minimal, lossless URL component parsing utilities.

## Documentation

- [Guide and API reference](docs/API.md) explains component parsing, percent decoding, preservation rules, and error reporting.
- Tests can be run with `doof test url`.

`std/url` is for parsing already-split URL components. It does not resolve full
URLs, normalize paths, canonicalize hosts, or rebuild URLs. The parsers preserve
details such as duplicate query parameters, missing query values, trailing path
slashes, and empty authority ports.

## Usage

```doof
import { parseAuthority, parsePath, parseQueryParams } from "std/url"

path := try! parsePath("/api//v1/")
// absolute: true
// segments: ["api", "", "v1", ""]

query := try! parseQueryParams("tag=doof&flag&tag=stdlib")
// preserves order, duplicate names, and the difference between `flag` and `flag=`

authority := try! parseAuthority("user@example.com:443")
// userinfo: "user", host: "example.com", port: "443"
```

Percent escapes are decoded by every parser. Query parsing also decodes `+` as a
space; path and authority parsing keep `+` as a literal plus sign.

## Exports

#### `parsePath(text: string): Result<Path, UrlError>`

Parse a URL path component into decoded path segments while preserving interior
and trailing empty segments and whether the input started with `/`. A leading
`/` is represented by `absolute`, not by an extra leading empty segment.
The parser does not resolve `.` or `..`, and a decoded `%2F` stays inside the
segment where it appeared.

#### Empty paths, root paths, and trailing slashes

`Path` distinguishes an empty path from the absolute root path.

| input | absolute | segments | meaning |
|---|---:|---|---|
| `""` | `false` | `[]` | empty path / no path |
| `"foo"` | `false` | `["foo"]` | relative path |
| `"/"` | `true` | `[""]` | absolute root path |
| `"/foo"` | `true` | `["foo"]` | absolute path to `foo` |
| `"/foo/"` | `true` | `["foo", ""]` | absolute path with trailing slash |
| `"/foo//bar"` | `true` | `["foo", "", "bar"]` | preserves empty interior segment |

#### `parseQueryParams(text: string): Result<QueryParams, UrlError>`

Parse a URL query string into ordered entries. Query names and values decode
percent escapes, and `+` decodes to a space. Entries without `=` preserve a
missing value as `null`. Empty entries from leading, trailing, or repeated `&`
are discarded.

| input | params |
|---|---|
| `""` | `[]` |
| `"&"` | `[]` |
| `"a"` | `[("a", null)]` |
| `"a="` | `[("a", "")]` |
| `"=x"` | `[("", "x")]` |
| `"="` | `[("", "")]` |
| `"a=1&b=2"` | `[("a", "1"), ("b", "2")]` |
| `"a=1&&b=2&"` | `[("a", "1"), ("b", "2")]` |

#### `parseAuthority(text: string): Result<Authority, UrlError>`

Parse a URL authority component into decoded `userinfo`, `host`, and `port`
parts. `userinfo` and `port` are `null` when absent. Empty parts are preserved
when their separator is present, so `example.com:` has an empty port. Bracketed
hosts are kept bracketed, e.g. `[::1]:443` parses as host `[::1]` and port
`443`.

When userinfo is present, the last `@` separates it from the host and port.
Unbracketed hosts with multiple `:` characters are treated as host-only text.

#### `Path`

- `absolute: bool`
- `segments: readonly string[]`
- `isEmpty(): bool`
- `segmentCount(): int`
- `segment(index: int): string`

#### `Authority`

- `userinfo: string | null`
- `host: string`
- `port: string | null`
- `hasUserinfo(): bool`
- `hasPort(): bool`

#### `QueryParam`

- `name: string`
- `value: string | null`
- `hasValue(): bool`

#### `QueryParams`

- `entries: readonly QueryParam[]`
- `isEmpty(): bool`
- `size(): int`
- `has(name: string): bool`
- `first(name: string): QueryParam | null`
- `all(name: string): readonly QueryParam[]`

#### `UrlError`

Currently reports malformed percent escapes and malformed authority syntax with:

- `kind: string`
- `index: int`
- `message: string`
