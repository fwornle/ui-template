import { Amplify } from 'aws-amplify';
import {
  signIn,
  signUp,
  confirmSignUp,
  signOut,
  resendSignUpCode,
  resetPassword,
  confirmResetPassword,
  getCurrentUser,
  fetchUserAttributes,
  fetchAuthSession,
} from '@aws-amplify/auth';

interface CognitoConfig {
  userPoolId: string;
  userPoolClientId: string;
  region: string;
}

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface SignUpData {
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
}

export interface ConfirmSignUpData {
  username: string;
  confirmationCode: string;
}

export interface ForgotPasswordData {
  username: string;
}

export interface ResetPasswordData {
  username: string;
  confirmationCode: string;
  newPassword: string;
}

export interface CognitoUser {
  userId: string;
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  emailVerified: boolean;
  attributes: Record<string, unknown>;
}

export interface AuthTokens {
  accessToken: string;
  idToken: string;
  refreshToken: string;
  tokenType: string;
  expiresAt: number;
}

class CognitoService {
  private isConfigured = false;

  constructor() {
    this.configure();
  }

  private configure(): void {
    const config: CognitoConfig = {
      userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID || '',
      userPoolClientId: import.meta.env.VITE_COGNITO_USER_POOL_CLIENT_ID || '',
      region: import.meta.env.VITE_COGNITO_REGION || 'eu-central-1',
    };

    if (!config.userPoolId || !config.userPoolClientId) {
      console.warn(
        'Cognito configuration missing. Authentication will not work in local development without env variables.'
      );
      return;
    }

    Amplify.configure({
      Auth: {
        Cognito: {
          userPoolId: config.userPoolId,
          userPoolClientId: config.userPoolClientId,
          signUpVerificationMethod: 'code',
          loginWith: {
            email: true,
            username: false,
            phone: false,
          },
        },
      },
    });

    this.isConfigured = true;
  }

  private ensureConfigured(): void {
    if (!this.isConfigured) {
      throw new Error('Cognito service is not properly configured');
    }
  }

  async signIn(
    credentials: LoginCredentials
  ): Promise<{
    user: CognitoUser;
    tokens: AuthTokens;
  }> {
    this.ensureConfigured();

    try {
      const signInResult = await signIn({
        username: credentials.username,
        password: credentials.password,
      });

      if (signInResult.isSignedIn) {
        const [currentUser, session, userAttributes] = await Promise.all([
          getCurrentUser(),
          fetchAuthSession(),
          fetchUserAttributes(),
        ]);

        const userWithAttributes = {
          ...currentUser,
          attributes: userAttributes,
        };

        const user = this.mapUserAttributes(userWithAttributes);
        const tokens = this.extractTokens(session);

        return { user, tokens };
      } else {
        const nextStep = signInResult.nextStep;

        switch (nextStep?.signInStep) {
          case 'CONFIRM_SIGN_UP':
            throw new Error(
              'Your email address has not been verified yet. Please check your email for a verification code.'
            );
          case 'RESET_PASSWORD':
            throw new Error(
              'Password reset required. Please use the "Forgot password?" link to reset your password.'
            );
          default:
            throw new Error(
              `Sign in requires additional verification (${nextStep?.signInStep || 'unknown'}).`
            );
        }
      }
    } catch (error: unknown) {
      const err = error as { name?: string; message?: string };

      if (err.name === 'UserNotConfirmedException') {
        throw new Error(
          'Your email address has not been verified. Please check your email for a verification code.'
        );
      } else if (err.name === 'NotAuthorizedException') {
        throw new Error(
          'Invalid email or password. Please check your credentials and try again.'
        );
      } else if (err.name === 'UserNotFoundException') {
        throw new Error('No account found with this email address. Please sign up first.');
      } else if (err.name === 'TooManyRequestsException') {
        throw new Error('Too many sign in attempts. Please wait a moment and try again.');
      } else {
        throw new Error(err.message || 'Sign in failed. Please try again.');
      }
    }
  }

  async signUp(
    userData: SignUpData
  ): Promise<{ userId: string; codeDeliveryDetails?: unknown }> {
    this.ensureConfigured();

    try {
      const signUpResult = await signUp({
        username: userData.email,
        password: userData.password,
        options: {
          userAttributes: {
            email: userData.email,
            given_name: userData.firstName || '',
            family_name: userData.lastName || '',
          },
        },
      });

      return {
        userId: signUpResult.userId || userData.email,
        codeDeliveryDetails: signUpResult.nextStep,
      };
    } catch (error: unknown) {
      const err = error as { message?: string };
      throw new Error(err.message || 'Sign up failed');
    }
  }

  async confirmSignUp(data: ConfirmSignUpData): Promise<void> {
    this.ensureConfigured();

    try {
      await confirmSignUp({
        username: data.username,
        confirmationCode: data.confirmationCode,
      });
    } catch (error: unknown) {
      const err = error as { message?: string };
      throw new Error(err.message || 'Email confirmation failed');
    }
  }

  async resendConfirmationCode(username: string): Promise<unknown> {
    this.ensureConfigured();

    try {
      const result = await resendSignUpCode({ username });
      return result;
    } catch (error: unknown) {
      const err = error as { message?: string };
      throw new Error(err.message || 'Failed to resend confirmation code');
    }
  }

  async forgotPassword(data: ForgotPasswordData): Promise<unknown> {
    this.ensureConfigured();

    try {
      const result = await resetPassword({ username: data.username });
      return result.nextStep;
    } catch (error: unknown) {
      const err = error as { message?: string };
      throw new Error(err.message || 'Failed to initiate password reset');
    }
  }

  async confirmResetPassword(data: ResetPasswordData): Promise<void> {
    this.ensureConfigured();

    try {
      await confirmResetPassword({
        username: data.username,
        confirmationCode: data.confirmationCode,
        newPassword: data.newPassword,
      });
    } catch (error: unknown) {
      const err = error as { message?: string };
      throw new Error(err.message || 'Password reset failed');
    }
  }

  async signOut(): Promise<void> {
    this.ensureConfigured();

    try {
      await signOut();
    } catch (error) {
      console.error('Sign out error:', error);
    }
  }

  async getCurrentAuthenticatedUser(): Promise<{
    user: CognitoUser;
    tokens: AuthTokens;
  } | null> {
    this.ensureConfigured();

    try {
      const [currentUser, session, userAttributes] = await Promise.all([
        getCurrentUser(),
        fetchAuthSession(),
        fetchUserAttributes(),
      ]);

      if (!currentUser || !session.tokens) {
        return null;
      }

      const userWithAttributes = {
        ...currentUser,
        attributes: userAttributes,
      };

      const user = this.mapUserAttributes(userWithAttributes);
      const tokens = this.extractTokens(session);

      return { user, tokens };
    } catch {
      return null;
    }
  }

  async refreshAuthSession(): Promise<AuthTokens> {
    this.ensureConfigured();

    try {
      const session = await fetchAuthSession({ forceRefresh: true });
      return this.extractTokens(session);
    } catch (error: unknown) {
      const err = error as { message?: string };
      throw new Error(err.message || 'Session refresh failed');
    }
  }

  private mapUserAttributes(user: {
    userId?: string;
    username?: string;
    signInDetails?: { loginId?: string };
    attributes?: Partial<Record<string, string | undefined>>;
  }): CognitoUser {
    const userAttributes = user.attributes || {};

    const getAttributeValue = (attributeName: string): string => {
      if (typeof userAttributes === 'object') {
        return userAttributes[attributeName] || '';
      }
      return '';
    };

    return {
      userId: user.userId || user.username || '',
      username: user.username || '',
      email: user.signInDetails?.loginId || getAttributeValue('email') || '',
      firstName: getAttributeValue('given_name') || '',
      lastName: getAttributeValue('family_name') || '',
      emailVerified: getAttributeValue('email_verified') === 'true',
      attributes: userAttributes || {},
    };
  }

  private extractTokens(session: {
    tokens?: {
      accessToken?: { toString(): string; payload?: { exp?: number } };
      idToken?: { toString(): string };
      refreshToken?: { toString(): string };
    };
  }): AuthTokens {
    const tokens = session.tokens;
    if (!tokens) {
      throw new Error('No tokens available in session');
    }

    return {
      accessToken: tokens.accessToken?.toString() || '',
      idToken: tokens.idToken?.toString() || '',
      refreshToken: tokens.refreshToken?.toString() || '',
      tokenType: 'Bearer',
      expiresAt: (tokens.accessToken?.payload?.exp || 0) * 1000 || Date.now() + 3600000,
    };
  }

  getIsConfigured(): boolean {
    return this.isConfigured;
  }
}

export const cognitoService = new CognitoService();
