import type { D1Like, D1PreparedStatementLike } from "./d1";

export type Env = {
  HOTELS_DB?: D1Like;
  BOOKINGS_DB?: D1Like & { batch(statements: D1PreparedStatementLike[]): Promise<unknown[]> };
};
