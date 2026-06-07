import type {
  Budget,
  Category,
  DashboardOverview,
  EmiPayment,
  Expense,
  FinancialYearReport,
  Income,
  Loan,
  LoanDetail,
  MonthlyBill,
  MonthlyReport,
  User,
} from "@/types";

const BASE_URL = "/api/v1";

export class ApiError extends Error {}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
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

function buildQuery(params: Record<string, unknown>): string {
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
    login: (email: string, password: string) => post<User>("/session", { email, password }),
    logout: () => del<void>("/session"),
    register: (data: { name: string; email: string; password: string }) =>
      post<User>("/registrations", { user: data }),
  },

  categories: {
    list: () => get<Category[]>("/categories"),
    create: (data: Partial<Category>) => post<Category>("/categories", data),
    update: ({ id, ...data }: Partial<Category> & { id: number }) => patch<Category>(`/categories/${id}`, data),
    delete: (id: number) => del<void>(`/categories/${id}`),
  },

  expenses: {
    list: (params: { month?: number; year?: number; categoryId?: number; search?: string } = {}) =>
      get<Expense[]>(`/expenses${buildQuery(params)}`),
    create: (data: Record<string, unknown>) => post<Expense>("/expenses", data),
    update: ({ id, ...data }: { id: number } & Record<string, unknown>) => patch<Expense>(`/expenses/${id}`, data),
    delete: (id: number) => del<void>(`/expenses/${id}`),
  },

  incomes: {
    list: (params: { month: number; year: number }) => get<Income[]>(`/incomes${buildQuery(params)}`),
    summary: (params: { month: number; year: number }) =>
      get<{ total: string; count: number }>(`/incomes/summary${buildQuery(params)}`),
    create: (data: Record<string, unknown>) => post<Income>("/incomes", data),
    update: ({ id, ...data }: { id: number } & Record<string, unknown>) => patch<Income>(`/incomes/${id}`, data),
    delete: (id: number) => del<void>(`/incomes/${id}`),
    toggleReceived: (id: number) => patch<Income>(`/incomes/${id}/toggle_received`),
  },

  bills: {
    list: () => get<MonthlyBill[]>("/bills"),
    create: (data: Record<string, unknown>) => post<MonthlyBill>("/bills", data),
    update: ({ id, ...data }: { id: number } & Record<string, unknown>) => patch<MonthlyBill>(`/bills/${id}`, data),
    delete: (id: number) => del<void>(`/bills/${id}`),
    togglePaid: (id: number) => patch<MonthlyBill>(`/bills/${id}/toggle_paid`),
  },

  loans: {
    list: () => get<Loan[]>("/loans"),
    byId: (id: number) => get<LoanDetail>(`/loans/${id}`),
    create: (data: Record<string, unknown>) => post<Loan>("/loans", data),
    delete: (id: number) => del<void>(`/loans/${id}`),
    payEmi: ({ emiId, paidDate }: { emiId: number; paidDate?: string }) =>
      patch<EmiPayment>(`/emi_payments/${emiId}/pay`, { paidDate }),
  },

  budgets: {
    list: (params: { month: number; year: number }) => get<Budget[]>(`/budgets${buildQuery(params)}`),
    create: (data: Record<string, unknown>) => post<Budget>("/budgets", data),
    update: ({ id, ...data }: { id: number } & Record<string, unknown>) => patch<Budget>(`/budgets/${id}`, data),
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
};
