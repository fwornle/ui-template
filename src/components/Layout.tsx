import { Outlet } from 'react-router-dom'
import { TopBar } from './layout/TopBar'
import { BottomBar } from './layout/BottomBar'
import { useState } from 'react'
import type { StatusType } from './layout/BottomBar'

interface LayoutProps {
  appName?: string;
  version?: string;
}

export function Layout({ appName = 'UI Template', version = '1.0.0' }: LayoutProps) {
  const [status] = useState<StatusType>('idle')
  const [statusMessage] = useState('')

  return (
    <div className="min-h-screen flex flex-col bg-background text-foreground">
      <TopBar
        appName={appName}
        className="sticky top-0 z-50"
      />

      <main className="flex-1 w-full">
        <div className="container mx-auto px-4 py-6 md:px-6 lg:px-8 max-w-7xl">
          <Outlet />
        </div>
      </main>

      <BottomBar
        className="sticky bottom-0 z-50"
        status={status}
        statusMessage={statusMessage}
        version={version}
      />
    </div>
  )
}
