import { Counter } from '@/features/counter'
import { ApiStatus } from '@/features/api-status'

export function HomePage() {
  return (
    <div className="container mx-auto py-8">
      <h1 className="text-4xl font-bold mb-8 text-center">Welcome to UI Template</h1>
      <p className="text-muted-foreground text-center mb-8">
        A Vite + React + TypeScript template with Tailwind CSS, shadcn/ui, React Router, and Redux (MVI)
      </p>
      <div className="flex flex-col items-center gap-8">
        <Counter />
        <ApiStatus />
      </div>
    </div>
  )
}
