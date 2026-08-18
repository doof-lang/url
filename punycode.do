import { PunycodeError, punycodeFailure } from "./punycode_error"
import { decodePunycodeUtf8, encodePunycodeUtf8 } from "./punycode_utf8"

readonly BASE = 36L
readonly TMIN = 1L
readonly TMAX = 26L
readonly SKEW = 38L
readonly DAMP = 700L
readonly INITIAL_BIAS = 72L
readonly INITIAL_N = 128L
readonly MAX_INT = 2147483647L

export function encodePunycodeLabel(text: string): Result<string, PunycodeError> {
  try input := decodePunycodeUtf8(text)
  output: int[] := []

  for codepoint of input {
    if codepoint < 128 {
      output.push(codepoint)
    }
  }

  let handled = output.length
  basicCount := handled
  if basicCount > 0 {
    output.push(int('-'))
  }

  let n = INITIAL_N
  let delta = 0L
  let bias = INITIAL_BIAS

  while handled < input.length {
    let nextCodepoint = 1114112L
    for codepoint of input {
      value := long(codepoint)
      if value >= n && nextCodepoint > value {
        nextCodepoint = value
      }
    }

    distance := nextCodepoint - n
    points := long(handled) + 1L
    if distance > (MAX_INT - delta) \ points {
      return punycodeFailure<string>("overflow", handled, "Punycode encoding overflow")
    }
    delta += distance * points
    n = nextCodepoint

    for codepoint of input {
      value := long(codepoint)
      if value < n {
        if delta == MAX_INT {
          return punycodeFailure<string>("overflow", handled, "Punycode encoding overflow")
        }
        delta += 1L
      }

      if value == n {
        let q = delta
        let k = BASE
        while true {
          thresholdValue := threshold(k, bias)
          if q < thresholdValue {
            break
          }
          output.push(encodeDigit(thresholdValue + (q - thresholdValue) % (BASE - thresholdValue)))
          q = (q - thresholdValue) \ (BASE - thresholdValue)
          k += BASE
        }
        output.push(encodeDigit(q))
        bias = adapt(delta, points, handled == basicCount)
        delta = 0L
        handled += 1
      }
    }

    if delta == MAX_INT || n == MAX_INT {
      return punycodeFailure<string>("overflow", handled, "Punycode encoding overflow")
    }
    delta += 1L
    n += 1L
  }

  return encodePunycodeUtf8(output)
}

export function decodePunycodeLabel(text: string): Result<string, PunycodeError> {
  output: int[] := []
  delimiter := findLastByte(text, int('-'))
  let inputIndex = 0

  if delimiter >= 0 {
    let index = 0
    while index < delimiter {
      value := int(text.charAt(index))
      if value >= 128 {
        return punycodeFailure<string>("invalid-punycode", index, "Punycode basic section must be ASCII")
      }
      output.push(value)
      index += 1
    }
    inputIndex = delimiter + 1
  }

  let n = INITIAL_N
  let insertion = 0L
  let bias = INITIAL_BIAS

  while inputIndex < text.length {
    oldInsertion := insertion
    let weight = 1L
    let k = BASE

    while true {
      if inputIndex >= text.length {
        return punycodeFailure<string>("invalid-punycode", inputIndex, "Truncated Punycode input")
      }

      digit := decodeDigit(int(text.charAt(inputIndex)))
      if 0 > digit {
        return punycodeFailure<string>("invalid-punycode", inputIndex, "Invalid Punycode digit")
      }
      inputIndex += 1

      digitValue := long(digit)
      if digitValue > (MAX_INT - insertion) \ weight {
        return punycodeFailure<string>("overflow", inputIndex - 1, "Punycode decoding overflow")
      }
      insertion += digitValue * weight

      limit := threshold(k, bias)
      if digitValue < limit {
        break
      }
      factor := BASE - limit
      if weight > MAX_INT \ factor {
        return punycodeFailure<string>("overflow", inputIndex - 1, "Punycode decoding overflow")
      }
      weight *= factor
      k += BASE
    }

    outputSize := long(output.length) + 1L
    bias = adapt(insertion - oldInsertion, outputSize, oldInsertion == 0L)
    increment := insertion \ outputSize
    if increment > 1114111L - n {
      return punycodeFailure<string>("overflow", inputIndex, "Decoded code point is outside Unicode")
    }
    n += increment
    insertion %= outputSize

    if n >= 55296L && n <= 57343L {
      return punycodeFailure<string>("invalid-punycode", inputIndex, "Decoded Punycode contains a surrogate")
    }

    insertCodepoint(output, int(insertion), int(n))
    insertion += 1L
  }

  return encodePunycodeUtf8(output)
}

function threshold(k: long, bias: long): long {
  if k <= bias + TMIN {
    return TMIN
  }
  if k >= bias + TMAX {
    return TMAX
  }
  return k - bias
}

function adapt(deltaValue: long, pointCount: long, firstTime: bool): long {
  let delta = if firstTime then deltaValue \ DAMP else deltaValue \ 2L
  delta += delta \ pointCount
  let k = 0L
  while delta > ((BASE - TMIN) * TMAX) \ 2L {
    delta = delta \ (BASE - TMIN)
    k += BASE
  }
  return k + ((BASE - TMIN + 1L) * delta) \ (delta + SKEW)
}

function encodeDigit(digit: long): int {
  if digit < 26L {
    return int('a') + int(digit)
  }
  return int('0') + int(digit - 26L)
}

function decodeDigit(value: int): int {
  if value >= int('a') && value <= int('z') {
    return value - int('a')
  }
  if value >= int('A') && value <= int('Z') {
    return value - int('A')
  }
  if value >= int('0') && value <= int('9') {
    return 26 + value - int('0')
  }
  return -1
}

function insertCodepoint(values: int[], index: int, value: int): none {
  values.push(value)
  let cursor = values.length - 1
  while cursor > index {
    values[cursor] = values[cursor - 1]
    cursor -= 1
  }
  values[index] = value
}

function findLastByte(text: string, target: int): int {
  let found = -1
  let index = 0
  while index < text.length {
    if int(text.charAt(index)) == target {
      found = index
    }
    index += 1
  }
  return found
}
