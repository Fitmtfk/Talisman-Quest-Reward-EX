local QURIOUS_VOUCHER_ID = 68160308
local FRIEND_VOUCHER_ID = 68158506
local DEFAULT_MESSAGE = "<COL RED>Talisman Rewards:</COL>\nRewards available for pickup at melding pot."
local LANGUAGES = {
    "JP",
    "EN",
    "FR",
    "IT",
    "DE",
    "ES",
    "RU",
    "PL",
    "NL",
    "PR",
    "PR_BR",
    "KR",
    "ZH-HK",
    "ZH-CN",
    "FI",
    "SV",
    "DA",
    "NO",
    "CS",
    "HU",
    "SK",
    "AR",
    "TR",
    "BG",
    "EL",
    "RO",
    "TH",
    "UA",
    "VI",
    "ID",
    "FICTION",
    "HI",
    "UNKNOWN"
}

local charms = { [3] = { points = 500, tickets = 19 }, [5] = { points = 1000, tickets = 25 }, [8] = { points = 1500, tickets = 10 } }

local config_file = "talisman_rewards_ex.json"
local mod_name = "Talisman Reward"
local give_rewards = false
local talisman_level = 8

local config = json.load_file(config_file)
if config == nil then
    config = {
        enabled = true,
        rewards_config = {
            endgame = false,
            percent = 100,
            quantity = 1,
        },
        message = {
            enabled = true,
            language = 2.0,
            overwrite = false,
            text = {}
        }
    }
    for _, value in ipairs(LANGUAGES) do
        config.message.text[value] = ""
    end
    config.message.text["EN"] = DEFAULT_MESSAGE
    json.dump_file(config_file, config)
elseif config.rewards_config == nil then
    config.rewards_config = {
        endgame = false,
        percent = 100,
        quantity = 1,
    }
    json.dump_file(config_file, config)
end

local function create_chat()
    if config.message.enabled then
        local cm = sdk.get_managed_singleton("snow.gui.ChatManager")
        local rm = sdk.get_native_singleton("via.ResourceManager")
        local rm_type = sdk.find_type_definition("via.ResourceManager")
        local lang = 2.0
        if config.message.overwrite then
            lang = config.message.language
        else
            lang = sdk.call_native_func(rm, rm_type, "get_Language") + 1
        end
        local str = config.message.text[LANGUAGES[lang]]
        if not str or str == '' then
            str = DEFAULT_MESSAGE
        end
        cm:call("reqAddChatInfomation", str, 2289944406) --,message,0)
    end

end

local function check_rewards_on_quest_complete(retval)
    local qm = sdk.get_managed_singleton("snow.QuestManager")
    local qrlv = qm:call("getQuestRank_Lv")
    local qlvex = qm:call("getQuestLvEx")
    local qlv = qm:call("getQuestLv")
    local is_mistery = qm:call("isMysteryQuest")
    local is_research = qm:call("isRandomMysteryQuest")
    local is_tour = qm:call("isTourQuest")
    local is_zako = qm:call("isZakoTargetQuest")
    local roll = math.random()
    if give_rewards ~= true then
        if roll <= config.rewards_config.percent / 100 then
            if not (is_tour or is_zako) then
                if config.rewards_config.endgame then
                    if qrlv == 2 and (not is_mistery) and (not is_research) then
                        give_rewards = true
                        talisman_level = 5
                    elseif is_mistery or is_research then
                        give_rewards = true
                        talisman_level = 8
                    elseif qrlv == 1 then
                        give_rewards = true
                        talisman_level = 3
                    end
                else
                    if (qrlv == 2 and qlv >= 5) or is_mistery then
                        give_rewards = true
                        talisman_level = 5
                    elseif (qlvex == 7 and qrlv == 1) or (qrlv == 2 and qlv < 5) then
                        give_rewards = true
                        talisman_level = 3
                    end
                end
            end
        end
        if give_rewards then
            create_chat()
        end
    end
end

local function swap_talismans(alchemy, index)
    local af = alchemy:call("get_Function")
    local list = af:get_field("_ReserveInfoList")
    local array = list:call("ToArray")
    local temp = array:get_element(0)

    array:call("SetValue", array:get_element(index), 0)
    for i = 1, index do
        local curr = array:get_element(i)
        array:call("SetValue", temp, i)
        temp = curr
    end

    list:call("Clear")
    list:call("AddRange", array)
end

local function add_points(dm)
    local points = dm:call("get_VillagePointData")
    local amount = charms[talisman_level]["points"]
    points:call("addPoint", amount)
end

local function add_tickets(dm)
    local ib = dm:call("get_PlItemBox")
    local amount = charms[talisman_level]["tickets"]
    if talisman_level == 8 then
        ib:call("tryAddGameItem(snow.data.ContentsIdSystem.ItemId, System.Int32)", QURIOUS_VOUCHER_ID, amount)
    else
        ib:call("tryAddGameItem(snow.data.ContentsIdSystem.ItemId, System.Int32)", FRIEND_VOUCHER_ID, amount)
    end
end

local function refill_resources()
    local dm = sdk.get_managed_singleton("snow.data.DataManager")
    add_points(dm)
    add_tickets(dm)
end

local function add_talismans_to_pot(retval)
    if config.enabled and give_rewards then
        local fm = sdk.get_managed_singleton("snow.data.FacilityDataManager")
        local alchemy = fm:call("getAlchemy")
        local slots = alchemy:call("getRemainingSlotNum")
        for index=1,config.rewards_config.quantity do
            if slots > 0 then
                slots = slots - 1
                refill_resources()
                local list = alchemy:call("getPatturnDataList")
                local list_array = list:call("ToArray")
                local pattern = list_array[talisman_level]
                local name = pattern:call("getName")
                alchemy:call("selectPatturn", pattern)
                local amount = charms[talisman_level]["tickets"]
                if talisman_level == 8 then
                    alchemy:call("addUsingItem", QURIOUS_VOUCHER_ID, amount)
                else
                    alchemy:call("addUsingItem", FRIEND_VOUCHER_ID, amount)
                end
                alchemy:call("reserveAlchemy")
                if slots < 9 then
                    swap_talismans(alchemy, 10 - slots - 1)
                end
                alchemy:call("invokeCycleMethod")
                alchemy:call("resetUsingItem")
            end
        end
    end
    give_rewards = false
    return retval
end

sdk.hook(sdk.find_type_definition("snow.QuestManager"):get_method("setQuestClear"),
    function(args) end,
    check_rewards_on_quest_complete)

sdk.hook(sdk.find_type_definition("snow.QuestManager"):get_method("setQuestClearSub"),
    function(args) end,
    check_rewards_on_quest_complete)

sdk.hook(sdk.find_type_definition("snow.SnowSessionManager"):get_method("_onSucceedQuickQuest"),
    function(arg) end,
    check_rewards_on_quest_complete)

sdk.hook(sdk.find_type_definition("snow.data.FacilityDataManager"):get_method("executeCycle"),
    function(args) end,
    add_talismans_to_pot)

re.on_draw_ui(function()
    if imgui.tree_node(mod_name) then
        local changed = false
        changed, config.enabled = imgui.checkbox("Enabled", config.enabled)
        if imgui.tree_node("Rewards Configuration") then
            changed, config.rewards_config.endgame = imgui.checkbox("Endgame Mode", config.rewards_config.endgame)
            changed, config.rewards_config.percent = imgui.slider_int("Percent", config.rewards_config.percent, 1, 100)
            changed, config.rewards_config.quantity = imgui.slider_int("Quantity", config.rewards_config.quantity, 1, 10)
            imgui.tree_pop()
        end
        if imgui.tree_node("Message") then
            changed, config.message.enabled = imgui.checkbox("Enabled", config.message.enabled)
            changed, config.message.overwrite = imgui.checkbox("Overwrite Game Language", config.message.overwrite)
            if config.message.overwrite then
                changed, config.message.language = imgui.combo("Language", config.message.language, LANGUAGES)
            end
            imgui.tree_pop()
        end
        if imgui.button("Save") then
            json.dump_file(config_file, config)
        end
        imgui.tree_pop()
    end
end)
