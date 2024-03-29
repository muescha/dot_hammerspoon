---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 17.12.22 00:02
--- source https://github.com/kazu914/dotfiles/blob/master/hammerspoon/FuzzyMatcher.lua

-- NOTE: text/subText can be created as: hs.styledtext.new() or as string
-- additional: preserve previous values and not strip down to { text,subtext}

local function fuzzyMatch(target, query)
    local matched_idx = {}

    if string.len(query) > string.len(target) then
        return matched_idx
    end
    if not string.match(query, "%u") then
        target = string.lower(target)
    end

    local query_idx = 1
    local target_idx = 1
    while query_idx <= #query and target_idx <= #target do
        local query_char = string.sub(query, query_idx, query_idx)
        local target_char = string.sub(target, target_idx, target_idx)
        if query_char == target_char then
            table.insert(matched_idx, target_idx)
            query_idx = query_idx + 1
        end
        target_idx = target_idx + 1
    end
    return query_idx == #query + 1 and matched_idx or {}
end

local function highlightMatched(text, matched_idxs)
    local new_text = hs.styledtext.new(text)
    for _, idx in pairs(matched_idxs) do
        new_text = new_text:setStyle({ color = hs.drawing.color.red }, idx, idx)
    end
    return new_text
end

local function getText(text)
    if text == nil then
        return ''
    end
    if type(text) == 'string' then
        return text
    end
    return text:getString()
end

local function lenSorter(a, b)
    return (string.len(getText(a.text)) < string.len(getText(b.text)))
end

local function ascSorter(a, b)
    return (getText(a.text) < getText(b.text))
end

local function descSorter(a, b)
    return (getText(a.text) > getText(b.text))
end

local function filter(choices, query, ignore_sub_text)
    if string.len(query) == 0 then
        return choices
    end
    local filtered_choices = {}
    for _, choice in pairs(choices) do

        local choice_text = getText(choice.text)
        local choice_subText = getText(choice.subText)

        local text_matched_idxs = fuzzyMatch(choice_text, query)

        local sub_text_matched_idxs = ignore_sub_text and {} or
                fuzzyMatch(choice_subText,
                        query)

        local is_text_matched = #text_matched_idxs ~= 0
        local is_sub_text_matched = #sub_text_matched_idxs ~= 0

        if is_text_matched or is_sub_text_matched then
            local new_text = is_text_matched and
                    highlightMatched(choice_text,
                            text_matched_idxs) or
                    choice.text  -- leave original otherwise formatting is lost
            local new_sub_text = is_sub_text_matched and
                    highlightMatched(
                            choice_subText,
                            sub_text_matched_idxs) or
                    choice.subText -- leave original otherwise formatting is lost

            --local new_app = { text = new_text, subText = new_sub_text }
            -- preserve previous values
            local new_app = helper.table.assigned(choice,{ text = new_text, subText = new_sub_text })
            table.insert(filtered_choices, new_app)
        end
    end
    return filtered_choices
end

local function setChoices(choices, chooser, ignoreSubText, sorter)
    local filtered_choices = filter(choices, chooser:query(), ignoreSubText)
    if sorter ~= nil then
        table.sort(filtered_choices, sorter)
    end
    chooser:choices(filtered_choices)
    chooser:refreshChoicesCallback(true)
end

return {
    setChoices = setChoices,
    Sorter = {
        byLength = lenSorter,
        asc = ascSorter,
        desc = descSorter
    }
}