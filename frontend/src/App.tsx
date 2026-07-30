import { Routes, Route } from "react-router";
import { AppLayout } from "./components/AppLayout";
import { RequireAuth } from "./components/RequireAuth";
import Dashboard from "./pages/Dashboard";
import Expenses from "./pages/Expenses";
import Bills from "./pages/Bills";
import Loans from "./pages/Loans";
import Income from "./pages/Income";
import Budget from "./pages/Budget";
import Reports from "./pages/Reports";
import Categories from "./pages/Categories";
import AiAssistant from "./pages/AiAssistant";
import Investments from "./pages/Investments";
import ITR from "./pages/ITR";
import Brokers from "./pages/Brokers";
import DebtPlanner from "./pages/DebtPlanner";
import Login from "./pages/Login";
import NotFound from "./pages/NotFound";
import TaxDocuments from "./pages/TaxDocuments";
import ItrFiling from "./pages/ItrFiling";

function LayoutWrapper({ children }: { children: React.ReactNode }) {
  return (
    <RequireAuth>
      <AppLayout>{children}</AppLayout>
    </RequireAuth>
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/"
        element={
          <LayoutWrapper>
            <Dashboard />
          </LayoutWrapper>
        }
      />
      <Route
        path="/expenses"
        element={
          <LayoutWrapper>
            <Expenses />
          </LayoutWrapper>
        }
      />
      <Route
        path="/bills"
        element={
          <LayoutWrapper>
            <Bills />
          </LayoutWrapper>
        }
      />
      <Route
        path="/loans"
        element={
          <LayoutWrapper>
            <Loans />
          </LayoutWrapper>
        }
      />
      <Route
        path="/income"
        element={
          <LayoutWrapper>
            <Income />
          </LayoutWrapper>
        }
      />
      <Route
        path="/budget"
        element={
          <LayoutWrapper>
            <Budget />
          </LayoutWrapper>
        }
      />
      <Route
        path="/reports"
        element={
          <LayoutWrapper>
            <Reports />
          </LayoutWrapper>
        }
      />
      <Route
        path="/categories"
        element={
          <LayoutWrapper>
            <Categories />
          </LayoutWrapper>
        }
      />
      <Route
        path="/ai-assistant"
        element={
          <LayoutWrapper>
            <AiAssistant />
          </LayoutWrapper>
        }
      />
      <Route
        path="/investments"
        element={
          <LayoutWrapper>
            <Investments />
          </LayoutWrapper>
        }
      />
      <Route
        path="/itr"
        element={
          <LayoutWrapper>
            <ITR />
          </LayoutWrapper>
        }
      />
      <Route
        path="/brokers"
        element={
          <LayoutWrapper>
            <Brokers />
          </LayoutWrapper>
        }
      />
      <Route
        path="/debt-planner"
        element={
          <LayoutWrapper>
            <DebtPlanner />
          </LayoutWrapper>
        }
      />
      <Route
        path="/tax-documents"
        element={
          <LayoutWrapper>
            <TaxDocuments />
          </LayoutWrapper>
        }
      />
      <Route
        path="/itr-filing"
        element={
          <LayoutWrapper>
            <ItrFiling />
          </LayoutWrapper>
        }
      />
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}
