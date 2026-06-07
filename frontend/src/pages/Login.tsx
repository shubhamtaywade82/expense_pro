import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router";
import { useAuth, AUTH_QUERY_KEY } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { IndianRupee, Receipt, TrendingUp, Shield } from "lucide-react";
import { api, ApiError } from "@/lib/api";

export default function Login() {
  const { isAuthenticated, isLoading } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [loginForm, setLoginForm] = useState({ email: "", password: "" });
  const [registerForm, setRegisterForm] = useState({ name: "", email: "", password: "" });
  const [error, setError] = useState<string | null>(null);

  const onAuthSuccess = (user: Awaited<ReturnType<typeof api.auth.me>>) => {
    setError(null);
    queryClient.setQueryData(AUTH_QUERY_KEY, user);
    navigate("/");
  };

  const loginMutation = useMutation({
    mutationFn: () => api.auth.login(loginForm.email, loginForm.password),
    onSuccess: onAuthSuccess,
    onError: (err) => setError(err instanceof ApiError ? err.message : "Something went wrong"),
  });

  const registerMutation = useMutation({
    mutationFn: () => api.auth.register(registerForm),
    onSuccess: onAuthSuccess,
    onError: (err) => setError(err instanceof ApiError ? err.message : "Something went wrong"),
  });

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-muted/20">
        <div className="animate-spin w-8 h-8 border-4 border-primary border-t-transparent rounded-full" />
      </div>
    );
  }

  if (isAuthenticated) {
    navigate("/");
    return null;
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-background via-muted/30 to-background p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-primary mb-4">
            <IndianRupee className="w-8 h-8 text-primary-foreground" />
          </div>
          <h1 className="text-3xl font-bold tracking-tight">ExpenseFlow</h1>
          <p className="text-muted-foreground mt-2">Smart expense management for your financial life</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Welcome</CardTitle>
            <CardDescription>Sign in to manage your expenses, bills, loans, and budgets</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Tabs defaultValue="login" onValueChange={() => setError(null)}>
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="login">Sign In</TabsTrigger>
                <TabsTrigger value="register">Create Account</TabsTrigger>
              </TabsList>

              <TabsContent value="login" className="space-y-4 pt-4">
                <form
                  className="space-y-4"
                  onSubmit={(e) => {
                    e.preventDefault();
                    loginMutation.mutate();
                  }}
                >
                  <div className="space-y-2">
                    <Label htmlFor="login-email">Email</Label>
                    <Input
                      id="login-email"
                      type="email"
                      required
                      value={loginForm.email}
                      onChange={(e) => setLoginForm((f) => ({ ...f, email: e.target.value }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="login-password">Password</Label>
                    <Input
                      id="login-password"
                      type="password"
                      required
                      value={loginForm.password}
                      onChange={(e) => setLoginForm((f) => ({ ...f, password: e.target.value }))}
                    />
                  </div>
                  <Button type="submit" className="w-full" size="lg" disabled={loginMutation.isPending}>
                    {loginMutation.isPending ? "Signing in..." : "Sign In"}
                  </Button>
                </form>
              </TabsContent>

              <TabsContent value="register" className="space-y-4 pt-4">
                <form
                  className="space-y-4"
                  onSubmit={(e) => {
                    e.preventDefault();
                    registerMutation.mutate();
                  }}
                >
                  <div className="space-y-2">
                    <Label htmlFor="register-name">Name</Label>
                    <Input
                      id="register-name"
                      required
                      value={registerForm.name}
                      onChange={(e) => setRegisterForm((f) => ({ ...f, name: e.target.value }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="register-email">Email</Label>
                    <Input
                      id="register-email"
                      type="email"
                      required
                      value={registerForm.email}
                      onChange={(e) => setRegisterForm((f) => ({ ...f, email: e.target.value }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="register-password">Password</Label>
                    <Input
                      id="register-password"
                      type="password"
                      required
                      minLength={8}
                      value={registerForm.password}
                      onChange={(e) => setRegisterForm((f) => ({ ...f, password: e.target.value }))}
                    />
                    <p className="text-xs text-muted-foreground">At least 8 characters</p>
                  </div>
                  <Button type="submit" className="w-full" size="lg" disabled={registerMutation.isPending}>
                    {registerMutation.isPending ? "Creating account..." : "Create Account"}
                  </Button>
                </form>
              </TabsContent>
            </Tabs>

            {error && <p className="text-sm text-destructive text-center">{error}</p>}

            <div className="grid grid-cols-3 gap-3 pt-4">
              <div className="text-center">
                <div className="w-10 h-10 rounded-lg bg-red-100 flex items-center justify-center mx-auto mb-2">
                  <Receipt className="w-5 h-5 text-red-600" />
                </div>
                <p className="text-xs text-muted-foreground">Track Expenses</p>
              </div>
              <div className="text-center">
                <div className="w-10 h-10 rounded-lg bg-green-100 flex items-center justify-center mx-auto mb-2">
                  <TrendingUp className="w-5 h-5 text-green-600" />
                </div>
                <p className="text-xs text-muted-foreground">Monitor Savings</p>
              </div>
              <div className="text-center">
                <div className="w-10 h-10 rounded-lg bg-blue-100 flex items-center justify-center mx-auto mb-2">
                  <Shield className="w-5 h-5 text-blue-600" />
                </div>
                <p className="text-xs text-muted-foreground">Secure Data</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
