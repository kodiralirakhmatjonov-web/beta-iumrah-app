import type { D1Like, D1PreparedStatementLike } from "./primary-hotels";

export type DurableObjectIdLike = unknown;

export type DurableObjectStubLike = {
  fetch(request: Request): Promise<Response>;
};

export type DurableObjectNamespaceLike = {
  idFromName(name: string): DurableObjectIdLike;
  get(id: DurableObjectIdLike): DurableObjectStubLike;
};

export type Env = {
  PRICING_VERSION?: string;
  HOTELS_DB?: D1Like;
  BOOKINGS_DB?: D1Like & { batch(statements: D1PreparedStatementLike[]): Promise<unknown[]> };
  SEARCH_SESSIONS?: DurableObjectNamespaceLike;
  CBU_FX_URL?: string;
  AUTH_SESSION_URL?: string;
  PACKAGE_BOOKING_UPSTREAM?: string;
};
