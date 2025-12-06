import { Outlet } from 'react-router-dom'
import { TopBar } from './layout/TopBar'
import { BottomBar } from './layout/BottomBar'
import { SidebarMenu } from './layout/SidebarMenu'
import { useState } from 'react'
import type { StatusType } from './layout/BottomBar'

// App version and environment from Vite define and env
const appVersion = __APP_VERSION__;
const appEnvironment = import.meta.env.VITE_ENVIRONMENT || 'local';

interface LayoutProps {
  appName?: string;
}

export function Layout({ appName = 'UI Template' }: LayoutProps) {
  const [status] = useState<StatusType>('idle')
  const [statusMessage] = useState('')

  return (
    <div className="min-h-screen flex flex-col bg-background text-foreground">
      <TopBar
        appName={appName}
        className="sticky top-0 z-50"
      />

      {/* Sidebar Menu - opens on left edge hover, closes on click outside */}
      <SidebarMenu />

      <main className="flex-1 w-full">
        <div className="container mx-auto px-4 py-6 md:px-6 lg:px-8 max-w-7xl">
          <Outlet />
        </div>
      </main>

      <BottomBar
        className="sticky bottom-0 z-50"
        status={status}
        statusMessage={statusMessage}
        version={appVersion}
        environment={appEnvironment}
      />
    </div>
  )
}
