local _, ns = ...

local Scheduler = {
	tasks = {},
	nextId = 0,
	frame = nil,
}

ns.JobScheduler = Scheduler

local function ensureFrame(self)
	if self.frame then
		return
	end

	self.frame = CreateFrame("Frame")
	self.frame:SetScript("OnUpdate", function(_, elapsed)
		for id, task in pairs(self.tasks) do
			task.remaining = task.remaining - elapsed
			if task.remaining <= 0 then
				local callback = task.callback
				if task.repeating then
					task.remaining = task.interval
				else
					self.tasks[id] = nil
				end

				callback()
			end
		end
	end)
end

function Scheduler:Schedule(delay, callback, repeating)
	ensureFrame(self)
	self.nextId = self.nextId + 1
	self.tasks[self.nextId] = {
		remaining = delay or 0,
		interval = delay or 0,
		callback = callback,
		repeating = repeating or false,
	}
	return self.nextId
end

function Scheduler:Cancel(id)
	if id then
		self.tasks[id] = nil
	end
end

function Scheduler:CancelAll()
	wipe(self.tasks)
end
