import {
  Generated,
  Insertable,
  Selectable,
  Updateable,
} from "kysely";

export type UserRole =
  | "admin"
  | "trainer"
  | "employee"
  | "employee_trainer"
  | "member";

export interface UsersTable {
  id: Generated<string>;
  username: string;
  email: string;
  password: string;
  name: string;
  last_name: string;
  role: Generated<UserRole>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export type User = Selectable<UsersTable>;
export type UserInsert = Insertable<UsersTable>;
export type UserUpdate = Updateable<UsersTable>;

export interface Database {
  users: UsersTable;
}
