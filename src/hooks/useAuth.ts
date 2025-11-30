import { useEffect, useCallback } from 'react';
import { useAppDispatch, useAppSelector } from '@/store';
import {
  loginUser,
  signUpUser,
  confirmSignUp,
  resendConfirmationCode,
  forgotPassword,
  resetPassword,
  logout,
  checkAuthStatus,
  clearError,
  clearPendingVerification,
  type User,
} from '@/store/slices/authSlice';
import type {
  LoginCredentials,
  SignUpData,
  ConfirmSignUpData,
  ForgotPasswordData,
  ResetPasswordData,
} from '@/services/auth/cognitoService';

export interface UseAuthReturn {
  // State
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  pendingVerification: { username: string; email: string } | null;

  // Actions
  login: (credentials: LoginCredentials) => Promise<void>;
  signUp: (userData: SignUpData) => Promise<void>;
  confirmEmail: (data: ConfirmSignUpData) => Promise<void>;
  resendCode: (username: string) => Promise<void>;
  sendPasswordReset: (data: ForgotPasswordData) => Promise<void>;
  confirmPasswordReset: (data: ResetPasswordData) => Promise<void>;
  signOut: () => Promise<void>;
  checkAuth: () => Promise<void>;
  clearAuthError: () => void;
  clearVerification: () => void;
}

export function useAuth(): UseAuthReturn {
  const dispatch = useAppDispatch();
  const { user, isAuthenticated, isLoading, error, pendingVerification } = useAppSelector(
    (state) => state.auth
  );

  // Check auth status on mount
  useEffect(() => {
    dispatch(checkAuthStatus());
  }, [dispatch]);

  const login = useCallback(
    async (credentials: LoginCredentials) => {
      await dispatch(loginUser(credentials)).unwrap();
    },
    [dispatch]
  );

  const signUp = useCallback(
    async (userData: SignUpData) => {
      await dispatch(signUpUser(userData)).unwrap();
    },
    [dispatch]
  );

  const confirmEmail = useCallback(
    async (data: ConfirmSignUpData) => {
      await dispatch(confirmSignUp(data)).unwrap();
    },
    [dispatch]
  );

  const resendCode = useCallback(
    async (username: string) => {
      await dispatch(resendConfirmationCode(username)).unwrap();
    },
    [dispatch]
  );

  const sendPasswordReset = useCallback(
    async (data: ForgotPasswordData) => {
      await dispatch(forgotPassword(data)).unwrap();
    },
    [dispatch]
  );

  const confirmPasswordReset = useCallback(
    async (data: ResetPasswordData) => {
      await dispatch(resetPassword(data)).unwrap();
    },
    [dispatch]
  );

  const signOut = useCallback(async () => {
    await dispatch(logout()).unwrap();
  }, [dispatch]);

  const checkAuth = useCallback(async () => {
    await dispatch(checkAuthStatus()).unwrap();
  }, [dispatch]);

  const clearAuthError = useCallback(() => {
    dispatch(clearError());
  }, [dispatch]);

  const clearVerification = useCallback(() => {
    dispatch(clearPendingVerification());
  }, [dispatch]);

  return {
    // State
    user,
    isAuthenticated,
    isLoading,
    error,
    pendingVerification,

    // Actions
    login,
    signUp,
    confirmEmail,
    resendCode,
    sendPasswordReset,
    confirmPasswordReset,
    signOut,
    checkAuth,
    clearAuthError,
    clearVerification,
  };
}

export default useAuth;
