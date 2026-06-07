import { useCallback, useEffect, useMemo } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router";
import { LOGIN_PATH } from "@/const";
import { api, ApiError } from "@/lib/api";

type UseAuthOptions = {
  redirectOnUnauthenticated?: boolean;
  redirectPath?: string;
};

export const AUTH_QUERY_KEY = ["auth", "me"] as const;

export function useAuth(options?: UseAuthOptions) {
  const { redirectOnUnauthenticated = false, redirectPath = LOGIN_PATH } = options ?? {};

  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const {
    data: user,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: AUTH_QUERY_KEY,
    queryFn: async () => {
      try {
        return await api.auth.me();
      } catch (err) {
        if (err instanceof ApiError) return null;
        throw err;
      }
    },
    staleTime: 1000 * 60 * 5,
    retry: false,
  });

  const logoutMutation = useMutation({
    mutationFn: () => api.auth.logout(),
    onSuccess: async () => {
      await queryClient.invalidateQueries();
      queryClient.setQueryData(AUTH_QUERY_KEY, null);
      navigate(redirectPath);
    },
  });

  const logout = useCallback(() => logoutMutation.mutate(), [logoutMutation]);

  useEffect(() => {
    if (redirectOnUnauthenticated && !isLoading && !user) {
      const currentPath = window.location.pathname;
      if (currentPath !== redirectPath) {
        navigate(redirectPath);
      }
    }
  }, [redirectOnUnauthenticated, isLoading, user, navigate, redirectPath]);

  return useMemo(
    () => ({
      user: user ?? null,
      isAuthenticated: !!user,
      isLoading: isLoading || logoutMutation.isPending,
      error,
      logout,
      refresh: refetch,
    }),
    [user, isLoading, logoutMutation.isPending, error, logout, refetch],
  );
}
