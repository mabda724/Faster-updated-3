-- Add settled_amount column to provider_profiles
-- This tracks the total COMMISSION that has been settled (paid) by the provider
-- Provider keeps net profit (services total - commission) and only pays commission to app
-- When admin verifies a settlement, this amount is increased
-- The dashboard will show: commission remaining = total commission - settled_amount

ALTER TABLE provider_profiles
ADD COLUMN IF NOT EXISTS settled_amount DECIMAL(10, 2) DEFAULT 0;

-- Add comment
COMMENT ON COLUMN provider_profiles.settled_amount IS 'Total commission amount that has been settled/paid by the provider. Used to calculate remaining commission to withdraw.';
