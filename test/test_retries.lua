local retries = require "nakama.util.retries"
local log = require "nakama.util.log"
log.print()

context("Retries", function()

	before(function() end)
	after(function() end)

	test("create exponentially increasing intervals", function()
		local intervals = retries.exponential(5, 0.5)
		assert(#intervals == 5)
		assert(intervals[1] == 0.5)
		assert(intervals[2] == 1.0)
		assert(intervals[3] == 2.0)
		assert(intervals[4] == 4.0)
		assert(intervals[5] == 8.0)
	end)

	test("create incrementally increasing intervals", function()
		local intervals = retries.incremental(5, 0.5)
		assert(#intervals == 5)
		assert(intervals[1] == 0.5)
		assert(intervals[2] == 1.0)
		assert(intervals[3] == 1.5)
		assert(intervals[4] == 2.0)
		assert(intervals[5] == 2.5)
	end)

	test("create fixed intervals", function()
		local intervals = retries.fixed(5, 0.5)
		assert(#intervals == 5)
		assert(intervals[1] == 0.5)
		assert(intervals[2] == 0.5)
		assert(intervals[3] == 0.5)
		assert(intervals[4] == 0.5)
		assert(intervals[5] == 0.5)
	end)

	test("create no intervals", function()
		local intervals = retries.none()
		assert(#intervals == 0)
		intervals = retries.exponential(0, 0)
		assert(#intervals == 0)
		intervals = retries.incremental(0, 0)
		assert(#intervals == 0)
		intervals = retries.fixed(0, 0)
		assert(#intervals == 0)
	end)
end)


