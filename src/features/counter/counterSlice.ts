import { createSlice, type PayloadAction } from '@reduxjs/toolkit'

// Model - State shape
interface CounterState {
  value: number
  status: 'idle' | 'loading' | 'failed'
}

const initialState: CounterState = {
  value: 0,
  status: 'idle',
}

// Intent handlers - Reducers that process user intentions
export const counterSlice = createSlice({
  name: 'counter',
  initialState,
  reducers: {
    increment: (state) => {
      state.value += 1
    },
    decrement: (state) => {
      state.value -= 1
    },
    incrementByAmount: (state, action: PayloadAction<number>) => {
      state.value += action.payload
    },
    reset: (state) => {
      state.value = 0
    },
  },
})

// Intent creators - Actions that represent user intentions
export const { increment, decrement, incrementByAmount, reset } = counterSlice.actions

// Selectors - Functions to derive data from state
export const selectCount = (state: { counter: CounterState }) => state.counter.value
export const selectStatus = (state: { counter: CounterState }) => state.counter.status

export default counterSlice.reducer
