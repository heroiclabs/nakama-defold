local M = {}


--- Create a retry policy where the interval between attempts is exponentially increasing
-- Example: interval = 0.5 and attempts = 5 gives retries: 0.5, 1.0, 2.0, 4.0, 8.0
-- @param attempts The number of retry attempts
-- @param interval (seconds)
-- @return Retry intervals
function M.exponential(attempts, interval)
	local delays = {}
	for i=1,attempts do
		delays[i] = (i > 1) and delays[i] * 2 or interval
	end
	return delays
end

--- Create a retry policy where the interval between attempts is increasing
-- Example: interval = 0.5 and attempts = 5 gives retries: 0.5, 1.0, 1.5, 2.0, 2.5
-- @param attempts The number of retry attempts
-- @param interval (seconds)
-- @return Retry intervals
function M.incremental(attempts, interval)
	local delays = {}
	for i=1,attempts do
		delays[i] = interval * i
	end
	return delays
end

--- Create a retry policy where the interval between attempts is fixed
-- Example: interval = 0.5 and attempts = 5 gives retries: 0.5, 0.5, 0.5, 0.5, 0.5
-- @param attempts The number of retry attempts
-- @param interval (seconds)
-- @return Retry intervals
function M.fixed(attempts, interval)
	local delays = {}
	for i=1,attempts do
		delays[i] = interval
	end
	return delays
end

--- No retry policy
function M.none()
	return {}
end

return M