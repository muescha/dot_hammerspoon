---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 16.12.22 22:54
---
function hotkeybindmodal(mod, key, description, pressedFn, releasedFn)
    local ks = hs.hotkey.modal.new(
            mod,
            key,
            description);

    function ks:entered() pressedFn() end
    function ks:exited() releasedFn()  end

    ks:bind('', 'escape', "~~~~~hide~~~~~", function() ks:exit() end)
    ks:bind(mod, key, description, function() ks:exit() end)
    return ks
end
