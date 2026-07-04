import { createContext, useContext } from 'react';
import { shortId } from '../lib/format';

/** Resolution order: "You" for own identity → local alias (localStorage) →
 *  mock-seeded suggestion → truncated identity id. Never invented. */
export interface NameApi {
  display(identityId: string): string;
  isSelf(identityId: string): boolean;
  requestRename(identityId: string): void;
}

export const NamesContext = createContext<NameApi>({
  display: shortId,
  isSelf: () => false,
  requestRename: () => {},
});

export function useNames(): NameApi {
  return useContext(NamesContext);
}
