/**
 * Сравнение токенов за постоянное время: наивное `a === b` выходит из цикла на
 * первом несовпавшем символе и по времени ответа выдаёт префикс токена.
 */
export function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const bytesA = encoder.encode(a);
  const bytesB = encoder.encode(b);
  if (bytesA.length !== bytesB.length) return false;

  let diff = 0;
  for (let i = 0; i < bytesA.length; i++) {
    diff |= bytesA[i]! ^ bytesB[i]!;
  }
  return diff === 0;
}

export function isAuthorized(request: Request, expectedToken: string): boolean {
  if (!expectedToken) return false;
  const header = request.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return false;
  return timingSafeEqual(header.slice("Bearer ".length).trim(), expectedToken);
}
