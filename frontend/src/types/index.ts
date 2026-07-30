export type ISOString = string; // Future: Use template literals if specific format needed
export type DateString = string; // e.g. "YYYY-MM-DD"

export type CommonFields = {
  id: number;
  userId: number;
  createdAt: ISOString;
  updatedAt: ISOString;
};

export type CategoryType = "expense" | "income" | "bill" | "loan" | "emi";

export type Category = CommonFields & {
  name: string;
  type: CategoryType;
  icon: string;
  color: string;
  isDefault: boolean;
};

export type Expense = CommonFields & {
  categoryId: number;
  amount: string;
  description: string | null;
  expenseDate: DateString;
  paymentMethod: string;
  isRecurring: boolean;
  categoryName: string;
  categoryColor: string;
  categoryIcon: string;
};

export type IncomeFrequency = "weekly" | "monthly" | "quarterly" | "yearly" | "one_time";

export type Income = Omit<CommonFields, "id"> & {
  id: number | null; // Projected incomes have null id
  source: string;
  amount: string;
  incomeDate: DateString;
  isRecurring: boolean;
  frequency: IncomeFrequency;
  notes: string | null;
  isReceived: boolean;
  parentId?: number | null;
  endDate?: string | null;
  isCustom?: boolean;
  changeReason?: string | null;
  originalAmount?: string | number | null;
  amountDifference?: number | null;
  isLatestRecurring?: boolean;
  isOngoing?: boolean;
  gapInfo?: string | null;
};

export type MonthlyBill = CommonFields & {
  categoryId: number;
  name: string;
  amount: string;
  dueDate: number;
  reminderDays: number;
  notes: string | null;
  isPaid: boolean;
  isActive: boolean;
  categoryName: string;
};

export type EmiPayment = Omit<CommonFields, "createdAt" | "updatedAt"> & {
  loanId: number;
  emiNumber: number;
  dueDate: DateString;
  amount: string;
  principalAmount: string;
  interestAmount: string;
  isPaid: boolean;
  paidDate: DateString | null;
};

export type LoanType = "home" | "car" | "personal" | "education" | "business" | "gold" | "other";

export type Loan = CommonFields & {
  categoryId: number;
  name: string;
  lender: string | null;
  principalAmount: string;
  interestRate: string;
  tenureMonths: number;
  startDate: DateString;
  loanType: LoanType | string;
  notes: string | null;
  categoryName: string;
  categoryColor: string;
  emiAmount: string;
  outstandingPrincipal: string;
  totalInterest: string;
  totalAmount: string;
  isActive: boolean;
  paidEmiCount: number;
  remainingEmiCount: number;
};

export type LoanDetail = Loan & {
  emis: EmiPayment[];
};

export type Budget = CommonFields & {
  categoryId: number;
  month: number;
  year: number;
  amount: string;
  alertThreshold: number;
  categoryName: string;
  categoryColor: string;
  spent: number;
  percentage: number;
  remaining: number;
};

export type User = {
  id: number;
  name: string;
  email: string;
};

// Generic Create/Update Payloads
// We omit internal server fields and derived UI fields, then make everything else optional
// to allow server-side defaults, while maintaining type awareness.
export type CreatePayload<T> = Partial<
  Omit<
    T,
    | keyof CommonFields
    | "categoryName"
    | "categoryColor"
    | "categoryIcon"
    | "spent"
    | "percentage"
    | "remaining"
  >
>;
export type UpdatePayload<T> = CreatePayload<T> & { id: number };

export type DashboardOverview = {
  expenses: { total: string; count: number };
  income: { total: string; count: number; received: number; expected: number };
  bills: { total: string; paid: number; unpaid: number };
  emis: { total: string; paid: number; totalCount: number };
  loans: { activeCount: number; outstandingTotal: string; totalEMI: string };
  monthlyTrend: { month: string; expenses: string; income: string }[];
  categoryBreakdown: { categoryName: string; categoryColor: string; total: string }[];
  recentExpenses: Pick<Expense, "id" | "description" | "amount" | "expenseDate" | "categoryName" | "categoryColor">[];
  overall?: {
    totalIncome: string;
    totalExpense: string;
    totalEmiPaid: string;
    netBalance: string;
  };
};

export type MonthlyReport = {
  summary: {
    totalExpense: string;
    totalIncome: string;
    totalBills: string;
    totalEMI: string;
    netSavings: string;
  };
  categoryExpenses: { categoryName: string; categoryColor: string; total: string; count: number }[];
  dailyExpenses: { date: DateString; total: string }[];
  billsSummary: { name: string; amount: string; isPaid: boolean }[];
  emiSummary: { loanName: string; emiAmount: string; isPaid: boolean }[];
};

export type FinancialYearReport = {
  summary: MonthlyReport["summary"];
  monthlyData: { month: string; expenses: string; income: string; bills: string; emis: string }[];
  categoryYearly: { categoryName: string; categoryColor: string; total: string }[];
  loanSummary: Pick<Loan, "name" | "isActive" | "principalAmount" | "emiAmount" | "outstandingPrincipal" | "paidEmiCount" | "remainingEmiCount">[];
};

export type InvestmentAssetClass =
  | "speculative_intraday"
  | "non_speculative_fo"
  | "swing_trading"
  | "long_term_equity"
  | "mutual_funds"
  | "fixed_income"
  | "crypto"
  | "elss_80c"
  | "gold";

export type InvestmentStatus = "active" | "realized";

export type Investment = CommonFields & {
  name: string;
  assetClass: InvestmentAssetClass;
  symbol: string | null;
  quantity: string | number;
  buyPrice: string | number;
  currentPrice: string | number | null;
  sellPrice: string | number | null;
  investedAmount: string | number;
  realizedPnl: string | number;
  unrealizedPnl: string | number;
  purchaseDate: DateString;
  sellDate: DateString | null;
  status: InvestmentStatus;
  notes: string | null;
  currentValue?: string | number;
  totalPnl?: string | number;
  pnlPercentage?: number;
  isStcg?: boolean;
  isLtcg?: boolean;
};

export type ItrSummary = {
  financial_year: string;
  assessment_year: string;
  gross_salary: number;
  trading_summary: {
    speculative_intraday_pnl: number;
    non_speculative_fo_pnl: number;
    crypto_pnl: number;
    stcg_pnl: number;
    ltcg_pnl: number;
    total_pnl: number;
  };
  deductions: {
    section_80c: number;
    section_24b_home_loan_interest: number;
    standard_deduction_new: number;
    standard_deduction_old: number;
  };
  new_regime: {
    taxable_income: number;
    slab_tax: number;
    rebate_87a: number;
    total_tax: number;
  };
  old_regime: {
    taxable_income: number;
    slab_tax: number;
    rebate_87a: number;
    total_tax: number;
  };
  special_taxes: {
    stcg_tax_sec111a: number;
    ltcg_tax_sec112a: number;
    crypto_tax_sec115bbh: number;
  };
  recommendation: {
    best_regime: string;
    tax_saved: number;
    itr_form: string;
  };
};

export type DhanTokenStatus = {
  connected: boolean;
  expires_at?: string;
  client_id?: string;
  token_preview?: string;
  message?: string;
  error?: string;
};

export type DhanCredential = {
  client_id: string | null;
  token_service_url: string | null;
  has_token_service_secret: boolean;
  has_fallback_access_token: boolean;
  auto_import_pnl: boolean;
  message?: string;
};

export type DhanCredentialUpdate = {
  clientId?: string;
  tokenServiceUrl?: string;
  tokenServiceSecret?: string;
  fallbackAccessToken?: string;
  autoImportPnl?: boolean;
};

export type DhanPnlBucket = {
  buy_value: number;
  sell_value: number;
  charges: number;
  net_pnl: number;
  trade_count: number;
};

export type DhanPnlSummary = {
  from_date: string;
  to_date: string;
  truncated: boolean;
  segments: {
    speculative_intraday: DhanPnlBucket;
    non_speculative_fo: DhanPnlBucket;
    equity_delivery: DhanPnlBucket;
    commodity: DhanPnlBucket;
    other: DhanPnlBucket;
  };
};

export type DhanImportResult = {
  imported_count: number;
  investments: { id: number; name: string; asset_class: string; realized_pnl: string }[];
};

export type DhanSyncResult = {
  message: string;
  status: string;
};

export type DhanSyncStatus = {
  status: "none" | "running" | "completed" | "truncated";
  trades_imported: number;
};

export type BrokerSnapshots = {
  holdings: Record<string, unknown>[];
  positions: Record<string, unknown>[];
  last_synced_at: string | null;
};

export type Trade = {
  trade_date: string | null;
  symbol: string;
  security_id: string | null;
  isin: string | null;
  exchange_segment: string;
  product_type: string | null;
  instrument: string | null;
  transaction_type: "BUY" | "SELL";
  quantity: number;
  price: number;
  total_value: number;
  brokerage: number;
  stt: number;
  gst: number;
  sebi_tax: number;
  exchange_charges: number;
  stamp_duty: number;
  total_charges: number;
  net_value: number;
  expiry: string | null;
  strike_price: number | null;
  option_type: string | null;
  segment: string;
};

export type PnlReport = {
  from_date: string;
  to_date: string;
  trades: Trade[];
  summary: Record<string, {
    buy_value: number;
    sell_value: number;
    charges: number;
    net_pnl: number;
    trade_count: number;
  }>;
};
