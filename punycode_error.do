export class PunycodeError {
  readonly kind: string
  readonly index: int
  readonly message: string
}

export function punycodeFailure<T>(kind: string, index: int, message: string): Result<T, PunycodeError> {
  return Failure {
    error: PunycodeError { kind, index, message }
  }
}
