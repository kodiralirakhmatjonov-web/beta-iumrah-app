import type { D1Like, D1PreparedStatementLike } from "./d1";

export type Env = {
  IGNAV_API_KEY?: string;
  HOTELS_DB?: D1Like;
  BOOKINGS_DB?: D1Like & { batch(statements: D1PreparedStatementLike[]): Promise<unknown[]> };
};
