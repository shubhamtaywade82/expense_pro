import type {
  Budget,
  Category,
  CreatePayload,
  DashboardOverview,
  EmiPayment,
  Expense,
  FinancialYearReport,
  Income,
  Loan,
  LoanDetail,
  MonthlyBill,
  MonthlyReport,
  UpdatePayload,
  User,
} from "@/types";

const BASE_URL = "/api/v1";

export class ApiError extends Error {}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem("jwt");
  const headers = {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(options.headers ?? {}),
  };

  const response = await fetch(`${BASE_URL}${path}`, {
    headers,
    ...options,
  });

  if (!response.ok) {
    let message = response.statusText || "Request failed";
    try {
      const body = await response.json();
      if (body?.error) message = body.error;
    } catch {
      // response had no JSON body
    }
    throw new ApiError(message);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}

function buildQuery(params: Record<string, string | number | boolean | undefined | null>): string {
  const search = new URLSearchParams();

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === "") continue;
    search.set(key, String(value));
  }

  const query = search.toString();
  return query ? `?${query}` : "";
}

const get = <T>(path: string) => request<T>(path);
const post = <T>(path: string, body?: unknown) =>
  request<T>(path, { method: "POST", body: body === undefined ? undefined : JSON.stringify(body) });
const patch = <T>(path: string, body?: unknown) =>
  request<T>(path, { method: "PATCH", body: body === undefined ? undefined : JSON.stringify(body) });
const del = <T>(path: string) => request<T>(path, { method: "DELETE" });

export const api = {
  auth: {
    me: () => get<User>("/session"),
    login: async (email: string, password: string) => {
      const data = await post<User & { token: string }>("/session", { email, password });
      if (data.token) localStorage.setItem("jwt", data.token);
      return data;
    },
    logout: async () => {
      localStorage.removeItem("jwt");
    },
    register: async (data: { name: string; email: string; password: string }) => {
      const res = await post<User & { token: string }>("/registrations", { user: data });
      if (res.token) localStorage.setItem("jwt", res.token);
      return res;
    },
  },

  categories: {
    list: () => get<Category[]>("/categories"),
    create: (data: CreatePayload<Category>) => post<Category>("/categories", data),
    update: (data: UpdatePayload<Category>) => patch<Category>(`/categories/${data.id}`, data),
    delete: (id: number) => del<void>(`/categories/${id}`),
  },

  expenses: {
    list: (params: { month?: number; year?: number; categoryId?: number; search?: string } = {}) =>
      get<Expense[]>(`/expenses${buildQuery(params)}`),
    create: (data: CreatePayload<Expense>) => post<Expense>("/expenses", data),
    update: (data: UpdatePayload<Expense>) => patch<Expense>(`/expenses/${data.id}`, data),
    delete: (id: number) => del<void>(`/expenses/${id}`),
  },

  incomes: {
    list: (params: { month?: number; year?: number; search?: string } = {}) =>
      get<Income[]>(`/incomes${buildQuery(params)}`),
    summary: (params: { month?: number; year?: number }) =>
      get<{ total: string; count: number; received: number; expected: number }>(`/incomes/summary${buildQuery(params)}`),
    yearly: (params: { year: number }) =>
      get<{
        year: number;
        total_income: number;
        total_received: number;
        months: {
          month: number;
          month_name: string;
          full_month_name: string;
          total: number;
          received: number;
          expected: number;
          count: number;
          incomes: Income[];
        }[];
      }>(`/incomes/yearly${buildQuery(params)}`),
    create: (data: CreatePayload<Income>) => post<Income>("/incomes", data),
    update: (data: UpdatePayload<Income>) => patch<Income>(`/incomes/${data.id}`, data),
    delete: (id: number) => del<void>(`/incomes/${id}`),
    toggleReceived: (id: number) => patch<Income>(`/incomes/${id}/toggle_received`),
  },

  bills: {
    list: () => get<MonthlyBill[]>("/bills"),
    create: (data: CreatePayload<MonthlyBill>) => post<MonthlyBill>("/bills", data),
    update: (data: UpdatePayload<MonthlyBill>) => patch<MonthlyBill>(`/bills/${data.id}`, data),
    delete: (id: number) => del<void>(`/bills/${id}`),
    togglePaid: (id: number) => patch<MonthlyBill>(`/bills/${id}/toggle_paid`),
  },

  loans: {
    list: () => get<Loan[]>("/loans"),
    byId: (id: number) => get<LoanDetail>(`/loans/${id}`),
    create: (data: CreatePayload<Loan>) => post<Loan>("/loans", data),
    delete: (id: number) => del<void>(`/loans/${id}`),
    payEmi: ({ emiId, paidDate }: { emiId: number; paidDate?: string }) =>
      patch<EmiPayment>(`/emi_payments/${emiId}/pay`, { paidDate }),
  },

  budgets: {
    list: (params: { month: number; year: number }) => get<Budget[]>(`/budgets${buildQuery(params)}`),
    create: (data: CreatePayload<Budget>) => post<Budget>("/budgets", data),
    update: (data: UpdatePayload<Budget>) => patch<Budget>(`/budgets/${data.id}`, data),
    delete: (id: number) => del<void>(`/budgets/${id}`),
  },

  dashboard: {
    overview: (params: { month: number; year: number }) =>
      get<DashboardOverview>(`/dashboard/overview${buildQuery(params)}`),
  },

  ai: {
    chat: (data: { message: string; history?: { role: string; content: string }[] }) =>
      post<{ role: string; content: string }>("/ai/chat", data),
  },

  reports: {
    monthly: (params: { month: number; year: number }) => get<MonthlyReport>(`/reports/monthly${buildQuery(params)}`),
    financialYear: (params: { year: number }) =>
      get<FinancialYearReport>(`/reports/financial_year${buildQuery(params)}`),
  },

  investments: {
    list: (params: { assetClass?: string; status?: string } = {}) =>
      get<{
        investments: Investment[];
        summary: {
          total_invested: string;
          current_value: string;
          total_pnl: string;
          count: number;
        };
      }>(`/investments${buildQuery(params)}`),
    create: (data: CreatePayload<Investment>) => post<Investment>("/investments", data),
    update: (data: UpdatePayload<Investment>) => patch<Investment>(`/investments/${data.id}`, data),
    delete: (id: number) => del<void>(`/investments/${id}`),
  },

  tax: {
    itrSummary: (params: { financialYear?: number } = {}) =>
      get<ItrSummary>(`/tax/itr_summary${buildQuery(params)}`),
  },
};
