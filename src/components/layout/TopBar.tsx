import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Disclosure, DisclosureButton, DisclosurePanel, Menu as HeadlessMenu, MenuButton, MenuItems, MenuItem } from '@headlessui/react';
import { SettingsModal } from '../settings/SettingsModal';
import { LoggingControl } from '../ui/LoggingControl';
import { LoginModal } from '../auth/LoginModal';
import { Menu, X, Settings, FileText, Sun, Moon, LogOut, LogIn } from 'lucide-react';
import { useAppSelector, useAppDispatch } from '@/store';
import { updatePreferences } from '@/store/slices/preferencesSlice';
import { useAuth } from '@/hooks/useAuth';

interface TopBarProps {
  className?: string;
  appName?: string;
  navigation?: Array<{ name: string; href: string }>;
}

export function TopBar({
  className = '',
  appName = 'App Template',
  navigation = [
    { name: 'Home', href: '/' },
    { name: 'About', href: '/about' },
  ],
}: TopBarProps) {
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [showLoggingControl, setShowLoggingControl] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);

  const dispatch = useAppDispatch();
  const theme = useAppSelector(state => state.preferences.theme) || 'system';
  const { user, isAuthenticated, signOut } = useAuth();

  const toggleTheme = () => {
    const newTheme = theme === 'light' ? 'dark' : theme === 'dark' ? 'system' : 'light';
    dispatch(updatePreferences({ theme: newTheme }));
  };

  return (
    <>
      <Disclosure as="nav" className={`bg-primary-800 dark:bg-primary-900 ${className}`}>
        {({ open }) => (
          <>
            <div className="mx-auto px-2 sm:px-6 lg:px-8">
              <div className="relative flex h-16 items-center justify-between">
                <div className="absolute inset-y-0 left-0 flex items-center sm:hidden">
                  {/* Mobile menu button*/}
                  <DisclosureButton className="relative inline-flex items-center justify-center rounded-md p-2 text-gray-400 hover:bg-primary-700 hover:text-white focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white">
                    <span className="sr-only">Open main menu</span>
                    {open ? (
                      <X className="block h-5 w-5" aria-hidden="true" />
                    ) : (
                      <Menu className="block h-5 w-5" aria-hidden="true" />
                    )}
                  </DisclosureButton>
                </div>

                <div className="flex flex-1 items-center justify-start sm:items-stretch">
                  {/* Logo and Title */}
                  <Link to="/" className="flex flex-shrink-0 items-center">
                    <div className="h-8 w-8 bg-accent-500 rounded-full flex items-center justify-center">
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M12 2L2 7l10 5 10-5-10-5z" />
                        <path d="M2 17l10 5 10-5" />
                        <path d="M2 12l10 5 10-5" />
                      </svg>
                    </div>
                    <h1 className="ml-2 text-xl font-bold text-white hidden sm:block">{appName}</h1>
                  </Link>

                  {/* Desktop Navigation */}
                  <div className="hidden sm:ml-6 sm:flex sm:items-center sm:space-x-4">
                    {navigation.map((item) => (
                      <Link
                        key={item.name}
                        to={item.href}
                        className="text-gray-300 hover:bg-primary-700 hover:text-white rounded-md px-3 py-2 text-sm font-medium transition-colors"
                      >
                        {item.name}
                      </Link>
                    ))}
                  </div>
                </div>

                {/* Control Buttons */}
                <div className="absolute inset-y-0 right-0 flex items-center space-x-2 pr-2 sm:static sm:inset-auto sm:ml-6 sm:pr-0">
                  {/* Theme Toggle Button */}
                  <button
                    type="button"
                    className="rounded-full bg-primary-800 dark:bg-primary-900 p-1 text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-primary-800"
                    onClick={toggleTheme}
                    title={`Current: ${theme}. Click to toggle.`}
                  >
                    <span className="sr-only">Toggle theme</span>
                    {theme === 'dark' ? (
                      <Moon className="h-6 w-6" />
                    ) : (
                      <Sun className="h-6 w-6" />
                    )}
                  </button>

                  {/* Logging Control Button */}
                  <button
                    type="button"
                    className="rounded-full bg-primary-800 dark:bg-primary-900 p-1 text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-primary-800"
                    onClick={() => setShowLoggingControl(true)}
                    title="Logging Configuration"
                  >
                    <span className="sr-only">Open logging configuration</span>
                    <FileText className="h-6 w-6" />
                  </button>

                  {/* Settings Button */}
                  <button
                    type="button"
                    className="rounded-full bg-primary-800 dark:bg-primary-900 p-1 text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-primary-800"
                    onClick={() => setShowSettingsModal(true)}
                    title="Settings"
                  >
                    <span className="sr-only">Open settings</span>
                    <Settings className="h-6 w-6" />
                  </button>

                  {/* Auth Button / User Menu */}
                  {isAuthenticated && user ? (
                    <HeadlessMenu as="div" className="relative">
                      <MenuButton className="flex items-center rounded-full bg-primary-800 dark:bg-primary-900 p-1 text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-primary-800">
                        <span className="sr-only">Open user menu</span>
                        <div className="h-6 w-6 rounded-full bg-accent-500 flex items-center justify-center text-white text-xs font-medium">
                          {user.name?.charAt(0).toUpperCase() || user.email?.charAt(0).toUpperCase() || 'U'}
                        </div>
                      </MenuButton>
                      <MenuItems className="absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white dark:bg-gray-800 py-1 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                        <div className="px-4 py-2 border-b border-gray-200 dark:border-gray-700">
                          <p className="text-sm font-medium text-gray-900 dark:text-white truncate">
                            {user.name || 'User'}
                          </p>
                          <p className="text-xs text-gray-500 dark:text-gray-400 truncate">
                            {user.email}
                          </p>
                        </div>
                        <MenuItem>
                          {({ focus }) => (
                            <button
                              onClick={() => signOut()}
                              className={`${
                                focus ? 'bg-gray-100 dark:bg-gray-700' : ''
                              } flex w-full items-center px-4 py-2 text-sm text-gray-700 dark:text-gray-300`}
                            >
                              <LogOut className="mr-2 h-4 w-4" />
                              Sign out
                            </button>
                          )}
                        </MenuItem>
                      </MenuItems>
                    </HeadlessMenu>
                  ) : (
                    <button
                      type="button"
                      className="rounded-full bg-primary-800 dark:bg-primary-900 p-1 text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-2 focus:ring-offset-primary-800"
                      onClick={() => setShowLoginModal(true)}
                      title="Sign In"
                    >
                      <span className="sr-only">Sign in</span>
                      <LogIn className="h-6 w-6" />
                    </button>
                  )}
                </div>
              </div>
            </div>

            {/* Mobile menu */}
            <DisclosurePanel className="sm:hidden">
              <div className="space-y-1 px-2 pb-3 pt-2">
                {navigation.map((item) => (
                  <Link
                    key={item.name}
                    to={item.href}
                    className="block rounded-md px-3 py-2 text-base font-medium text-white hover:bg-primary-700"
                  >
                    {item.name}
                  </Link>
                ))}
              </div>
            </DisclosurePanel>
          </>
        )}
      </Disclosure>

      {/* Settings Modal */}
      <SettingsModal
        isOpen={showSettingsModal}
        onClose={() => setShowSettingsModal(false)}
      />

      {/* Logging Control Dialog */}
      <LoggingControl
        isOpen={showLoggingControl}
        onClose={() => setShowLoggingControl(false)}
      />

      {/* Login Modal */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
      />
    </>
  );
}

export default TopBar;
