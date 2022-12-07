fileInfo()

-- require("external/mobdebug").start()

-- ## Init Functions
-- add opt.runonstart to mobdebug
-- https://github.com/pkulchenko/MobDebug/issues/37#issuecomment-663341417
local mobdebug = require("mobdebug")
--debugInfo(mobdebug)
--debugFunction(mobdebug.coro)
mobdebug.start()

-- cancel
-- https://github.com/pkulchenko/MobDebug/issues/51#issuecomment-662565734
