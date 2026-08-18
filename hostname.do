import { decodePunycodeLabel, encodePunycodeLabel } from "./punycode"
import { PunycodeError } from "./punycode_error"

export function hostnameToAscii(hostname: string): Result<string, PunycodeError> {
  if isBracketedHost(hostname) {
    return Success { value: hostname }
  }

  labels := hostname.split(".")
  let result = ""
  let offset = 0
  let index = 0
  while index < labels.length {
    if index > 0 {
      result += "."
    }

    label := labels[index]
    if containsNonAscii(label) {
      encoded := encodePunycodeLabel(label)
      case encoded {
        s: Success -> result += "xn--${s.value}"
        f: Failure -> return Failure { error: offsetError(f.error, offset) }
      }
    } else {
      result += label
    }

    offset += label.length + 1
    index += 1
  }
  return Success { value: result }
}

export function hostnameToUnicode(hostname: string): Result<string, PunycodeError> {
  if isBracketedHost(hostname) {
    return Success { value: hostname }
  }

  labels := hostname.split(".")
  let result = ""
  let offset = 0
  let index = 0
  while index < labels.length {
    if index > 0 {
      result += "."
    }

    label := labels[index]
    if label.toLowerCase().startsWith("xn--") {
      decoded := decodePunycodeLabel(label.slice(4))
      case decoded {
        s: Success -> result += s.value
        f: Failure -> return Failure { error: offsetError(f.error, offset + 4) }
      }
    } else {
      result += label
    }

    offset += label.length + 1
    index += 1
  }
  return Success { value: result }
}

function containsNonAscii(text: string): bool {
  let index = 0
  while index < text.length {
    if int(text.charAt(index)) >= 128 {
      return true
    }
    index += 1
  }
  return false
}

function isBracketedHost(hostname: string): bool {
  return hostname.length >= 2 && hostname.startsWith("[") && hostname.endsWith("]")
}

function offsetError(error: PunycodeError, offset: int): PunycodeError {
  return PunycodeError {
    kind: error.kind,
    index: offset + error.index,
    message: error.message,
  }
}
