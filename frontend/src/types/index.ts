export type User = {
  id: number;
  name: string;
  email: string;
};

export type Category = {
  id: number;
  userId: number;
  name: string;
  type: "expense" | "income" | "bill" | "loan" | "emi";
  icon: string;
  color: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
};

export type Expense = {
  id: number;
  userId: number;
  categoryId: number;
  amount: string;
  description: string | null;
  expenseDate: string;
  paymentMethod: string;
  isRecurring: boolean;
  categoryName: string;
  categoryColor: string;
  categoryIcon: string;
  createdAt: string;
  updatedAt: string;
};

export type Income = {
  id: number | null;
  userId: number;
  source: string;
  amount: string;
  incomeDate: string;
  isRecurring: boolean;
  frequency: string;
  notes: string | null;
  isReceived: boolean;
  parentId?: number | null;
  createdAt?: string;
  updatedAt?: string;
};

export type MonthlyBill = {
  id: number;
  userId: number;
  categoryId: number;
  name: string;
  amount: string;
  dueDate: number;
  reminderDays: number;
  notes: string | null;
  isPaid: boolean;
  isActive: boolean;
  categoryName: string;
  createdAt: string;
  updatedAt: string;
};

export type EmiPayment = {
  id: number;
  userId: number;
  loanId: number;
  emiNumber: number;
  dueDate: string;
  amount: string;
  principalAmount: string;
  interestAmount: string;
  isPaid: boolean;
  paidDate: string | null;
};

export type Loan = {
  id: number;
  userId: number;
  categoryId: number;
  name: string;
  lender: string | null;
  principalAmount: string;
  interestRate: string;
  tenureMonths: number;
  startDate: string;
  loanType: string;
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

export type Budget = {
  id: number;
  userId: number;
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

export type DashboardOverview = {
  expenses: { total: string; count: number };
  income: { total: string; count: number };
  bills: { total: string; paid: number; unpaid: number };
  emis: { total: string; paid: number; totalCount: number };
  loans: { activeCount: number; outstandingTotal: string; totalEMI: string };
  monthlyTrend: { month: string; expenses: string; income: string }[];
  categoryBreakdown: { categoryName: string; categoryColor: string; total: string }[];
  recentExpenses: {
    id: number;
    description: string | null;
    amount: string;
    expenseDate: string;
    categoryName: string;
    categoryColor: string;
  }[];
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
  dailyExpenses: { date: string; total: string }[];
  billsSummary: { name: string; amount: string; isPaid: boolean }[];
  emiSummary: { loanName: string; emiAmount: string; isPaid: boolean }[];
};

export type FinancialYearReport = {
  summary: MonthlyReport["summary"];
  monthlyData: { month: string; expenses: string; income: string; bills: string; emis: string }[];
  categoryYearly: { categoryName: string; categoryColor: string; total: string }[];
  loanSummary: {
    name: string;
    isActive: boolean;
    principalAmount: string;
    emiAmount: string;
    outstandingPrincipal: string;
    paidEmiCount: number;
    remainingEmiCount: number;
  }[];
};
