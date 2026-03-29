// Kysely-style schema types for the public schema.
// Used to type the Supabase client via createClient<Database>().

export type UserRole =
  | "admin"
  | "trainer"
  | "employee"
  | "employee_trainer"
  | "member";

export interface UserRow {
  id: string;
  username: string;
  email: string;
  password: string;
  name: string;
  last_name: string;
  role: UserRole;
  created_at: string;
  updated_at: string;
}

export interface UserInsert {
  id?: string;
  username: string;
  email: string;
  password: string;
  name: string;
  last_name: string;
  role?: UserRole;
  created_at?: string;
  updated_at?: string;
}

export interface UserUpdate {
  username?: string;
  email?: string;
  password?: string;
  name?: string;
  last_name?: string;
  role?: UserRole;
}

export interface Database {
  public: {
    Tables: {
      users: {
        Row: UserRow;
        Insert: UserInsert;
        Update: UserUpdate;
      };
    };
    Enums: {
      user_role: UserRole;
    };
  };
}
