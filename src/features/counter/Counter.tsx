import { useAppDispatch, useAppSelector } from '@/hooks'
import { increment, decrement, reset, selectCount } from './counterSlice'

// View - Renders state and dispatches intents
export function Counter() {
  const count = useAppSelector(selectCount)
  const dispatch = useAppDispatch()

  return (
    <div className="flex flex-col items-center gap-4 p-6 rounded-lg border bg-card">
      <h2 className="text-2xl font-bold">Counter: {count}</h2>
      <div className="flex gap-2">
        <button
          onClick={() => dispatch(decrement())}
          className="px-4 py-2 rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80"
        >
          -
        </button>
        <button
          onClick={() => dispatch(increment())}
          className="px-4 py-2 rounded-md bg-primary text-primary-foreground hover:bg-primary/80"
        >
          +
        </button>
        <button
          onClick={() => dispatch(reset())}
          className="px-4 py-2 rounded-md bg-destructive text-white hover:bg-destructive/80"
        >
          Reset
        </button>
      </div>
    </div>
  )
}
