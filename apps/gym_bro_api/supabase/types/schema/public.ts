import type {
  ColumnType,
  Generated,
  Insertable,
  Selectable,
  Updateable,
} from "npm:kysely@^0.27";

// ── Enums ─────────────────────────────────────────────────────────────────────

export type UserRole =
  | "owner"
  | "trainer"
  | "employee"
  | "employee_trainer"
  | "member"
  | "super_user";

export type BusinessType = "gym" | "shop";

export type ShopItemType = "equipment" | "supplement" | "gift_card";

// ── Tables ────────────────────────────────────────────────────────────────────

export interface UsersTable {
  id: Generated<string>;
  username: string;
  email: string;
  // Managed by Supabase Auth for auth-flow users; empty string for legacy rows.
  password: ColumnType<string, string | undefined, string>;
  name: string;
  last_name: string;
  role: Generated<UserRole>; // DB default: 'member'
  // Links to auth.users. Null for rows created outside the auth flow.
  auth_id: ColumnType<string | null, string | null | undefined, string | null>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface BusinessTable {
  id: Generated<string>;
  name: string;
  location: string;
  logo: string | null;
  working_hours_from: string; // TIME as HH:MM:SS string
  working_hours_to: string;
  working_weekdays: number[]; // ISO weekday ints 1–7
  type: BusinessType;
}

export interface GymTable {
  id: string; // FK → business.id (also PK)
}

export interface ShopTable {
  id: string; // FK → business.id (also PK)
}

export interface TrainerTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface MemberTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface EmployeeTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface EmployeeTrainerTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface GymOwnerTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface ShopOwnerTable {
  id: Generated<string>;
  user_id: string;
  shop_id: string;
}

export interface GymMembershipTypeTable {
  id: Generated<string>;
  name: string;
  monthly_cost: ColumnType<string, string | number, string | number>; // NUMERIC
  gym_id: string;
  is_active: Generated<boolean>;
}

export interface MembershipTable {
  id: Generated<string>;
  user_id: string;
  current_membership_type_id: string;
  from_date: string; // DATE as ISO string
  to_date: string;
  last_updated_date: Generated<string>;
  is_active: Generated<boolean>;
}

export interface MembershipInvoiceTable {
  id: Generated<string>;
  membership_id: string;
  membership_type_id: string;
  issued_at: Generated<string>;
  amount: ColumnType<string, string | number, string | number>; // NUMERIC
}

export interface ShopItemTable {
  id: Generated<string>;
  shop_id: string;
  type: ShopItemType;
  name: string;
  description: string | null;
  price: ColumnType<string, string | number, string | number>; // NUMERIC
  is_active: Generated<boolean>;
  active_until: string | null; // TIMESTAMPTZ as ISO string
}

export interface InvoiceTable {
  id: Generated<string>;
  date: Generated<string>; // DATE as ISO string, defaults to CURRENT_DATE
  // Maintained by trigger; never set manually. Use ColumnType<select, never, never>.
  total: ColumnType<string, never, never>;
}

export interface InvoiceItemTable {
  id: Generated<string>;
  invoice_id: string;
  shop_item_id: string;
  quantity: number;
}

// ── Database ──────────────────────────────────────────────────────────────────

export interface Database {
  users: UsersTable;
  business: BusinessTable;
  gym: GymTable;
  shop: ShopTable;
  trainer: TrainerTable;
  member: MemberTable;
  employee: EmployeeTable;
  employee_trainer: EmployeeTrainerTable;
  gym_owner: GymOwnerTable;
  shop_owner: ShopOwnerTable;
  gym_membership_type: GymMembershipTypeTable;
  membership: MembershipTable;
  membership_invoice: MembershipInvoiceTable;
  shop_item: ShopItemTable;
  invoice: InvoiceTable;
  invoice_item: InvoiceItemTable;
}

// ── CRUD helpers ──────────────────────────────────────────────────────────────

export type User = Selectable<UsersTable>;
export type UserInsert = Insertable<UsersTable>;
export type UserUpdate = Updateable<UsersTable>;

export type Business = Selectable<BusinessTable>;
export type BusinessInsert = Insertable<BusinessTable>;
export type BusinessUpdate = Updateable<BusinessTable>;

export type Gym = Selectable<GymTable>;
export type GymInsert = Insertable<GymTable>;
export type GymUpdate = Updateable<GymTable>;

export type Shop = Selectable<ShopTable>;
export type ShopInsert = Insertable<ShopTable>;
export type ShopUpdate = Updateable<ShopTable>;

export type Trainer = Selectable<TrainerTable>;
export type TrainerInsert = Insertable<TrainerTable>;
export type TrainerUpdate = Updateable<TrainerTable>;

export type Member = Selectable<MemberTable>;
export type MemberInsert = Insertable<MemberTable>;
export type MemberUpdate = Updateable<MemberTable>;

export type Employee = Selectable<EmployeeTable>;
export type EmployeeInsert = Insertable<EmployeeTable>;
export type EmployeeUpdate = Updateable<EmployeeTable>;

export type EmployeeTrainer = Selectable<EmployeeTrainerTable>;
export type EmployeeTrainerInsert = Insertable<EmployeeTrainerTable>;
export type EmployeeTrainerUpdate = Updateable<EmployeeTrainerTable>;

export type GymOwner = Selectable<GymOwnerTable>;
export type GymOwnerInsert = Insertable<GymOwnerTable>;
export type GymOwnerUpdate = Updateable<GymOwnerTable>;

export type ShopOwner = Selectable<ShopOwnerTable>;
export type ShopOwnerInsert = Insertable<ShopOwnerTable>;
export type ShopOwnerUpdate = Updateable<ShopOwnerTable>;

export type GymMembershipType = Selectable<GymMembershipTypeTable>;
export type GymMembershipTypeInsert = Insertable<GymMembershipTypeTable>;
export type GymMembershipTypeUpdate = Updateable<GymMembershipTypeTable>;

export type Membership = Selectable<MembershipTable>;
export type MembershipInsert = Insertable<MembershipTable>;
export type MembershipUpdate = Updateable<MembershipTable>;

export type MembershipInvoice = Selectable<MembershipInvoiceTable>;
export type MembershipInvoiceInsert = Insertable<MembershipInvoiceTable>;
export type MembershipInvoiceUpdate = Updateable<MembershipInvoiceTable>;

export type ShopItem = Selectable<ShopItemTable>;
export type ShopItemInsert = Insertable<ShopItemTable>;
export type ShopItemUpdate = Updateable<ShopItemTable>;

export type Invoice = Selectable<InvoiceTable>;
export type InvoiceInsert = Insertable<InvoiceTable>;

export type InvoiceItem = Selectable<InvoiceItemTable>;
export type InvoiceItemInsert = Insertable<InvoiceItemTable>;
export type InvoiceItemUpdate = Updateable<InvoiceItemTable>;

// ── Auth response ─────────────────────────────────────────────────────────────

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  user: {
    id: string;
    email: string;
    email_confirmed_at: string | null;
  };
}
