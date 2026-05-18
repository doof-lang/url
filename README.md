# std/url

Minimal, lossless URL component parsing utilities.

## Usage

```doof
import { parsePath, parseQueryParams } from "std/url"

path := try! parsePath("/api//v1/")
// absolute: true
// segments: ["api", "", "v1", ""]

query := try! parseQueryParams("tag=doof&flag&tag=stdlib")
// preserves order, duplicate names, and the difference between `flag` and `flag=`
```

## Exports

#### `parsePath(text: string): Result<Path, UrlError>`

Parse a URL path component into decoded path segments while preserving interior
and trailing empty segments and whether the input started with `/`. A leading
`/` is represented by `absolute`, not by an extra leading empty segment.

#### `parseQueryParams(text: string): Result<QueryParams, UrlError>`

Parse a URL query string into ordered entries. Query names and values decode
percent escapes, and `+` decodes to a space. Entries without `=` preserve a
missing value as `null`.

#### `Path`

- `absolute: bool`
- `segments: readonly string[]`
- `isEmpty(): bool`
- `segmentCount(): int`
- `segment(index: int): string`

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

Currently reports malformed percent escapes with:

- `kind: string`
- `index: int`
- `message: string`
