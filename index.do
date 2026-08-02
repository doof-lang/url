import { BlobBuilder, BlobReader } from "std/blob"

export class UrlError {
  readonly kind: string
  readonly index: int
  readonly message: string
}

export class Path {
  readonly absolute: bool
  readonly segments: readonly string[]

  isEmpty(): bool => this.segments.length == 0

  segmentCount(): int => this.segments.length

  segment(index: int): string => this.segments[index]
}

export class Authority {
  readonly userinfo: string | none
  readonly host: string
  readonly port: string | none

  hasUserinfo(): bool => this.userinfo != none

  hasPort(): bool => this.port != none
}

export class QueryParam {
  readonly name: string
  readonly value: string | none

  hasValue(): bool => this.value != none
}

export class QueryParams {
  readonly entries: readonly QueryParam[]

  isEmpty(): bool => this.entries.length == 0

  size(): int => this.entries.length

  has(name: string): bool {
    for entry of this.entries {
      if entry.name == name {
        return true
      }
    }
    return false
  }

  first(name: string): QueryParam | none {
    for entry of this.entries {
      if entry.name == name {
        return entry
      }
    }
    return none
  }

  all(name: string): readonly QueryParam[] {
    matches: QueryParam[] := []
    for entry of this.entries {
      if entry.name == name {
        matches.push(entry)
      }
    }
    return matches.drainToReadonly()
  }
}

export function parsePath(text: string): Result<Path, UrlError> {
  if text.length == 0 {
    return Success {
      value: Path {
        absolute: false,
        segments: readonly [],
      }
    }
  }

  rawSegments := text.split("/")
  segments: string[] := []
  let firstSegment = if text.startsWith("/") then 1 else 0

  for index of firstSegment..<rawSegments.length {
    rawSegment := rawSegments[index]
    try segment := decodeComponent(rawSegment, false)
    segments.push(segment)
  }

  return Success {
    value: Path {
      absolute: text.startsWith("/"),
      segments: segments.drainToReadonly(),
    }
  }
}

export function parseAuthority(text: string): Result<Authority, UrlError> {
  let userinfo: string | none = none
  let hostPort = text
  atIndex := findLastChar(text, '@')

  if atIndex >= 0 {
    try decodedUserinfo := decodeComponent(text.substring(0, atIndex), false)
    userinfo = decodedUserinfo
    hostPort = text.slice(atIndex + 1)
  }

  let hostText = hostPort
  let port: string | none = none

  if hostPort.startsWith("[") {
    closeIndex := findChar(hostPort, ']')
    if closeIndex < 0 {
      return invalidAuthority(0, "Missing closing bracket in authority host")
    }

    hostText = hostPort.substring(0, closeIndex + 1)
    if closeIndex + 1 < hostPort.length {
      if hostPort.charAt(closeIndex + 1) != ':' {
        return invalidAuthority(closeIndex + 1, "Invalid bracketed authority host")
      }
      port = hostPort.slice(closeIndex + 2)
    }
  } else {
    portSeparator := findSingleChar(hostPort, ':')
    if portSeparator >= 0 {
      hostText = hostPort.substring(0, portSeparator)
      port = hostPort.slice(portSeparator + 1)
    }
  }

  try host := decodeComponent(hostText, false)

  return Success {
    value: Authority {
      userinfo,
      host,
      port,
    }
  }
}

export function parseQueryParams(text: string): Result<QueryParams, UrlError> {
  if text.length == 0 {
    return Success {
      value: QueryParams {
        entries: readonly [],
      }
    }
  }

  entries: QueryParam[] := []
  rawEntries := text.split("&")

  for rawEntry of rawEntries {
    if rawEntry.length == 0 {
      continue
    }

    separator := rawEntry.indexOf("=")
    if separator < 0 {
      try name := decodeComponent(rawEntry, true)
      entries.push(QueryParam { name, value: none })
      continue
    }

    try name := decodeComponent(rawEntry.substring(0, separator), true)
    try value := decodeComponent(rawEntry.slice(separator + 1), true)
    entries.push(QueryParam { name, value })
  }

  return Success {
    value: QueryParams {
      entries: entries.drainToReadonly(),
    }
  }
}

function decodeComponent(text: string, plusAsSpace: bool): Result<string, UrlError> {
  builder := BlobBuilder()
  let rawStart = 0
  let index = 0

  while index < text.length {
    current := text.charAt(index)

    if current == '%' {
      if rawStart < index {
        builder.writeString(text.substring(rawStart, index))
      }

      if index + 2 >= text.length {
        return invalidPercentEncoding(index)
      }

      high := hexValue(text.charAt(index + 1))
      low := hexValue(text.charAt(index + 2))
      if high < 0 || low < 0 {
        return invalidPercentEncoding(index)
      }

      builder.writeByte(byte(high * 16 + low))
      index += 3
      rawStart = index
      continue
    }

    if plusAsSpace && current == '+' {
      if rawStart < index {
        builder.writeString(text.substring(rawStart, index))
      }
      builder.writeString(" ")
      index += 1
      rawStart = index
      continue
    }

    index += 1
  }

  if rawStart < text.length {
    builder.writeString(text.substring(rawStart, text.length))
  }

  bytes := builder.build()
  reader := BlobReader(bytes)
  return Success { value: reader.readString(reader.length()) }
}

function findChar(text: string, target: char): int {
  let index = 0
  while index < text.length {
    if text.charAt(index) == target {
      return index
    }
    index += 1
  }
  return -1
}

function findLastChar(text: string, target: char): int {
  let found = -1
  let index = 0
  while index < text.length {
    if text.charAt(index) == target {
      found = index
    }
    index += 1
  }
  return found
}

function findSingleChar(text: string, target: char): int {
  let found = -1
  let index = 0
  while index < text.length {
    if text.charAt(index) == target {
      if found >= 0 {
        return -1
      }
      found = index
    }
    index += 1
  }
  return found
}

function hexValue(value: char): int {
  if value >= '0' && value <= '9' {
    return int(value) - int('0')
  }
  if value >= 'a' && value <= 'f' {
    return 10 + int(value) - int('a')
  }
  if value >= 'A' && value <= 'F' {
    return 10 + int(value) - int('A')
  }
  return -1
}

function invalidPercentEncoding(index: int): Result<string, UrlError> {
  return Failure {
    error: UrlError {
      kind: "invalid-percent-encoding",
      index,
      message: "Invalid percent encoding at byte ${index}",
    }
  }
}

function invalidAuthority(index: int, message: string): Result<Authority, UrlError> {
  return Failure {
    error: UrlError {
      kind: "invalid-authority",
      index,
      message,
    }
  }
}
