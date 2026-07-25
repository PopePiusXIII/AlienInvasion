--!strict
local RunService = game:GetService("RunService")

local RenderScheduler = {}

local tasks: { any } = {}
local idToIndex: { [string]: number } = {}
local nextId = 0
local conn: RBXScriptConnection?

local function disconnectIfIdle()
    if conn == nil then return end
    if #tasks == 0 then
        conn:Disconnect()
        conn = nil
    end
end

local function ensureLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function(dt)
        -- numeric loop for performance
        for i = 1, #tasks do
            local task = tasks[i]
            if task.enabled then
                if task.throttle and task.throttle > 0 then
                    task.acc = task.acc + dt
                    if task.acc >= task.throttle then
                        local acc = task.acc
                        task.acc = task.acc - task.throttle
                        local ok, err = pcall(task.fn, acc)
                        if not ok then
                            task.enabled = false
                            warn("RenderScheduler task error:", task.name, err)
                        end
                    end
                else
                    local ok, err = pcall(task.fn, dt)
                    if not ok then
                        task.enabled = false
                        warn("RenderScheduler task error:", task.name, err)
                    end
                end
            end
        end
    end)
end

function RenderScheduler.register(name, fn, opts)
    opts = opts or {}
    nextId += 1
    local id = tostring(nextId)
    local entry = {
        id = id,
        name = name or ("task_" .. id),
        fn = fn,
        throttle = opts.throttle or 0,
        acc = 0,
        enabled = opts.enabled ~= false,
    }
    table.insert(tasks, entry)
    idToIndex[id] = #tasks
    ensureLoop()
    return id
end

function RenderScheduler.unregister(id)
    local idx = idToIndex[id]
    if not idx then return end
    local last = tasks[#tasks]
    tasks[idx] = last
    idToIndex[last.id] = idx
    tasks[#tasks] = nil
    idToIndex[id] = nil
    disconnectIfIdle()
end

function RenderScheduler.setEnabled(id, enabled)
    local idx = idToIndex[id]
    if not idx then return end
    tasks[idx].enabled = enabled
end

function RenderScheduler.setThrottle(id, throttle)
    local idx = idToIndex[id]
    if not idx then return end
    tasks[idx].throttle = throttle
    tasks[idx].acc = 0
end

return RenderScheduler
