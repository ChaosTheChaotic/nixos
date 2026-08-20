--- Composer pipeline, generates rendering intents from stage pipeline.
--- There is a general concern with this implementation about JIT optimization when 
--- we have a lot of different polymorhic stages. This hasnt been an issue thusfar but it might be at some point

local perf = require('strontium.perf')
local util = require('strontium.renderer.util')

local composer = {}

local function create_context(br, cards)
    return {
        cards = cards,
        intents = {},
        cache = {},
        br = br,
    }
end

local function reset_context(ctx, cards)
    ctx.cards = cards
    util.clear_array(ctx.intents)
    local cache = ctx.cache
    for k in pairs(cache) do
        cache[k] = nil
    end
end

function composer.attach(br)
    local comp = {
        pipeline = {},
        runners = {},
        ctx = create_context(br, {}),
        dirty = true,
    }

    function comp:add_stage(stage, opts)
        opts = opts or {}
        if type(stage) ~= "table" and type(stage) ~= "function" then
            error("Composer: Stage must be a table or function.")
        end
        if type(stage) == "table" and type(stage.run) ~= "function" then
            error("Composer: Stage table must have a :run(context) method.")
        end

        local name = opts.name or (type(stage) == "table" and stage.name) or ("anon_" .. tostring(stage))
        self:remove_stage(name)

        local order = opts.order or 1000
        if opts.after then
            for _, entry in ipairs(self.pipeline) do
                if entry.name == opts.after then
                    order = entry.order + 0.1
                    break
                end
            end
        elseif opts.before then
            for _, entry in ipairs(self.pipeline) do
                if entry.name == opts.before then
                    order = entry.order - 0.1
                    break
                end
            end
        end

        local entry = {
            name = name,
            stage = stage,
            order = order,
            perf_name = opts.perf_name or ("stage." .. tostring(name)),
        }

        table.insert(self.pipeline, entry)
        self.dirty = true
    end

    function comp:remove_stage(name)
        for i, entry in ipairs(self.pipeline) do
            if entry.name == name then
                table.remove(self.pipeline, i)
                self.dirty = true
                return true
            end
        end
        return false
    end

    function comp:sort_pipeline()
        table.sort(self.pipeline, function(a, b)
            if a.order == b.order then
                return a.name < b.name
            end
            return a.order < b.order
        end)
        local runners = {}
        for i = 1, #self.pipeline do
            local entry = self.pipeline[i]
            local stage = entry.stage
            local perf_name = entry.perf_name
            if type(stage) == "function" then
                runners[i] = function(ctx)
                    perf.begin(perf_name)
                    stage(ctx)
                    perf.finish(perf_name)
                end
            else
                runners[i] = function(ctx)
                    perf.begin(perf_name)
                    stage:run(ctx)
                    perf.finish(perf_name)
                end
            end
        end
        self.runners = runners
        self.dirty = false
    end

    function comp:process(cards)
        if self.dirty then
            self:sort_pipeline()
        end

        local ctx = self.ctx or create_context(br, cards)
        if ctx == self.ctx then
            reset_context(ctx, cards)
        else
            self.ctx = ctx
        end

        for i = 1, #self.runners do
            self.runners[i](ctx)
        end

        self.last_context_cache = ctx.cache
        return ctx.intents
    end

    function comp:get_stage(name)
        for _, entry in ipairs(self.pipeline) do
            if entry.name == name then
                return entry.stage
            end
        end
        return nil
    end

    br.composer = comp

    function br:draw_all_cards(cards)
        perf.frame_begin()
        perf.begin("frame.total")
        br:reset_frame()

        perf.begin("compose.process")
        local intents = comp:process(cards)
        perf.finish("compose.process")
        perf.begin("emit.intents")
        for i = 1, #intents do
            br:emit_intent(intents[i])
        end
        perf.finish("emit.intents")

        local ctx_cache = comp.last_context_cache
        br.queue_sorted_by_x = false
        if ctx_cache then
            local ui_queue = ctx_cache.ui_queue or {}
            for i = 1, #ui_queue do
                br.drawhash_queue[#br.drawhash_queue + 1] = ui_queue[i]
                br.ui_queue[#br.ui_queue + 1] = ui_queue[i]
            end
            br.queue_sorted_by_x = ctx_cache.ui_queue_sorted == true
        end

        br:draw_frame()
        perf.finish("frame.total")
        perf.frame_end()
    end
end

composer.create_context = create_context

return composer
