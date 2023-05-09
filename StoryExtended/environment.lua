local _G = getfenv(0)
StoryExtendedEnv = setmetatable({ _G = _G }, { __index = _G })