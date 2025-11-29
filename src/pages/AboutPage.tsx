export function AboutPage() {
  return (
    <div className="container mx-auto py-8">
      <h1 className="text-4xl font-bold mb-8 text-center">About</h1>
      <div className="max-w-2xl mx-auto prose prose-neutral dark:prose-invert">
        <p className="text-muted-foreground">
          This is a modern React template featuring:
        </p>
        <ul className="list-disc list-inside text-muted-foreground space-y-2 mt-4">
          <li>Vite for fast development and builds</li>
          <li>TypeScript for type safety</li>
          <li>Tailwind CSS v4 for styling</li>
          <li>shadcn/ui for accessible components</li>
          <li>React Router for client-side routing</li>
          <li>Redux Toolkit with MVI architecture</li>
        </ul>
      </div>
    </div>
  )
}
