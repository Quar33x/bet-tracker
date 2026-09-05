import { describe, expect, it } from "vitest";
import { isAuthorized, timingSafeEqual } from "../src/auth";

const request = (headers: Record<string, string> = {}) =>
  new Request("https://example.com/matches/upcoming", { headers });

describe("timingSafeEqual", () => {
  it("сравнивает строки", () => {
    expect(timingSafeEqual("secret", "secret")).toBe(true);
    expect(timingSafeEqual("secret", "secrft")).toBe(false);
    expect(timingSafeEqual("secret", "secret ")).toBe(false);
    expect(timingSafeEqual("", "")).toBe(true);
  });

  it("не спотыкается о многобайтовые символы", () => {
    expect(timingSafeEqual("токен", "токен")).toBe(true);
    expect(timingSafeEqual("токен", "токін")).toBe(false);
  });
});

describe("isAuthorized", () => {
  it("пускает с верным токеном", () => {
    expect(isAuthorized(request({ authorization: "Bearer good" }), "good")).toBe(true);
  });

  it("не пускает с неверным, без заголовка и с чужой схемой", () => {
    expect(isAuthorized(request({ authorization: "Bearer bad" }), "good")).toBe(false);
    expect(isAuthorized(request(), "good")).toBe(false);
    expect(isAuthorized(request({ authorization: "Basic good" }), "good")).toBe(false);
  });

  it("не пускает никого, когда токен на сервере не настроен", () => {
    expect(isAuthorized(request({ authorization: "Bearer " }), "")).toBe(false);
    expect(isAuthorized(request({ authorization: "Bearer whatever" }), "")).toBe(false);
  });
});
