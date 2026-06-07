import type { ReactNode } from "react";
import { useAuth } from "@/hooks/useAuth";
import { LOGIN_PATH } from "@/const";

export function RequireAuth({ children }: { children: ReactNode }) {
  const { isLoading, isAuthenticated } = useAuth({ redirectOnUnauthenticated: true, redirectPath: LOGIN_PATH });

  if (isLoading || !isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-muted/20">
        <div className="animate-spin w-8 h-8 border-4 border-primary border-t-transparent rounded-full" />
      </div>
    );
  }

  return <>{children}</>;
}
