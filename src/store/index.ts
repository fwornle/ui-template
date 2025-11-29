import { configureStore } from '@reduxjs/toolkit'
import { useDispatch, useSelector } from 'react-redux'
import type { TypedUseSelectorHook } from 'react-redux'
import { counterReducer } from '@/features/counter'
import preferencesReducer from './slices/preferencesSlice'
import loggingReducer from './slices/loggingSlice'

export const store = configureStore({
  reducer: {
    counter: counterReducer,
    preferences: preferencesReducer,
    logging: loggingReducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: false,
    }),
})

export type RootState = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch

// Typed hooks for use throughout the app
export const useAppDispatch = () => useDispatch<AppDispatch>()
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector
