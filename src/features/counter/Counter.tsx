import { useEffect } from 'react';
import { useAppDispatch, useAppSelector } from '@/hooks';
import { increment, decrement, reset, selectCount } from './counterSlice';
import { Logger } from '@/utils/logging';

// View - Renders state and dispatches intents
export function Counter() {
  const count = useAppSelector(selectCount);
  const dispatch = useAppDispatch();

  // Log component mount/unmount at trace level
  useEffect(() => {
    Logger.trace(Logger.Categories.UI, 'Counter component mounted');
    return () => {
      Logger.trace(Logger.Categories.UI, 'Counter component unmounted');
    };
  }, []);

  // Log state changes at debug level
  useEffect(() => {
    Logger.debug(Logger.Categories.STORE, 'Counter state changed:', { count });
  }, [count]);

  const handleIncrement = () => {
    Logger.info(Logger.Categories.UI, 'User clicked increment button');
    Logger.trace(Logger.Categories.STORE, 'Dispatching increment action');
    dispatch(increment());
    Logger.debug(Logger.Categories.STORE, 'Increment action dispatched, new count will be:', count + 1);
  };

  const handleDecrement = () => {
    Logger.info(Logger.Categories.UI, 'User clicked decrement button');
    Logger.trace(Logger.Categories.STORE, 'Dispatching decrement action');

    // Demonstrate warning when count goes negative
    if (count <= 0) {
      Logger.warn(Logger.Categories.UI, 'Counter going negative:', { currentCount: count, newCount: count - 1 });
    }

    dispatch(decrement());
    Logger.debug(Logger.Categories.STORE, 'Decrement action dispatched, new count will be:', count - 1);
  };

  const handleReset = () => {
    Logger.info(Logger.Categories.UI, 'User clicked reset button');

    // Demonstrate error-like scenario (not a real error, just for demo)
    if (count === 0) {
      Logger.warn(Logger.Categories.UI, 'Reset called but counter already at 0');
    }

    Logger.trace(Logger.Categories.STORE, 'Dispatching reset action');
    dispatch(reset());
    Logger.debug(Logger.Categories.STORE, 'Reset action dispatched, count reset to 0');
  };

  return (
    <div className="flex flex-col items-center gap-4 p-6 rounded-lg border bg-card">
      <h2 className="text-2xl font-bold">Counter: {count}</h2>
      <div className="flex gap-2">
        <button
          onClick={handleDecrement}
          className="px-4 py-2 rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80"
        >
          -
        </button>
        <button
          onClick={handleIncrement}
          className="px-4 py-2 rounded-md bg-primary text-primary-foreground hover:bg-primary/80"
        >
          +
        </button>
        <button
          onClick={handleReset}
          className="px-4 py-2 rounded-md bg-destructive text-white hover:bg-destructive/80"
        >
          Reset
        </button>
      </div>
    </div>
  );
}
