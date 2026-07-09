-- Migration 023: Update transactions table check constraint for type

-- Drop existing constraint
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

-- Add updated constraint including 'cancel_commission'
ALTER TABLE public.transactions
ADD CONSTRAINT transactions_type_check
CHECK (type IN ('earning', 'commission', 'withdrawal', 'refund', 'cancel_commission'));
