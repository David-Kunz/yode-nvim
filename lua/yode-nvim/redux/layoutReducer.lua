local R = require('yode-nvim.deps.lamda.dist.lamda')
local logging = require('yode-nvim.logging')
local createReducer = require('yode-nvim.redux.createReducer')
local layoutMap = require('yode-nvim.layout.layoutMap')
local h = require('yode-nvim.helper')
local sharedActions = require('yode-nvim.layout.sharedActions')

local M = { actions = {}, selectors = {} }

initialState = {
    tabs = {},
}

local multiTabActionMap = {
    [sharedActions.actionNames.MULTI_TAB_REMOVE_SEDITOR] = R.pipe(
        R.omit({ 'type', 'syncToNeovim' }),
        sharedActions.actions.removeFloatingWindow
    ),
}

local createTabState = function(name)
    return {
        name = name,
        -- FIXME: track here for example "align=right|left, columnWidthMin=30,
        -- columnWidthMax=50%" for Mosaic
        config = {},
        -- FIXME place for layout reducer to store data not tied to window, probably not needed?!
        data = {},
        windows = {},
    }
end

M.selectors = R.reduce(function(selectors, selectorName)
    local selector = function(tabId, selectorArgs, state)
        local tabState = state.tabs[tabId] or {}
        local layoutSelector = R.path({ tabState.name, 'selectors', selectorName }, layoutMap)
            or h.noop
        return layoutSelector(tabId, selectorArgs, tabState)
    end
    return R.assoc(selectorName, selector, selectors)
end, {}, {
    'getWindowBySomeId',
})

local reducerFunctions = {
    -- FIXME do better
    me = function(state, a)
        return R.assocPath({ 'tabs', a.tabId }, a.data, state)
    end,
    [sharedActions.actionNames.ON_TAB_CLOSED] = function(state, a)
        return R.dissocPath({ 'tabs', a.tabId }, state)
    end,
}

local reduceSingleTab = function(state, action)
    local log = logging.create('reduceSingleTab')
    local tabState = state.tabs[action.tabId] or createTabState('mosaic')
    local layout = layoutMap[tabState.name]
    local tabStateData = layout.reducer(tabState, action)

    if tabStateData == nil then
        log.warn(string.format("layout %s can't handle action ", tabState.name or 'mosaic'), action)
        return state
    end

    return R.assocPath({ 'tabs', action.tabId }, tabStateData, state)
end

M.reducer = function(stateParam, action)
    local tabIds, singleTabActionCreator
    local log = logging.create('reducer')
    local state = stateParam or initialState
    if reducerFunctions[action.type] then
        return reducerFunctions[action.type](state, action)
    end

    singleTabActionCreator = multiTabActionMap[action.type]
    if singleTabActionCreator then
        tabIds = R.keys(state.tabs)
        log.trace(
            string.format('mapping multi tab action %s to single tab action: ', action.type),
            tabIds
        )
        return R.reduce(function(prevState, tabId)
            log.trace('reducing tabId', tabId)
            return reduceSingleTab(
                prevState,
                singleTabActionCreator(R.assoc('tabId', tabId, action))
            )
        end, state, tabIds)
    end

    if action.tabId then
        return reduceSingleTab(state, action)
    end

    return state
end

--[[
TODO:
* this logic must be already in SOME plugin in the internet!
    * how to find windows to ignore? E.g. location/quickfix list window panel at bottom?
    * what special things do we need to ignore?
        * height: tab row (if visible)
        * width: nerdtree, gundo, ...
    * check https://github.com/beauwilliams/focus.nvim
]]

return M
