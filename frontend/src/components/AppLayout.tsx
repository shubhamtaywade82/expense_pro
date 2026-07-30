import { useState } from "react";
import { Link, useLocation } from "react-router";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
  LayoutDashboard,
  Receipt,
  FileText,
  Landmark,
  Target,
  PiggyBank,
  Wallet,
  BarChart3,
  Tags,
  LogOut,
  ChevronLeft,
  ChevronRight,
  Menu,
  X,
  IndianRupee,
  Sparkles,
  TrendingUp,
  FileBadge,
  LineChart,
} from "lucide-react";

const navItems = [
  { path: "/", label: "Dashboard", icon: LayoutDashboard },
  { path: "/expenses", label: "Expenses", icon: Receipt },
  { path: "/bills", label: "Monthly Bills", icon: FileText },
  { path: "/loans", label: "Loans & EMIs", icon: Landmark },
  { path: "/debt-planner", label: "Debt Planner", icon: Target },
  { path: "/income", label: "Income", icon: Wallet },
  { path: "/budget", label: "Budget", icon: PiggyBank },
  { path: "/investments", label: "Investments", icon: TrendingUp },
  { path: "/dhan", label: "Dhan Trading", icon: LineChart },
  { path: "/itr", label: "ITR & Tax", icon: FileBadge },
  { path: "/reports", label: "Reports", icon: BarChart3 },
  { path: "/categories", label: "Categories", icon: Tags },
  { path: "/ai-assistant", label: "AI Assistant", icon: Sparkles },
];

export function AppLayout({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const location = useLocation();
  const { user, logout } = useAuth();

  const userInitials = user?.name
    ? user.name
        .split(" ")
        .map((n: string) => n[0])
        .join("")
        .toUpperCase()
        .slice(0, 2)
    : "U";

  return (
    <div className="flex h-screen bg-background relative overflow-hidden">
      {/* Ambient background meshes */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] bg-primary/10 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-emerald-500/5 rounded-full blur-[120px] pointer-events-none" />

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Mobile sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 bg-card/90 backdrop-blur-xl border-r border-border/40 shadow-2xl transform transition-transform duration-300 lg:hidden ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex items-center justify-between p-4 border-b border-border/40">
          <Link to="/" className="flex items-center gap-2" onClick={() => setMobileOpen(false)}>
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-primary to-indigo-500 flex items-center justify-center shadow-lg shadow-primary/20">
              <IndianRupee className="w-5 h-5 text-primary-foreground" />
            </div>
            <span className="font-bold text-lg font-display tracking-tight text-gradient">ExpenseFlow</span>
          </Link>
          <Button variant="ghost" size="icon" onClick={() => setMobileOpen(false)} className="rounded-full">
            <X className="w-5 h-5" />
          </Button>
        </div>
        <nav className="p-3 space-y-1">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                onClick={() => setMobileOpen(false)}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                  isActive
                    ? "bg-gradient-to-r from-primary/15 to-primary/5 text-primary border-l-2 border-primary shadow-sm"
                    : "text-muted-foreground hover:bg-muted/50 hover:text-foreground"
                }`}
              >
                <item.icon className={`w-5 h-5 ${isActive ? "text-primary filter drop-shadow-[0_0_8px_rgba(99,102,241,0.5)]" : ""}`} />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-border/40 bg-card/50 backdrop-blur-md">
          <div className="flex items-center gap-3 mb-4">
            <Avatar className="w-9 h-9 border border-primary/20 shadow-md">
              <AvatarFallback className="text-xs bg-gradient-to-tr from-primary/20 to-indigo-500/10 text-primary font-semibold">{userInitials}</AvatarFallback>
            </Avatar>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold truncate text-foreground">{user?.name || "User"}</p>
              <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
            </div>
          </div>
          <Button variant="outline" size="sm" className="w-full rounded-xl hover:bg-destructive hover:text-destructive-foreground transition-all duration-200" onClick={logout}>
            <LogOut className="w-4 h-4 mr-2" />
            Sign Out
          </Button>
        </div>
      </aside>

      {/* Desktop sidebar */}
      <aside
        className={`hidden lg:flex flex-col border-r border-border/40 bg-card/45 backdrop-blur-xl transition-all duration-300 z-30 ${
          collapsed ? "w-20" : "w-64"
        }`}
      >
        <div className={`flex items-center ${collapsed ? "justify-center" : "justify-between"} p-4 border-b border-border/40 h-16`}>
          <Link to="/" className={`flex items-center gap-2.5 ${collapsed ? "hidden" : "flex"}`}>
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-primary to-indigo-500 flex items-center justify-center shadow-lg shadow-primary/25">
              <IndianRupee className="w-5 h-5 text-primary-foreground" />
            </div>
            <span className="font-bold text-lg font-display tracking-tight text-gradient">ExpenseFlow</span>
          </Link>
          {collapsed && (
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-primary to-indigo-500 flex items-center justify-center shadow-lg shadow-primary/25">
              <IndianRupee className="w-5 h-5 text-primary-foreground" />
            </div>
          )}
          <Button
            variant="ghost"
            size="icon"
            className={`${collapsed ? "hidden" : "flex"} h-8 w-8 rounded-lg hover:bg-muted/80`}
            onClick={() => setCollapsed(true)}
          >
            <ChevronLeft className="w-4 h-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className={`${collapsed ? "flex" : "hidden"} h-8 w-8 rounded-lg hover:bg-muted/80 mt-1`}
            onClick={() => setCollapsed(false)}
          >
            <ChevronRight className="w-4 h-4" />
          </Button>
        </div>

        <nav className="flex-1 p-3 space-y-1.5 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center ${collapsed ? "justify-center" : "gap-3"} px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                  isActive
                    ? "bg-gradient-to-r from-primary/12 to-primary/3 text-primary border-l-2 border-primary shadow-sm"
                    : "text-muted-foreground hover:bg-muted/30 hover:text-foreground hover:translate-x-0.5"
                }`}
                title={collapsed ? item.label : undefined}
              >
                <item.icon className={`w-5 h-5 flex-shrink-0 transition-transform ${isActive ? "text-primary filter drop-shadow-[0_0_8px_rgba(99,102,241,0.5)]" : "group-hover:scale-105"}`} />
                {!collapsed && <span className="font-sans font-medium">{item.label}</span>}
              </Link>
            );
          })}
        </nav>

        <div className={`p-4 border-t border-border/40 bg-card/20 backdrop-blur-md ${collapsed ? "px-3" : ""}`}>
          <div className={`flex items-center ${collapsed ? "justify-center" : "gap-3"} mb-4`}>
            <Avatar className="w-9 h-9 border border-primary/20 shadow-sm flex-shrink-0">
              <AvatarFallback className="text-xs bg-gradient-to-tr from-primary/20 to-indigo-500/10 text-primary font-semibold">{userInitials}</AvatarFallback>
            </Avatar>
            {!collapsed && (
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold truncate text-foreground">{user?.name || "User"}</p>
                <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
              </div>
            )}
          </div>
          <Button
            variant="outline"
            size={collapsed ? "icon" : "sm"}
            className={`${collapsed ? "w-9 h-9" : "w-full"} rounded-xl hover:bg-destructive hover:text-destructive-foreground transition-all duration-200`}
            onClick={logout}
            title="Sign Out"
          >
            <LogOut className="w-4 h-4" />
            {!collapsed && <span className="ml-2 font-medium">Sign Out</span>}
          </Button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-h-0 relative z-10">
        {/* Top bar */}
        <header className="flex-shrink-0 flex items-center justify-between px-4 py-3 bg-card/30 backdrop-blur-md border-b border-border/30 lg:px-6 h-16 z-20">
          <div className="flex items-center gap-3">
            <Button
              variant="ghost"
              size="icon"
              className="lg:hidden rounded-lg hover:bg-muted/80"
              onClick={() => setMobileOpen(true)}
            >
              <Menu className="w-5 h-5" />
            </Button>
            <h1 className="text-lg font-bold font-display tracking-tight text-foreground">
              {navItems.find((n) => n.path === location.pathname)?.label || "ExpenseFlow"}
            </h1>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 min-h-0 overflow-hidden p-4 lg:p-6 bg-transparent flex flex-col">
          {children}
        </main>
      </div>
    </div>
  );
}
