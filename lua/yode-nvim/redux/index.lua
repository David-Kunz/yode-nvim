local createStore = require('yode-nvim.deps.redux-lua.src.createStore')
local applyMiddleware = require('yode-nvim.deps.redux-lua.src.applyMiddleware')
local combineReducers = require('yode-nvim.deps.redux-lua.src.combineReducers')
local seditorsReducer = require('yode-nvim.redux.seditorsReducer')
local layoutReducer = require('yode-nvim.redux.layoutReducer')
local stateLogger = require('yode-nvim.redux.stateLogger')
local layoutStateToNeovim = require('yode-nvim.redux.layoutStateToNeovim')
local ReduxEnv = require('yode-nvim.deps.redux-lua.src.env')
ReduxEnv.setDebug(false)
local h = require('yode-nvim.helper')
local R = require('yode-nvim.deps.lamda.dist.lamda')
local sharedActions = require('yode-nvim.layout.sharedActions')

local M = { store = {}, seditors = {} }

local STATE_PATH_SEDITORS = { 'seditors' }
local STATE_PATH_LAYOUT = { 'layout' }
local reducerMap = R.pipe(
    R.assocPath(STATE_PATH_SEDITORS, seditorsReducer.reducer),
    R.assocPath(STATE_PATH_LAYOUT, layoutReducer.reducer)
)({})
local reducers = combineReducers(reducerMap)

local globalizeSelectors = function(rootPath, selectors)
    return h.map(function(selector)
        return function(...)
            local state = M.store.getState()
            return selector(unpack(R.concat({ ... }, { R.path(rootPath, state) })))
        end
    end, selectors)
end

local wrapWithDispatch = h.map(function(action)
    return function(...)
        return M.store.dispatch(action(...))
    end
end)

M.store = createStore(reducers, applyMiddleware(stateLogger, layoutStateToNeovim))
M.seditors = {
    actions = wrapWithDispatch(seditorsReducer.actions),
    selectors = globalizeSelectors(STATE_PATH_SEDITORS, seditorsReducer.selectors),
}
M.layout = {
    selectors = globalizeSelectors(STATE_PATH_LAYOUT, layoutReducer.selectors),
    actions = wrapWithDispatch({
        -- FIXME add layout actions somhow here as well. Should we insert
        -- "tabId" automatically?! When it is only copied from "sharedActions"
        -- ... probably remove?
        createFloatingWindow = sharedActions.actions.createFloatingWindow,
        removeFloatingWindow = sharedActions.actions.removeFloatingWindow,
        contentChanged = sharedActions.actions.contentChanged,
        onVimResized = sharedActions.actions.onVimResized,
    }),
}

return M
