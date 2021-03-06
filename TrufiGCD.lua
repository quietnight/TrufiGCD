-- TrufiGCD stevemyz@gmail.com

local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

--sizeicon = 30
--speed = sizeicon /1.6 --скорость перемотка
local TimeGcd = 1.6
--width = sizeicon * 3 -- длина очереди
local SpMod = 3 -- fast forward modifier

TrGCDBufferIcon = {} -- counter of distance between icons
local TimeDelay = 0.03 -- delay between OnUpdate
local TimeReset = GetTime() -- time of last OnUpdate
local DurTimeImprove = 0.0 -- fast forward duration
TrGCDCastSp = {} -- 0 - каст идет, 1 - каст прошел и не идет
TrGCDCastSpBanTime = {} -- casting stop time
TrGCDBL = {} -- spell blacklist
local BLSpSel = nil -- highlighted spell in blacklist
local InnerBL = { --закрытый черный список, по ID
	61391, -- Тайфун x2
	5374, -- Расправа х3
	27576, -- Расправа (левая рука) х3
	88263, -- Молот Праведника х3
	98057, -- Великий воин Света
	32175, -- Удар бури
	32176, -- Удар бури (левая рука)
	96103, -- Яростный выпад
	85384, -- Яростный выпад (левая рука)
	57794, -- Героический прыжок
	52174, -- Героический прыжок
	135299, -- Ледяная ловушка
	121473, -- Теневой клинок
	121474, -- Второй теневой клинок
	114093, -- Хлещущий ветер (левая рука)
	114089, -- Хлещущий ветер
	115357, -- Свирепость бури
	115360, -- Свирепость бури (левая рука)
	127797, -- Вихрь урсола
	102794, -- Вихрь урсола
	50622, -- Вихрь клинков
	122128, -- Божественная звезда (шп)
	110745, -- Божественная звезда (не шп)
	120696, -- Сияние (шп)
	120692, -- Сияние (не шп)
	115464, -- Целительная сфера
	126526, -- Целительная сфера
	132951, -- Осветительная ракета
	107270, -- Танцующий журавль
	137584, -- Бросок сюрикена
	137585, -- Бросок сюрикена левой рукой
	117993, -- Ци-полет (дамаг)
	124040, -- Ци-полет (хил)
	198928, -- Cinderstorm shards (Fire Mage verified fix)
	84721, -- Frozen Orb shards (Frost Mage verified fix)
	222031, -- Chaos Strike 1 (DemonHunter unverified fix)
	197125, -- Chaos Strike 2 (DemonHunter unverified fix)
	199547, -- Chaos Strike 3 (DemonHunter unverified fix)
}
local cross = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
local skull = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local trinket = "Interface\\Icons\\inv_jewelry_trinketpvp_01"
TrGCDInsSp = {}
TrGCDInsSp["spell"] = {}
TrGCDInsSp["time"] = {}
TrGCDSpStop = {} -- the index of the icon where the cast spell was stopped
TrGCDSpStopTime = {} -- the index of the icon where the cast spell was stopped
TrGCDSpStopName = {}
local TrGCDEnable = true
local PlayerDislocation = 0 -- Player location: 1 - Мир, 2 - ПвЕ, 3 - Арена, 4 - Бг.
TrGCDIconOnEnter = {} -- false - cursor on icon
TrGCDTimeuseSpamSpell = {} -- time when spell N spam was used -> SpellID -> Time

local ModTimeVanish = 2; -- the time it takes for the icons to disappear
local ModTimeIndent = 3; -- time after which icons will disappear

--Masque
local Masque = LibStub("Masque", true)
if Masque then
	TrGCDMasqueIcons = Masque:Group("TrufiGCD", "All Icons")
end

SLASH_TRUFI1, SLASH_TRUFI2 = '/tgcd', '/trufigcd' --slash commands
function SlashCmdList.TRUFI(msg, editbox) --Slash command function
	InterfaceOptionsFrame_OpenToCategory(TrGCDGUI)
end

local function AddButton(parent,position,x,y,height,width,text,font,texttop,template) --button template
	local temp = nil
	if (template == nil) then temp = "UIPanelButtonTemplate" end
	local button = CreateFrame ("Button", nil, parent, temp)
	button:SetHeight(height)
	button:SetWidth(width)
	button:SetPoint(position, parent, position,x, y)
	button:SetText(text)
	if ((font ~= nil) and (texttop ~= nil)) then
		button.Text = button:CreateFontString(nil, "BACKGROUND")
		button.Text:SetFont("Fonts\\FRIZQT__.TTF", font)
		button.Text:SetText(texttop)
		button.Text:SetPoint("TOP", button, "TOP",0, 10)
	end
	return button
end

local function AddCheckButton (parent, position,x,y,text,name,fromenable) --button template
	local button = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
	button:SetPoint(position, parent, position,x,y)
	button:SetChecked(fromenable)
	getglobal(name .. 'Text'):SetText(text)
	button:SetScript("OnEnter", function(self)
		if self.tooltipText then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, 1)
		end
		if self.tooltipRequirement then
			GameTooltip:AddLine(self.tooltipRequirement, "", 1.0, 1.0, 1.0)
			GameTooltip:Show()
		end
	end )
	button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	return button
end

local function ValueReverse(value) -- the function after clicking CheckButton, changes the stored value in the parameters, false-> true, true-> false
	local t = value
	if (t) then t = false else t = true end
	return t
end

local TrGCDLoadFrame = CreateFrame("Frame", nil, UIParent)
TrGCDLoadFrame:RegisterEvent("ADDON_LOADED")
TrGCDLoadFrame:SetScript("OnEvent", TrufiGCDAddonLoaded)
function TrufiGCDAddonLoaded(self, event, ...)
	local arg1 = ...;
	if (arg1 == "TrufiGCD" and event == "ADDON_LOADED") then
		--Load options
		TrGCDQueueOpt = {}
		local TrGCDNullOptions = false -- are the settings empty?
		if (TrufiGCDChSave == nil) then
			TrGCDNullOptions = true
		else
			if (TrufiGCDChSave["TrGCDQueueFrame"] == nil) then
				TrGCDNullOptions = true
			else
				for i=1,12 do
					if (TrufiGCDChSave["TrGCDQueueFrame"][i] == nil) then
						TrGCDNullOptions = true
					else
						if ((TrufiGCDChSave["TrGCDQueueFrame"][i]["point"] == nil) or (TrufiGCDChSave["TrGCDQueueFrame"][i]["enable"] == nil) or (TrufiGCDChSave["TrGCDQueueFrame"][i]["text"] == nil)) then
							TrGCDNullOptions = true
						elseif ((TrufiGCDChSave["TrGCDQueueFrame"][i]["fade"] == nil) or (TrufiGCDChSave["TrGCDQueueFrame"][i]["size"] == nil) or (TrufiGCDChSave["TrGCDQueueFrame"][i]["width"] == nil)) then
							TrGCDNullOptions = true
						elseif ((TrufiGCDChSave["TrGCDQueueFrame"][i]["speed"] == nil) or (TrufiGCDChSave["TrGCDQueueFrame"][i]["x"] == nil) or (TrufiGCDChSave["TrGCDQueueFrame"][i]["y"] == nil)) then
							TrGCDNullOptions = true
						end
					end
				end
			end
			if (TrufiGCDChSave["TooltipEnable"] == nil) then
				TrGCDNullOptions = true
			end
		end
		-- load saved settings
		if (TrGCDNullOptions) then TrGCDRestoreDefaultSettings()
		else
			for i=1,12 do
				TrGCDQueueOpt[i] = {}
				TrGCDQueueOpt[i].x = TrufiGCDChSave["TrGCDQueueFrame"][i]["x"]
				TrGCDQueueOpt[i].y = TrufiGCDChSave["TrGCDQueueFrame"][i]["y"]
				TrGCDQueueOpt[i].point = TrufiGCDChSave["TrGCDQueueFrame"][i]["point"]
				TrGCDQueueOpt[i].enable = TrufiGCDChSave["TrGCDQueueFrame"][i]["enable"]
				TrGCDQueueOpt[i].text = TrufiGCDChSave["TrGCDQueueFrame"][i]["text"]
				TrGCDQueueOpt[i].fade = TrufiGCDChSave["TrGCDQueueFrame"][i]["fade"]
				TrGCDQueueOpt[i].size = TrufiGCDChSave["TrGCDQueueFrame"][i]["size"]
				TrGCDQueueOpt[i].width = TrufiGCDChSave["TrGCDQueueFrame"][i]["width"]
				TrGCDQueueOpt[i].speed = TrufiGCDChSave["TrGCDQueueFrame"][i]["speed"]
			end
		end

		-- Checking for an empty Black List
		if (TrufiGCDChSave["TrGCDBL"] == nil) then TrGCDBLDefaultSetting()
		else TrGCDBL = TrufiGCDChSave["TrGCDBL"]
		end

		-- Checking for empty EnableIn
		-- NEW MODE, TrufiGCDChSave["EnableIn"] - ["PvE"], ["Arena"], ["Bg"], ["World"] = true or false
		TrGCDNullOptions = false
		if (TrufiGCDChSave["EnableIn"] == nil) then
			TrGCDNullOptions = true
		else
			if (TrufiGCDChSave["EnableIn"]["PvE"] == nil) then TrGCDNullOptions = true
			elseif (TrufiGCDChSave["EnableIn"]["Arena"] == nil) then TrGCDNullOptions = true
			elseif (TrufiGCDChSave["EnableIn"]["Bg"] == nil) then TrGCDNullOptions = true
			elseif (TrufiGCDChSave["EnableIn"]["World"] == nil) then TrGCDNullOptions = true
			elseif (TrufiGCDChSave["EnableIn"]["Enable"] == nil) then TrGCDNullOptions = true
			end
		end
		if (TrGCDNullOptions) then
			TrufiGCDChSave["EnableIn"] = {}
			TrufiGCDChSave["EnableIn"]["PvE"] = true
			TrufiGCDChSave["EnableIn"]["Arena"] = true
			TrufiGCDChSave["EnableIn"]["Bg"] = true
			TrufiGCDChSave["EnableIn"]["World"] = true
			TrufiGCDChSave["EnableIn"]["Enable"] = true
		end
		-- check for empty Mod Scroll VERSION 1.5
		if (TrufiGCDChSave["ModScroll"] == nil) then TrufiGCDChSave["ModScroll"] = true end
		-- check for empty EnableIn - Raid VERSION 1.6
		if (TrufiGCDChSave["EnableIn"]["Raid"] == nil) then TrufiGCDChSave["EnableIn"]["Raid"] = true end
		if (TrufiGCDChSave["TooltipStopMove"] == nil) then TrufiGCDChSave["TooltipStopMove"] = true end
		if (TrufiGCDChSave["TooltipSpellID"] == nil) then TrufiGCDChSave["TooltipSpellID"] = false end

		TrGCDCheckToEnableAddon()
		-- Options Panel Frame
		TrGCDGUI = CreateFrame ("Frame", nil, UIParent, "OptionsBoxTemplate")
		TrGCDGUI:Hide()
		TrGCDGUI.name = "TrufiGCD"
		-- button show/hide
		TrGCDGUI.buttonfix = AddButton(TrGCDGUI,"TOPLEFT",10,-30,22,100,"Show",10,"Show/Hide anchors")
		TrGCDGUI.buttonfix:SetScript("OnClick", TrGCDGUIButtonFixClick)
		-- button for loading the settings saved in the cache
		TrGCDGUI.ButtonLoad = AddButton(TrGCDGUI,"TOPRIGHT",-145,-30,22,100,"Load",10,"Load saving settings")
		TrGCDGUI.ButtonLoad:SetScript("OnClick", TrGCDLoadSettings)
		-- buttons for saving settings to cache
		TrGCDGUI.ButtonSave = AddButton(TrGCDGUI,"TOPRIGHT",-260,-30,22,100,"Save",10,"Save settings to cache")
		TrGCDGUI.ButtonSave:SetScript("OnClick", TrGCDSaveSettings)
		-- restore default button
		TrGCDGUI.ButtonRes = AddButton(TrGCDGUI,"TOPRIGHT",-30,-30,22,100,"Default",10,"Restore default settings")
		TrGCDGUI.ButtonRes:SetScript("OnClick", function () TrGCDRestoreDefaultSettings() TrGCDUploadViewSetting() end)
		-- check for Tooltip
		TrGCDGUI.CheckTooltipText = TrGCDGUI:CreateFontString(nil, "BACKGROUND")
		TrGCDGUI.CheckTooltipText:SetFont("Fonts\\FRIZQT__.TTF", 12)
		TrGCDGUI.CheckTooltipText:SetText("Tooltip:")
		TrGCDGUI.CheckTooltipText:SetPoint("TOPRIGHT", TrGCDGUI, "TOPRIGHT",-70, -360)
		TrGCDGUI.CheckTooltip = AddCheckButton(TrGCDGUI,"TOPRIGHT",-90,-380,"Enable","TrGCDCheckTooltip",TrufiGCDChSave["TooltipEnable"])
		TrGCDGUI.CheckTooltip:SetScript("OnClick", function () TrufiGCDChSave["TooltipEnable"] = ValueReverse(TrufiGCDChSave["TooltipEnable"]) end)
		TrGCDGUI.CheckTooltip.tooltipText = ('Show tooltips when hovering the icon')
		TrGCDGUI.CheckTooltipMove = AddCheckButton(TrGCDGUI,"TOPRIGHT",-90,-410,"Stop icons","TrGCDCheckTooltipMove",TrufiGCDChSave["TooltipStopMove"])
		TrGCDGUI.CheckTooltipMove:SetScript("OnClick", function () TrufiGCDChSave["TooltipStopMove"] = ValueReverse(TrufiGCDChSave["TooltipStopMove"]) end)
		TrGCDGUI.CheckTooltipMove.tooltipText = ('Stop moving icons when hovering the icon')
		TrGCDGUI.CheckTooltipID = AddCheckButton(TrGCDGUI,"TOPRIGHT",-90,-440,"Spell ID","TrGCDCheckTooltipSpellID",TrufiGCDChSave["TooltipSpellID"])
		TrGCDGUI.CheckTooltipID:SetScript("OnClick", function () TrufiGCDChSave["TooltipSpellID"] = ValueReverse(TrufiGCDChSave["TooltipSpellID"]) end)
		TrGCDGUI.CheckTooltipID.tooltipText = ('Write spell ID to the chat when hovering the icon')
		-- check for scrolling icons
		TrGCDGUI.CheckModScroll = AddCheckButton(TrGCDGUI,"TOPRIGHT",-90,-80,"Scrolling icons","TrGCDCheckModScroll",TrufiGCDChSave["ModScroll"])
		TrGCDGUI.CheckModScroll:SetScript("OnClick", function () TrufiGCDChSave["ModScroll"] = ValueReverse(TrufiGCDChSave["ModScroll"]) end)
		TrGCDGUI.CheckModScroll.tooltipText = ('Icon will just disappear')
		-- check marks EnableIn: Enable, World, PvE, Arena, Bg
		TrGCDGUI.CheckEnableIn = {}
		TrGCDGUI.CheckEnableIn.Text = TrGCDGUI:CreateFontString(nil, "BACKGROUND")
		TrGCDGUI.CheckEnableIn.Text:SetFont("Fonts\\FRIZQT__.TTF", 12)
		TrGCDGUI.CheckEnableIn.Text:SetText("Enable in:")
		TrGCDGUI.CheckEnableIn.Text:SetPoint("TOPRIGHT", TrGCDGUI, "TOPRIGHT",-53, -175)
		TrGCDGUI.CheckEnableIn[0] = AddCheckButton(TrGCDGUI, "TOPRIGHT",-90,-140,"Enable addon","trgcdcheckenablein0",TrufiGCDChSave["EnableIn"]["Enable"])
		TrGCDGUI.CheckEnableIn[0]:SetScript("OnClick", function ()
			TrufiGCDChSave["EnableIn"]["Enable"] = ValueReverse(TrufiGCDChSave["EnableIn"]["Enable"])
			TrGCDCheckToEnableAddon(0)
		end)
		TrGCDGUI.CheckEnableIn[1] = AddCheckButton(TrGCDGUI, "TOPRIGHT",-90,-200,"World","trgcdcheckenablein1",TrufiGCDChSave["EnableIn"]["World"])
		TrGCDGUI.CheckEnableIn[1]:SetScript("OnClick", function ()
			TrufiGCDChSave["EnableIn"]["World"] = ValueReverse(TrufiGCDChSave["EnableIn"]["World"])
			TrGCDCheckToEnableAddon(1)
		end)
		TrGCDGUI.CheckEnableIn[2] = AddCheckButton(TrGCDGUI, "TOPRIGHT",-90,-230,"Party","trgcdcheckenablein2",TrufiGCDChSave["EnableIn"]["PvE"])
		TrGCDGUI.CheckEnableIn[2]:SetScript("OnClick", function ()
			TrufiGCDChSave["EnableIn"]["PvE"] = ValueReverse(TrufiGCDChSave["EnableIn"]["PvE"])
			TrGCDCheckToEnableAddon(2)
		end)
		TrGCDGUI.CheckEnableIn[5] = AddCheckButton(TrGCDGUI, "TOPRIGHT",-90,-260,"Raid","trgcdcheckenablein5",TrufiGCDChSave["EnableIn"]["Raid"])
		TrGCDGUI.CheckEnableIn[5]:SetScript("OnClick", function ()
			TrufiGCDChSave["EnableIn"]["Raid"] = ValueReverse(TrufiGCDChSave["EnableIn"]["Raid"])
			TrGCDCheckToEnableAddon(5)
		end)
		TrGCDGUI.CheckEnableIn[3] = AddCheckButton(TrGCDGUI, "TOPRIGHT",-90,-290,"Arena","trgcdcheckenablein3",TrufiGCDChSave["EnableIn"]["Arena"])
		TrGCDGUI.CheckEnableIn[3]:SetScript("OnClick", function ()
			TrufiGCDChSave["EnableIn"]["Arena"] = ValueReverse(TrufiGCDChSave["EnableIn"]["Arena"])
			TrGCDCheckToEnableAddon(3)
		end)
		TrGCDGUI.CheckEnableIn[4] = AddCheckButton(TrGCDGUI, "TOPRIGHT",-90,-320,"Battleground","trgcdcheckenablein4",TrufiGCDChSave["EnableIn"]["Bg"])
		TrGCDGUI.CheckEnableIn[4]:SetScript("OnClick", function ()
			TrufiGCDChSave["EnableIn"]["Bg"] = ValueReverse(TrufiGCDChSave["EnableIn"]["Bg"])
			TrGCDCheckToEnableAddon(4)
		end)
		-- labels for check marks, menu sliders
		for i=1,4 do
			_G["TrGCDGUI.Text" .. i] = TrGCDGUI:CreateFontString(nil, "BACKGROUND")
			_G["TrGCDGUI.Text" .. i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
		end
		_G["TrGCDGUI.Text1"]:SetText("Enable")
		_G["TrGCDGUI.Text1"]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",20, -65)
		_G["TrGADGET.Text2"]:SetText("Fade")
		_G["TrGCDGUI.Text2"]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",105, -65)
		_G["TrGCDGUI.Text3"]:SetText("Size icons")
		_G["TrGCDGUI.Text3"]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",245, -65)
		_G["TrGCDGUI.Text4"]:SetText("Number of icons")
		_G["TrGCDGUI.Text4"]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",390, -65)
		-- frame after clicking show / hide button
		TrGCDFixEnable = CreateFrame ("Frame", nil, UIParent)
		TrGCDFixEnable:SetHeight(50)
		TrGCDFixEnable:SetWidth(160)
		TrGCDFixEnable:SetPoint("TOP", UIParent, "TOP",0, -150)
		TrGCDFixEnable:Hide()
		TrGCDFixEnable:RegisterForDrag("LeftButton")
		TrGCDFixEnable:SetScript("OnDragStart", TrGCDFixEnable.StartMoving)
		TrGCDFixEnable:SetScript("OnDragStop", TrGCDFixEnable.StopMovingOrSizing)
		TrGCDFixEnable:SetMovable(true)
		TrGCDFixEnable:EnableMouse(true)
		TrGCDFixEnable.Texture = TrGCDFixEnable:CreateTexture(nil, "BACKGROUND")
		TrGCDFixEnable.Texture:SetAllPoints(TrGCDFixEnable)
		TrGCDFixEnable.Texture:SetColorTexture(0, 0, 0)
		TrGCDFixEnable.Texture:SetAlpha(0.5)
		TrGCDFixEnable.Button = AddButton(TrGCDFixEnable,"BOTTOM",0,5,22,150,"Return to options",12,"TrufiGCD")
		TrGCDFixEnable.Button:SetScript("OnClick", function () InterfaceOptionsFrame_OpenToCategory(TrGCDGUI) end)
		TrGCDFixEnable.Button.Text:SetPoint("TOP", TrGCDFixEnable, "TOP",0, -5)
		--checkbutton enable/disable
		TrGCDGUI.checkenable = {}
		TrGCDGUI.checkenablename = {}
		TrGCDGUI.menu = {}
		TrGCDGUI.sizeslider = {}
		TrGCDGUI.widthslider = {}
		for i=1,12 do
			TrGCDGUI.checkenable[i] = AddCheckButton(TrGCDGUI, "TOPLEFT",10,-50-i*40,TrGCDQueueOpt[i].text,("checkenable"..i),TrGCDQueueOpt[i].enable)
			TrGCDGUI.checkenable[i]:SetScript("OnClick", function () TrGCDCheckEnableClick(i) end)
			--dropdown menues
			TrGCDGUI.menu[i] = CreateFrame("FRAME", ("TrGCDGUImenu"..i), TrGCDGUI, "UIDropDownMenuTemplate")
			TrGCDGUI.menu[i]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",70, -50-i*40)
			UIDropDownMenu_SetWidth(TrGCDGUI.menu[i], 55)
			UIDropDownMenu_SetText(TrGCDGUI.menu[i], TrGCDQueueOpt[i].fade)
			UIDropDownMenu_Initialize(TrGCDGUI.menu[i], function(self, level, menuList)
				local info = UIDropDownMenu_CreateInfo()
				info.text = "Left"
				info.menuList = 1
				info.notCheckable = true
				info.func = function() TrGCDFadeMenuWasCheck(i, "Left") end
				UIDropDownMenu_AddButton(info)
				info.text = "Right"
				info.menuList = 2
				info.func = function() TrGCDFadeMenuWasCheck(i, "Right") end
				UIDropDownMenu_AddButton(info)
				info.text = "Up"
				info.menuList = 3
				info.func = function() TrGCDFadeMenuWasCheck(i, "Up") end
				UIDropDownMenu_AddButton(info)
				info.text = "Down"
				info.menuList = 4
				info.func = function() TrGCDFadeMenuWasCheck(i, "Down") end
				UIDropDownMenu_AddButton(info)
			end)
			--Size Slider
			TrGCDGUI.sizeslider[i] = CreateFrame("Slider", ("TrGCDGUIsizeslider" .. i), TrGCDGUI, "OptionsSliderTemplate")
			TrGCDGUI.sizeslider[i]:SetWidth(170)
			TrGCDGUI.sizeslider[i]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",190, -55-i*40)
			TrGCDGUI.sizeslider[i].tooltipText = ('Size icons ' .. TrGCDQueueOpt[i].text)
			getglobal(TrGCDGUI.sizeslider[i]:GetName() .. 'Low'):SetText('10')
			getglobal(TrGCDGUI.sizeslider[i]:GetName() .. 'High'):SetText('100')
			getglobal(TrGCDGUI.sizeslider[i]:GetName() .. 'Text'):SetText(TrGCDQueueOpt[i].size)
			TrGCDGUI.sizeslider[i]:SetMinMaxValues(10,100)
			TrGCDGUI.sizeslider[i]:SetValueStep(1)
			TrGCDGUI.sizeslider[i]:SetValue(TrGCDQueueOpt[i].size)
			TrGCDGUI.sizeslider[i]:SetScript("OnValueChanged", function (self,value) TrGCDSpSizeChanged(i,value) end)
			TrGCDGUI.sizeslider[i]:Show()
			--Width Slider
			TrGCDGUI.widthslider[i] = CreateFrame("Slider", ("TrGCDGUIwidthslider" .. i), TrGCDGUI, "OptionsSliderTemplate")
			TrGCDGUI.widthslider[i]:SetWidth(100)
			TrGCDGUI.widthslider[i]:SetPoint("TOPLEFT", TrGCDGUI, "TOPLEFT",390, -55-i*40)
			TrGCDGUI.widthslider[i].tooltipText = ('Spell icons in queue ' .. TrGCDQueueOpt[i].text)
			getglobal(TrGCDGUI.widthslider[i]:GetName() .. 'Low'):SetText('1')
			getglobal(TrGCDGUI.widthslider[i]:GetName() .. 'High'):SetText('8')
			getglobal(TrGCDGUI.widthslider[i]:GetName() .. 'Text'):SetText(TrGCDQueueOpt[i].width)
			TrGCDGUI.widthslider[i]:SetMinMaxValues(1,8)
			TrGCDGUI.widthslider[i]:SetValueStep(1)
			TrGCDGUI.widthslider[i]:SetValue(TrGCDQueueOpt[i].width)
			TrGCDGUI.widthslider[i]:SetScript("OnValueChanged", function (self,value) TrGCDSpWidthChanged(i,value) end)
			TrGCDGUI.widthslider[i]:Show()
		end
		InterfaceOptions_AddCategory(TrGCDGUI)
		-- add tab Spell Black List
		TrGCDGUI.BL = CreateFrame ("Frame", nil, UIParent, "OptionsBoxTemplate")
		TrGCDGUI.BL:Hide()
		TrGCDGUI.BL.name = "Blacklist"
		TrGCDGUI.BL.parent = "TrufiGCD"
		TrGCDGUI.BL.ScrollBD = CreateFrame ("Frame", nil, TrGCDGUI.BL, BackdropTemplateMixin and "BackdropTemplate")
		TrGCDGUI.BL.ScrollBD:SetPoint("TOPLEFT", TrGCDGUI.BL, "TOPLEFT",10, -25)
		TrGCDGUI.BL.ScrollBD:SetWidth(200)
		TrGCDGUI.BL.ScrollBD:SetHeight(501)
		TrGCDGUI.BL.ScrollBD:SetBackdrop({bgFile = nil,
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 0, right = 0, top = 0, bottom = 0}})
		TrGCDGUI.BL.Scroll = CreateFrame ("ScrollFrame", nil, TrGCDGUI.BL)
		TrGCDGUI.BL.Scroll:SetPoint("TOPLEFT", TrGCDGUI.BL, "TOPLEFT",10, -30)
		TrGCDGUI.BL.Scroll:SetWidth(200)
		TrGCDGUI.BL.Scroll:SetHeight(488)
		TrGCDGUI.BL.Scroll.ScrollBar = CreateFrame("Slider", "TrGCDBLScroll", TrGCDGUI.BL.Scroll, "UIPanelScrollBarTemplate")
		TrGCDGUI.BL.Scroll.ScrollBar:SetPoint("TOPLEFT", TrGCDGUI.BL.Scroll, "TOPRIGHT", 1, -16)
		TrGCDGUI.BL.Scroll.ScrollBar:SetPoint("BOTTOMLEFT", TrGCDGUI.BL.Scroll, "BOTTOMRIGHT", 1, 16)
		TrGCDGUI.BL.Scroll.ScrollBar:SetMinMaxValues(1, 470)
		TrGCDGUI.BL.Scroll.ScrollBar:SetValueStep(1)
		TrGCDGUI.BL.Scroll.ScrollBar.Bg = TrGCDGUI.BL.Scroll.ScrollBar:CreateTexture(nil, "BACKGROUND")
		TrGCDGUI.BL.Scroll.ScrollBar.Bg:SetAllPoints(TrGCDGUI.BL.Scroll.ScrollBar)
		TrGCDGUI.BL.Scroll.ScrollBar.Bg:SetColorTexture(0, 0, 0, 0.4)
		TrGCDGUI.BL.Scroll.ScrollBar:SetValue(0)
		TrGCDGUI.BL.Scroll.ScrollBar:SetScript("OnValueChanged", function (self, value)
			self:GetParent():SetVerticalScroll(value)
		end)
		TrGCDGUI.BL.List = CreateFrame ("Frame", nil, TrGCDGUI.BL.Scroll)
		--TrGCDGUI.BL.List:SetPoint("TOPLEFT", TrGCDGUI.BL.Scroll, "TOPLEFT",10, -35)
		TrGCDGUI.BL.List:SetWidth(200)
		TrGCDGUI.BL.List:SetHeight(958)
		TrGCDGUI.BL.List.Text = TrGCDGUI.BL.List:CreateFontString(nil, "BACKGROUND")
		TrGCDGUI.BL.List.Text:SetFont("Fonts\\FRIZQT__.TTF", 12)
		TrGCDGUI.BL.List.Text:SetText("Blacklist")
		TrGCDGUI.BL.List.Text:SetPoint("TOPLEFT", TrGCDGUI.BL.List, "TOPLEFT", 15, 15)
		TrGCDGUI.BL.Spell = {}
		TrGCDGUI.BL.TextSpell = TrGCDGUI.BL:CreateFontString(nil, "BACKGROUND")
		TrGCDGUI.BL.TextSpell:SetFont("Fonts\\FRIZQT__.TTF", 12)
		TrGCDGUI.BL.TextSpell:SetText("Select spell")
		TrGCDGUI.BL.Delete = AddButton(TrGCDGUI.BL,"TOPLEFT",260,-130,22,100,"Delete")
		TrGCDGUI.BL.TextSpell:SetPoint("TOPLEFT", TrGCDGUI.BL.Delete, "TOPLEFT", 5, 15)
		for i=1,60 do
			TrGCDGUI.BL.Spell[i] = AddButton(TrGCDGUI.BL.List,"TOP",0,(-(i-1)*16),15,192,_,11," ",true)
			TrGCDGUI.BL.Spell[i]:Disable()
			TrGCDGUI.BL.Spell[i].Number = i
			TrGCDGUI.BL.Spell[i].Text:SetAllPoints(TrGCDGUI.BL.Spell[i])
			TrGCDGUI.BL.Spell[i].Texture = TrGCDGUI.BL.Spell[i]:CreateTexture(nil, "BACKGROUND")
			TrGCDGUI.BL.Spell[i].Texture:SetAllPoints(TrGCDGUI.BL.Spell[i])
			TrGCDGUI.BL.Spell[i].Texture:SetColorTexture(255, 210, 0)
			TrGCDGUI.BL.Spell[i].Texture:SetAlpha(0)
			TrGCDGUI.BL.Spell[i]:SetScript("OnEnter", function (self) if (BLSpSel ~= self) then self.Texture:SetAlpha(0.3) end end)
			TrGCDGUI.BL.Spell[i]:SetScript("OnLeave", function (self) if (BLSpSel ~= self) then self.Texture:SetAlpha(0) end end)
			TrGCDGUI.BL.Spell[i]:SetScript("OnClick", function (self)
				if (BLSpSel ~= nil) then BLSpSel.Texture:SetAlpha(0) end
				BLSpSel = self
				self.Texture:SetAlpha(0.6)
				TrGCDGUI.BL.TextSpell:SetText(self.Text:GetText())
			end)
		end
		TrGCDLoadBlackList()
		TrGCDGUI.BL.Delete:SetScript("OnClick", function ()
			if (BLSpSel ~= nil) then
				table.remove(TrGCDBL, BLSpSel.Number)
				TrGCDGUI.BL.TextSpell:SetText("Select spell")
				TrGCDLoadBlackList()
			end
		end)
		TrGCDGUI.BL.Scroll:SetScrollChild(TrGCDGUI.BL.List)
		TrGCDGUI.BL.AddEdit = CreateFrame("EditBox", nil, TrGCDGUI.BL, "InputBoxTemplate")
		TrGCDGUI.BL.AddEdit:SetWidth(200)
		TrGCDGUI.BL.AddEdit:SetHeight(20)
		TrGCDGUI.BL.AddEdit:SetPoint("TOPLEFT", TrGCDGUI.BL, "TOPLEFT", 265, -200)
		TrGCDGUI.BL.AddEdit:SetAutoFocus(false)
		TrGCDGUI.BL.AddButt = AddButton(TrGCDGUI.BL,"TOPLEFT",260,-225,22,100,"Add",12,"Enter spell name or spell ID")
		TrGCDGUI.BL.AddButt.Text:SetPoint("TOPLEFT",TrGCDGUI.BL.AddButt,"TOPLEFT", 5, 40)
		TrGCDGUI.BL.AddButt:SetScript("OnClick", function (self) TrGCDBLAddSpell(self) end)
		TrGCDGUI.BL.AddEdit:SetScript("OnEnterPressed", function (self) TrGCDBLAddSpell(self) end)
		TrGCDGUI.BL.AddEdit:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
		TrGCDGUI.BL.AddButt.Text2 = TrGCDGUI.BL.List:CreateFontString(nil, "BACKGROUND")
		TrGCDGUI.BL.AddButt.Text2:SetFont("Fonts\\FRIZQT__.TTF", 11)
		-- TrGCDGUI.BL.AddButt.Text2:SetText("Blacklist can be loaded from the saved settings,\nbut does not restore the default.")
		TrGCDGUI.BL.AddButt.Text2:SetPoint("BOTTOMLEFT", TrGCDGUI.BL.AddButt, "BOTTOMLEFT", 0, -35)
		-- button for loading the settings saved in the cache
		TrGCDGUI.BL.ButtonLoad = AddButton(TrGCDGUI.BL,"TOPRIGHT",-145,-30,22,100,"Load",10,"Load saving blacklist")
		TrGCDGUI.BL.ButtonLoad:SetScript("OnClick", TrGCDBLLoadSetting)
		-- buttons for saving settings to cache
		TrGCDGUI.BL.ButtonSave = AddButton(TrGCDGUI.BL,"TOPRIGHT",-260,-30,22,100,"Save",10,"Save blacklist to cache")
		TrGCDGUI.BL.ButtonSave:SetScript("OnClick", TrGCDBLSaveSetting)
		-- restore default button
		TrGCDGUI.BL.ButtonRes = AddButton(TrGCDGUI.BL,"TOPRIGHT",-30,-30,22,100,"Default",10,"Restore default blacklist")
		TrGCDGUI.BL.ButtonRes:SetScript("OnClick", function () TrGCDBLDefaultSetting() TrGCDLoadBlackList() end)
		InterfaceOptions_AddCategory(TrGCDGUI.BL)

		-- Creating event enter arena/bg event frame
		TrGCDEnterEventFrame = CreateFrame("Frame", nil, UIParent)
		TrGCDEnterEventFrame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
		TrGCDEnterEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		TrGCDEnterEventFrame:SetScript("OnEvent", TrGCDEnterEventHandler) --check addon whether enable or not

		-- Creating event spell frame
		TrGCDEventFrame = CreateFrame("Frame", nil, UIParent)
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_START") -- Fired when a unit begins casting a non-instant cast spell, including party/raid members or the player.
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") -- Fired when a spell is cast successfully. Event is received even if spell is resisted.
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_STOP") -- Fired when a unit stops casting, including party/raid members or the player.
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP") -- Fired when a unit stops channeling. Received for party/raid members as well as the player.
		TrGCDEventFrame:SetScript("OnEvent", TrGCDEventHandler)
		TrGCDEventFrame:SetScript("OnUpdate", TrGCDUpdate)
		TrGCDEventBuffFrame = CreateFrame("Frame", nil, UIParent)
		TrGCDEventBuffFrame:RegisterEvent("UNIT_AURA")
		TrGCDEventBuffFrame:SetScript("OnEvent", TrGCDEventBuffHandler)
		--Creating TrGCDQueueFrame i =
		--1 - player, 2 - party1, 3 - party2
		--5 - arena1, 6 - arena2, 7 - arena3
		--11 - target, 12 - focus
		TrGCDQueueFrame = {}
		TrGCDIcon = {}
		TrGCDi = {} -- counter TrGCDIcons
		TrGCDQueueFirst = {} -- spell queue for first place
		TrGCDQueueFirstIndex = {} -- the beginning of the queue, then it is shifted, as the spell passes in TrGCDQueueFrame
		for i=1,12 do
			--if (TrGCDQueueOpt[i].enable) then
				TrGCDQueueFrame[i] = CreateFrame("Frame", nil, UIParent)
				TrGCDResizeQueueFrame(i)
				TrGCDQueueFrame[i].texture = TrGCDQueueFrame[i]:CreateTexture(nil, "BACKGROUND")
				TrGCDQueueFrame[i].texture:SetAllPoints(TrGCDQueueFrame[i])
				TrGCDQueueFrame[i].texture:SetColorTexture(0, 0, 0)
				TrGCDQueueFrame[i].texture:SetAlpha(0)
				TrGCDQueueFrame[i].text = TrGCDQueueFrame[i]:CreateFontString(nil, "BACKGROUND")
				TrGCDQueueFrame[i].text:SetFont("Fonts\\FRIZQT__.TTF", 9)
				TrGCDQueueFrame[i].text:SetText(TrGCDQueueOpt[i].text)
				TrGCDQueueFrame[i].text:SetAllPoints(TrGCDQueueFrame[i])
				TrGCDQueueFrame[i].text:SetAlpha(0)
				TrGCDQueueFrame[i]:RegisterForDrag("LeftButton")
				TrGCDQueueFrame[i]:SetScript("OnDragStart", TrGCDQueueFrame[i].StartMoving)
				TrGCDQueueFrame[i]:SetScript("OnDragStop", TrGCDQueueFrame[i].StopMovingOrSizing)
				TrGCDQueueFrame[i]:SetPoint(TrGCDQueueOpt[i].point, UIParent, TrGCDQueueOpt[i].point, TrGCDQueueOpt[i].x, TrGCDQueueOpt[i].y)
				--TrGCDIcon[i]
				TrGCDIcon[i] = {}
				TrGCDi[i] = 1
				TrGCDSpStop[i] = 0
				TrGCDSpStopTime[i] = GetTime()
				TrGCDCastSpBanTime[i] = GetTime()
				TrGCDInsSp["time"][i] = GetTime()
				TrGCDIconOnEnter[i] = true
				TrGCDTimeuseSpamSpell[i] = {}
				for k = 1,10 do
					TrGCDIcon[i][k] = CreateFrame("Button", nil, TrGCDQueueFrame[i])
					TrGCDIcon[i][k]:SetHeight(TrGCDQueueOpt[i].size)
					TrGCDIcon[i][k]:SetWidth(TrGCDQueueOpt[i].size)
					TrGCDIcon[i][k].texture = TrGCDIcon[i][k]:CreateTexture(nil, "BACKGROUND")
					TrGCDIcon[i][k].texture:SetAllPoints(TrGCDIcon[i][k])
					TrGCDIcon[i][k].texture2 = TrGCDIcon[i][k]:CreateTexture(nil, "BORDER")
					TrGCDIcon[i][k].texture2:SetAllPoints(TrGCDIcon[i][k].texture)
					TrGCDIcon[i][k].texture2:SetTexture(cross)
					TrGCDIcon[i][k].texture2:SetAlpha(1)
					TrGCDIcon[i][k].texture2:Hide()
					TrGCDIcon[i][k].texture2.show = false
					TrGCDIcon[i][k]:Hide()
					TrGCDIcon[i][k].show = false
					TrGCDIcon[i][k].x = 0
					TrGCDIcon[i][k].TimeStart = 0
					TrGCDIcon[i][k].spellID = 0
					TrGCDIcon[i][k]:SetScript("OnEnter", function (self)
						if (TrufiGCDChSave["TooltipEnable"] == true) then
							GameTooltip_SetDefaultAnchor(GameTooltip, self)
							GameTooltip:SetSpellByID(self.spellID, false, false, true)
							GameTooltip:Show()
							if (TrufiGCDChSave["TooltipStopMove"] == true) then
								TrGCDIconOnEnter[i] = false
							end
							if (TrufiGCDChSave["TooltipSpellID"] == true) then
								if (self.spellID ~= nil) then print(GetSpellLink(self.spellID) .. ' ID: ' .. self.spellID) end
							end
						end
					end)
					TrGCDIcon[i][k]:SetScript("OnLeave", function () GameTooltip_Hide() TrGCDIconOnEnter[i] = true end)
					if Masque then TrGCDMasqueIcons:AddButton(TrGCDIcon[i][k], {Icon = TrGCDIcon[i][k].texture}) end
				end
				TrGCDQueueFirst[i] = {}
				TrGCDQueueFirstIndex[i] = 1 -- the beginning of the queue, then it is shifted, as the spell passes in TrGCDQueueFrame
				TrGCDBufferIcon[i] = 0.0
				TrGCDCastSp[i] = 1 -- 0 - каст идет, 1 - каст прошел и не идет
			--end
		end
		TrGCDQueueFrame[11]:RegisterEvent("PLAYER_TARGET_CHANGED")
		TrGCDQueueFrame[11]:SetScript("OnEvent", function()
			TrGCDClear(11)
			if (TrGCDQueueOpt[11].enable) then TrGCDPlayerTarFocDetect(11) end
		end)
		if (not isClassic) then
			TrGCDQueueFrame[12]:RegisterEvent("PLAYER_FOCUS_CHANGED")
		end
		TrGCDQueueFrame[12]:SetScript("OnEvent", function()
			TrGCDClear(12)
			if (TrGCDQueueOpt[12].enable) then TrGCDPlayerTarFocDetect(12) end
		end)
	end
end

function TrGCDCheckToEnableAddon(t) -- checks the checkboxes EnableIn and from this whether the addon is already enabled
	if (TrufiGCDChSave["EnableIn"]["Enable"] == false) then TrGCDEnable = false
	elseif (PlayerDislocation == 1) then TrGCDEnable = TrufiGCDChSave["EnableIn"]["World"]
	elseif (PlayerDislocation == 2) then TrGCDEnable = TrufiGCDChSave["EnableIn"]["PvE"]
	elseif (PlayerDislocation == 3) then TrGCDEnable = TrufiGCDChSave["EnableIn"]["Arena"]
	elseif (PlayerDislocation == 4) then TrGCDEnable = TrufiGCDChSave["EnableIn"]["Bg"]
	elseif (PlayerDislocation == 5) then TrGCDEnable = TrufiGCDChSave["EnableIn"]["Raid"]
	end
	if (t ~= nil) then
		if ((PlayerDislocation == t) or (t == 0)) then
			for i=1,12 do TrGCDClear(i) end
		end
	end
end

function TrGCDEnterEventHandler(self, event, ...) -- an event when a player enters a BG, arena, pve, or vice versa exits
	local _, PlayerLocation = IsInInstance()
	if (event == "PLAYER_ENTERING_BATTLEGROUND") then
		if (PlayerLocation == "arena") then
			PlayerDislocation = 3
			if (TrufiGCDChSave["EnableIn"]["Arena"]) then TrGCDEnable = true
			else TrGCDEnable = false end
		elseif (PlayerLocation == "pvp") then
			PlayerDislocation = 4
			if (TrufiGCDChSave["EnableIn"]["Bg"]) then TrGCDEnable = true
			else TrGCDEnable = false end
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		if (PlayerLocation == "party") then
			PlayerDislocation = 2
			if (TrufiGCDChSave["EnableIn"]["PvE"]) then TrGCDEnable = true
			else TrGCDEnable = false end
		elseif (PlayerLocation == "raid") then
			PlayerDislocation = 5
			if (TrufiGCDChSave["EnableIn"]["Raid"]) then TrGCDEnable = true
			else TrGCDEnable = false end
		elseif ((PlayerLocation ~= "arena") or (PlayerLocation ~= "pvp")) then
			PlayerDislocation = 1
			if (TrufiGCDChSave["EnableIn"]["World"]) then TrGCDEnable = true
			else TrGCDEnable = false end
		end
	end
end

function TrGCDLoadBlackList() -- loading blacklist
	for i=1,60 do
		if (TrGCDBL[i] ~= nil) then
			local spellname = GetSpellInfo(TrGCDBL[i])
			if (spellname == nil) then spellname = TrGCDBL[i] end
			TrGCDGUI.BL.Spell[i]:Enable()
			TrGCDGUI.BL.Spell[i].Text:SetText(spellname)
		else
			TrGCDGUI.BL.Spell[i]:Disable()
			TrGCDGUI.BL.Spell[i].Text:SetText(nil)
			TrGCDGUI.BL.Spell[i].Texture:SetAlpha(0)
		end
	end
end

function TrGCDBLAddSpell(self)
	if (TrGCDGUI.BL.AddEdit:GetText() ~= nil) then
		local spellname = TrGCDGUI.BL.AddEdit:GetText()
		if (#TrGCDBL < 60) then
		--local spellicon = select(3, GetSpellInfo(TrGCDGUI.BL.AddEdit:GetText()))
		--if (spellicon ~= nil) then
			table.insert(TrGCDBL, spellname)
			TrGCDLoadBlackList()
			--TrGCDGUI.BL.AddEdit:SetText("")
			TrGCDGUI.BL.AddEdit:ClearFocus()
			--TrGCDGUI.BL.AddButt.Text2:SetText()
		--else TrGCDGUI.BL.AddButt.Text2:SetText('Spell not find, please try again.') end
		end
	end
end

function TrGCDBLSaveSetting()
	if (TrufiGCDGlSave == nil) then TrufiGCDGlSave = {} end
	TrufiGCDGlSave["TrGCDBL"] = {}
	for i=1,#TrGCDBL do	TrufiGCDGlSave["TrGCDBL"][i] = TrufiGCDChSave["TrGCDBL"][i]	end
end

function TrGCDBLLoadSetting()
	if ((TrufiGCDChSave ~= nil) and (TrufiGCDGlSave["TrGCDQueueFrame"] ~= nil)) then
		for i=1,#TrufiGCDGlSave["TrGCDBL"] do TrufiGCDChSave["TrGCDBL"][i] = TrufiGCDGlSave["TrGCDBL"][i] end
		if (#TrufiGCDGlSave["TrGCDBL"] < #TrufiGCDChSave["TrGCDBL"]) then
			for i=(#TrufiGCDGlSave["TrGCDBL"]+1),#TrufiGCDChSave["TrGCDBL"] do TrufiGCDChSave["TrGCDBL"][i] = nil end
		end
		TrGCDLoadBlackList()
	end
end

function TrGCDBLDefaultSetting()
	if (TrufiGCDChSave == nil) then TrufiGCDChSave = {} end
	TrufiGCDChSave["TrGCDBL"] = {}
	TrGCDBL = TrufiGCDChSave["TrGCDBL"]
	TrGCDBL[1] = 6603 --автоатака
	TrGCDBL[2] = 75 --автовыстрел
	TrGCDBL[3] = 7384 --превосходствo
end

function TrGCDSaveSettings()
	if (TrufiGCDGlSave == nil) then TrufiGCDGlSave = {} end
	TrufiGCDGlSave["TrGCDQueueFrame"] = {}
	for i=1,12 do
		TrufiGCDGlSave["TrGCDQueueFrame"][i] = {}
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["x"] = TrGCDQueueOpt[i].x
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["y"] = TrGCDQueueOpt[i].y
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["point"] = TrGCDQueueOpt[i].point
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["enable"] = TrGCDQueueOpt[i].enable
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["text"] = TrGCDQueueOpt[i].text
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["fade"] = TrGCDQueueOpt[i].fade
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["size"] = TrGCDQueueOpt[i].size
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["width"] = TrGCDQueueOpt[i].width
		TrufiGCDGlSave["TrGCDQueueFrame"][i]["speed"] = TrGCDQueueOpt[i].speed
	end
	TrufiGCDGlSave["TooltipEnable"] = TrufiGCDChSave["TooltipEnable"]
	TrufiGCDGlSave["TooltipStopMove"] = TrufiGCDChSave["TooltipStopMove"]
	TrufiGCDGlSave["TooltipSpellID"] = TrufiGCDChSave["TooltipSpellID"]
	TrufiGCDGlSave["EnableIn"] = {}
	TrufiGCDGlSave["EnableIn"]["PvE"] = TrufiGCDChSave["EnableIn"]["PvE"]
	TrufiGCDGlSave["EnableIn"]["Raid"] = TrufiGCDChSave["EnableIn"]["Raid"]
	TrufiGCDGlSave["EnableIn"]["Arena"] = TrufiGCDChSave["EnableIn"]["Arena"]
	TrufiGCDGlSave["EnableIn"]["Bg"] = TrufiGCDChSave["EnableIn"]["Bg"]
	TrufiGCDGlSave["EnableIn"]["World"] = TrufiGCDChSave["EnableIn"]["World"]
	TrufiGCDGlSave["EnableIn"]["Enable"] = TrufiGCDChSave["EnableIn"]["Enable"]
	TrufiGCDGlSave["ModScroll"] = TrufiGCDChSave["ModScroll"]
end

function TrGCDLoadSettings()
	if ((TrufiGCDGlSave ~= nil) and (TrufiGCDGlSave["TrGCDQueueFrame"] ~= nil)) then
		for i=1,12 do
			TrGCDQueueOpt[i].x = TrufiGCDGlSave["TrGCDQueueFrame"][i]["x"]
			TrGCDQueueOpt[i].y = TrufiGCDGlSave["TrGCDQueueFrame"][i]["y"]
			TrGCDQueueOpt[i].point = TrufiGCDGlSave["TrGCDQueueFrame"][i]["point"]
			TrGCDQueueOpt[i].enable = TrufiGCDGlSave["TrGCDQueueFrame"][i]["enable"]
			TrGCDQueueOpt[i].text = TrufiGCDGlSave["TrGCDQueueFrame"][i]["text"]
			TrGCDQueueOpt[i].fade = TrufiGCDGlSave["TrGCDQueueFrame"][i]["fade"]
			TrGCDQueueOpt[i].size = TrufiGCDGlSave["TrGCDQueueFrame"][i]["size"]
			TrGCDQueueOpt[i].width = TrufiGCDGlSave["TrGCDQueueFrame"][i]["width"]
			TrGCDQueueOpt[i].speed = TrufiGCDGlSave["TrGCDQueueFrame"][i]["speed"]
			TrufiGCDChSave["TrGCDQueueFrame"] = TrGCDQueueOpt
		end
		if (TrufiGCDGlSave["EnableIn"] ~= nil) then
			TrufiGCDChSave["TooltipEnable"] = TrufiGCDGlSave["TooltipEnable"]
			TrufiGCDChSave["EnableIn"] = {}
			TrufiGCDChSave["EnableIn"]["PvE"] = TrufiGCDGlSave["EnableIn"]["PvE"]
			TrufiGCDChSave["EnableIn"]["Arena"] = TrufiGCDGlSave["EnableIn"]["Arena"]
			TrufiGCDChSave["EnableIn"]["Bg"] = TrufiGCDGlSave["EnableIn"]["Bg"]
			TrufiGCDChSave["EnableIn"]["World"] = TrufiGCDGlSave["EnableIn"]["World"]
			TrufiGCDChSave["EnableIn"]["Enable"] = TrufiGCDGlSave["EnableIn"]["Enable"]
			if (TrufiGCDGlSave["EnableIn"]["Raid"] ~= nil) then
				TrufiGCDChSave["EnableIn"]["Raid"] = TrufiGCDGlSave["EnableIn"]["Raid"]
				TrufiGCDChSave["TooltipStopMove"] = TrufiGCDGlSave["TooltipStopMove"]
				TrufiGCDChSave["TooltipSpellID"] = TrufiGCDGlSave["TooltipSpellID"]
			end
		end
		if (TrufiGCDGlSave["ModScroll"] ~= nil) then
			TrufiGCDChSave["ModScroll"] = TrufiGCDGlSave["ModScroll"]
		end
		TrGCDUploadViewSetting()
	end
end

function TrGCDRestoreDefaultSettings() -- restore default settings
	if (TrufiGCDChSave == nil) then TrufiGCDChSave = {} end
	TrufiGCDChSave["TrGCDQueueFrame"] = {}
	TrufiGCDChSave["TooltipEnable"] = true
	TrufiGCDChSave["TooltipStopMove"] = true
	TrufiGCDChSave["TooltipSpellID"] = false
	for i=1,12 do
		TrufiGCDChSave["TrGCDQueueFrame"][i] = {}
		TrGCDQueueOpt[i] = {}
		TrGCDQueueOpt[i].x = 0
		TrGCDQueueOpt[i].y = 0
		TrGCDQueueOpt[i].point = "CENTER"
		TrGCDQueueOpt[i].enable = true
		if (i==1) then TrGCDQueueOpt[i].text = "Player" end
		if (i>1 and i<=5) then TrGCDQueueOpt[i].text = "Party " .. i-1 end
		if (i>5 and i<=10) then TrGCDQueueOpt[i].text = "Arena " .. i-5 end
		if (i==11) then TrGCDQueueOpt[i].text = "Target" end
		if (i==12) then TrGCDQueueOpt[i].text = "Focus" end
		TrGCDQueueOpt[i].fade = "Left"
		TrGCDQueueOpt[i].size = 30
		TrGCDQueueOpt[i].width = 3
		TrGCDQueueOpt[i].speed = TrGCDQueueOpt[i].size / TimeGcd
		TrufiGCDChSave["TrGCDQueueFrame"][i]["x"] = TrGCDQueueOpt[i].x
		TrufiGCDChSave["TrGCDQueueFrame"][i]["y"] = TrGCDQueueOpt[i].y
		TrufiGCDChSave["TrGCDQueueFrame"][i]["point"] = TrGCDQueueOpt[i].point
		TrufiGCDChSave["TrGCDQueueFrame"][i]["enable"] = TrGCDQueueOpt[i].enable
		TrufiGCDChSave["TrGCDQueueFrame"][i]["text"] = TrGCDQueueOpt[i].text
		TrufiGCDChSave["TrGCDQueueFrame"][i]["fade"] = TrGCDQueueOpt[i].fade
		TrufiGCDChSave["TrGCDQueueFrame"][i]["size"] = TrGCDQueueOpt[i].size
		TrufiGCDChSave["TrGCDQueueFrame"][i]["width"] = TrGCDQueueOpt[i].width
		TrufiGCDChSave["TrGCDQueueFrame"][i]["speed"] = TrGCDQueueOpt[i].speed
	end
	TrufiGCDChSave["EnableIn"] = {}
	TrufiGCDChSave["EnableIn"]["PvE"] = true
	TrufiGCDChSave["EnableIn"]["Raid"] = true
	TrufiGCDChSave["EnableIn"]["Arena"] = true
	TrufiGCDChSave["EnableIn"]["Bg"] = true
	TrufiGCDChSave["EnableIn"]["World"] = true
	TrufiGCDChSave["EnableIn"]["Enable"] = true
	TrufiGCDChSave["ModScroll"] = true
end

function TrGCDUploadViewSetting()
	TrGCDGUI.CheckTooltip:SetChecked(TrufiGCDChSave["TooltipEnable"])
	TrGCDGUI.CheckTooltipMove:SetChecked(TrufiGCDChSave["TooltipStopMove"])
	TrGCDGUI.CheckTooltipID:SetChecked(TrufiGCDChSave["TooltipSpellID"])
	for i=1,12 do
		getglobal(TrGCDGUI.sizeslider[i]:GetName() .. 'Text'):SetText(TrGCDQueueOpt[i].size)
		TrGCDGUI.sizeslider[i]:SetValue(TrGCDQueueOpt[i].size)
		getglobal(TrGCDGUI.widthslider[i]:GetName() .. 'Text'):SetText(TrGCDQueueOpt[i].width)
		TrGCDGUI.widthslider[i]:SetValue(TrGCDQueueOpt[i].width)
		UIDropDownMenu_SetText(TrGCDGUI.menu[i], TrGCDQueueOpt[i].fade)
		TrGCDGUI.checkenable[i]:SetChecked(TrGCDQueueOpt[i].enable)
		TrGCDCheckEnableClick(i)
		TrGCDCheckEnableClick(i)
		TrGCDResizeQueueFrame(i)
		TrGCDClear(i)
		TrGCDQueueFrame[i]:ClearAllPoints()
		TrGCDQueueFrame[i]:SetPoint(TrGCDQueueOpt[i].point, UIParent, TrGCDQueueOpt[i].point, TrGCDQueueOpt[i].x, TrGCDQueueOpt[i].y)
	end
	TrGCDGUI.CheckEnableIn[0]:SetChecked(TrufiGCDChSave["EnableIn"]["Enable"])
	TrGCDGUI.CheckEnableIn[1]:SetChecked(TrufiGCDChSave["EnableIn"]["World"])
	TrGCDGUI.CheckEnableIn[2]:SetChecked(TrufiGCDChSave["EnableIn"]["PvE"])
	TrGCDGUI.CheckEnableIn[3]:SetChecked(TrufiGCDChSave["EnableIn"]["Arena"])
	TrGCDGUI.CheckEnableIn[4]:SetChecked(TrufiGCDChSave["EnableIn"]["Bg"])
	TrGCDGUI.CheckEnableIn[5]:SetChecked(TrufiGCDChSave["EnableIn"]["Raid"])
	TrGCDGUI.CheckModScroll:SetChecked(TrufiGCDChSave["ModScroll"])
end

function TrGCDResizeQueueFrame(i) -- resize after resizing the TrGCDQueueFrame queue
	if ((TrGCDQueueOpt[i].fade == "Left") or (TrGCDQueueOpt[i].fade == "Right")) then
		TrGCDQueueFrame[i]:SetHeight(TrGCDQueueOpt[i].size)
		TrGCDQueueFrame[i]:SetWidth(TrGCDQueueOpt[i].width*TrGCDQueueOpt[i].size)
	elseif ((TrGCDQueueOpt[i].fade == "Up") or (TrGCDQueueOpt[i].fade == "Down")) then
		TrGCDQueueFrame[i]:SetHeight(TrGCDQueueOpt[i].width*TrGCDQueueOpt[i].size)
		TrGCDQueueFrame[i]:SetWidth(TrGCDQueueOpt[i].size)
	end
	if Masque then TrGCDMasqueIcons:ReSkin() end
end

function TrGCDSpSizeChanged(i,value) -- resized skill icons
	value = math.ceil(value);
	getglobal(TrGCDGUI.sizeslider[i]:GetName() .. 'Text'):SetText(value)
	TrGCDQueueOpt[i].size = value
	TrufiGCDChSave["TrGCDQueueFrame"][i]["size"] = value
	TrGCDQueueOpt[i].speed = TrGCDQueueOpt[i].size / TimeGcd
	TrufiGCDChSave["TrGCDQueueFrame"][i]["speed"] = TrGCDQueueOpt[i].speed
	TrGCDResizeQueueFrame(i)
	TrGCDClear(i)
end

function TrGCDSpWidthChanged(i,value) -- spell queue length changed
	value = math.ceil(value);
	getglobal(TrGCDGUI.widthslider[i]:GetName() .. 'Text'):SetText(value)
	TrGCDQueueOpt[i].width = value
	TrufiGCDChSave["TrGCDQueueFrame"][i]["width"] = value
	TrGCDResizeQueueFrame(i)
	TrGCDClear(i)
end

function TrGCDFadeMenuWasCheck(i, str) -- selected line in the ability fade direction menu
	TrGCDClear(i)
	UIDropDownMenu_SetText(TrGCDGUI.menu[i], str)
	TrGCDQueueOpt[i].fade = str
	TrufiGCDChSave["TrGCDQueueFrame"][i]["fade"] = str
	TrGCDResizeQueueFrame(i)
end

function TrGCDCheckEnableClick(i) -- there was a click on the checkboxes on / off frames
	if (TrGCDQueueOpt[i].enable) then
		if (TrGCDGUI.buttonfix:GetText() == "Hide") then
			TrGCDQueueFrame[i]:SetMovable(false)
			TrGCDQueueFrame[i]:EnableMouse(false)
			TrGCDQueueFrame[i].texture:SetAlpha(0)
			TrGCDQueueFrame[i].text:SetAlpha(0)
		end
		TrGCDQueueOpt[i].enable = false
		TrufiGCDChSave["TrGCDQueueFrame"][i]["enable"] = TrGCDQueueOpt[i].enable
	else
		if (TrGCDGUI.buttonfix:GetText() == "Hide") then
			TrGCDQueueFrame[i]:SetMovable(true)
			TrGCDQueueFrame[i]:EnableMouse(true)
			TrGCDQueueFrame[i].texture:SetAlpha(0.5)
			TrGCDQueueFrame[i].text:SetAlpha(0.5)
		end
		TrGCDQueueOpt[i].enable = true
		TrufiGCDChSave["TrGCDQueueFrame"][i]["enable"] = TrGCDQueueOpt[i].enable
	end
	TrGCDClear(i)
end

function TrGCDGUIButtonFixClick() -- show / hide button function in options
	if 	(TrGCDGUI.buttonfix:GetText() == "Show") then
		TrGCDGUI.buttonfix:SetText("Hide")
		TrGCDFixEnable:Show()
		for i=1,12 do
			if (TrGCDQueueOpt[i].enable) then
				TrGCDQueueFrame[i]:SetMovable(true)
				TrGCDQueueFrame[i]:EnableMouse(true)
				TrGCDQueueFrame[i].texture:SetAlpha(0.5)
				TrGCDQueueFrame[i].text:SetAlpha(0.5)
			end
		end
	else
		TrGCDGUI.buttonfix:SetText("Show")
		TrGCDFixEnable:Hide()
		for i=1,12 do
			if (TrGCDQueueOpt[i].enable) then
				TrGCDQueueFrame[i]:SetMovable(false)
				TrGCDQueueFrame[i]:EnableMouse(false)
				TrGCDQueueFrame[i].texture:SetAlpha(0)
				TrGCDQueueFrame[i].text:SetAlpha(0)
				TrGCDQueueOpt[i].point, _, _, TrGCDQueueOpt[i].x, TrGCDQueueOpt[i].y = TrGCDQueueFrame[i]:GetPoint()
				TrufiGCDChSave["TrGCDQueueFrame"][i]["x"] = TrGCDQueueOpt[i].x
				TrufiGCDChSave["TrGCDQueueFrame"][i]["y"] = TrGCDQueueOpt[i].y
				TrufiGCDChSave["TrGCDQueueFrame"][i]["point"] = TrGCDQueueOpt[i].point
				TrufiGCDChSave["TrGCDQueueFrame"][i]["enable"] = TrGCDQueueOpt[i].enable
			end
		end
	end
end

function TrGCDClear(i)
	TrGCDCastSp[i] = 1
	for k=1,10 do
		TrGCDIcon[i][k].show = false
		TrGCDIcon[i][k]:SetAlpha(0)
		TrGCDIcon[i][k].x = 0
		TrGCDIcon[i][k]:SetHeight(TrGCDQueueOpt[i].size)
		TrGCDIcon[i][k]:SetWidth(TrGCDQueueOpt[i].size)
		TrGCDIcon[i][k]:ClearAllPoints()
		TrGCDIcon[i][k]:Hide()
		TrGCDi[i] = 1
		TrGCDQueueFirst[i] = {}
		TrGCDQueueFirstIndex[i] = 1
		TrGCDIcon[i][k].texture:SetTexture(nil)
		TrGCDIcon[i][k].texture2:Hide()
		--TrGCDIcon[i][k]:SetPoint("LEFT", TrGCDQueueFrame[i], "LEFT",0,0)
	end
end

local function TrGCDCheckForEual(a,b) -- unit equivalence check - name, xn
	local t = false
	if ((UnitName(a) == UnitName(b)) and (UnitName(a)~= nil) and (UnitName(b) ~= nil)) then
		if (UnitHealth(a) == UnitHealth(b)) then t = true end
	end
	return t
end

function TrGCDPlayerTarFocDetect(k) -- check if there is a target or focus already in frames (party or arena)
	--k = 11 - target, 12 - focus
	local t = "null"
	local i = 0
	if (k == 11) then t = "target" end
	if (k == 12) then t = "focus" end
	if (TrGCDCheckForEual(t,"player")) then i = 1 end
	for j=2,5 do if (TrGCDCheckForEual(t,("party"..j-1))) then i = j end end
	for j=6,10 do if (TrGCDCheckForEual(t,("arena"..j-5))) then i = j end end
	if ((k ~= 11) and TrGCDCheckForEual(t,"target")) then i = 11 end
	if ((k~= 12) and TrGCDCheckForEual(t,"focus")) then i = 12 end
	if (i ~= 0) then -- если есть то копипаст всей очереди
		local width = TrGCDQueueOpt[i].width*TrGCDQueueOpt[i].size
		for j=1,10 do
			TrGCDIcon[k][j].x = TrGCDIcon[i][j].x
			if (TrGCDQueueOpt[k].fade == "Left") then TrGCDIcon[k][j]:SetPoint("RIGHT", TrGCDQueueFrame[k], "RIGHT",TrGCDIcon[k][j].x,0)
			elseif (TrGCDQueueOpt[k].fade == "Right") then TrGCDIcon[k][j]:SetPoint("LEFT", TrGCDQueueFrame[k], "LEFT",-TrGCDIcon[k][j].x,0)
			elseif (TrGCDQueueOpt[k].fade == "Up") then TrGCDIcon[k][j]:SetPoint("BOTTOM", TrGCDQueueFrame[k], "BOTTOM",0,-TrGCDIcon[k][j].x)
			elseif (TrGCDQueueOpt[k].fade == "Down") then TrGCDIcon[k][j]:SetPoint("TOP", TrGCDQueueFrame[k], "TOP",0,TrGCDIcon[k][j].x) end
			TrGCDIcon[k][j].texture:SetTexture(TrGCDIcon[i][j].texture:GetTexture())
			TrGCDIcon[k][j].show = TrGCDIcon[i][j].show
			TrGCDIcon[k][j]:SetAlpha(TrGCDIcon[i][j]:GetAlpha())
			TrGCDIcon[k][j].TimeStart = TrGCDIcon[i][j].TimeStart
			if (TrGCDIcon[k][j].show) then
				TrGCDIcon[k][j]:SetAlpha((1-(abs(TrGCDIcon[k][j].x) - width)/10))  --МИГАЕТ ПРИ РАЗНОМ РАЗМЕРЕ ОЧЕРЕДИ
				TrGCDIcon[k][j]:Show()
			else TrGCDIcon[k][j]:Hide() end
			TrGCDIcon[k][j].texture2.show = TrGCDIcon[i][j].texture2.show
			if (TrGCDIcon[k][j].texture2.show) then
				TrGCDIcon[k][j].texture2:Show()
			else TrGCDIcon[k][j].texture2:Hide() end
		end
		TrGCDCastSp[k] = TrGCDCastSp[i]
		TrGCDBufferIcon[k] = TrGCDBufferIcon[i]
		TrGCDCastSpBanTime[k] = TrGCDCastSpBanTime[i]
		TrGCDi[k] = TrGCDi[i]
		TrGCDQueueFirstIndex[k] = 1
		if (TrGCDSizeQueue(i) > 0) then -- copy-paste the queue of skills to the first place
			for j=1,TrGCDSizeQueue(i) do
				TrGCDQueueFirst[k][j] = TrGCDQueueFirst[i][TrGCDQueueFirstIndex[i]+j-1]
			end
		end
	end
end

--TrGCDQueueFirst - Skill queue for a new location
function TrGCDAddSpQueue(TrGCDit, i) -- add a new spell to the skill queue at a new location
	local k = TrGCDQueueFirstIndex[i]
	while (TrGCDQueueFirst[i][k] ~= nil) do k = k + 1 end
	TrGCDQueueFirst[i][k] = TrGCDit
end

function TrGCDSizeQueue(i) -- find out the length of the skill queue for a new location
	local k = TrGCDQueueFirstIndex[i]
	while (TrGCDQueueFirst[i][k] ~= nil) do k = k + 1 end
	return (k - TrGCDQueueFirstIndex[i])
end

function TrGCDPlayerDetect(who) -- Determine the player who sent the spell
	local t = false --true - if the event was launched by someone in a party or in the arena
	local i = 0
	if (who == "player") then i = 1 t = true return i,t end
	for j=2,5 do if (who == ("party"..j-1)) then i = j t = true return i,t end end
	for j=6,10 do if (who == ("arena"..j-5)) then i = j t = true return i,t end end
	if (who == "target") then i = 11 t = true return i,t end
	if (who == "focus") then i = 12 t = true end
	return i, t
end

--48108 - Огненная глыба!
--34936 - Ответный удар
--93400 - Падающие звезды
--69369 - Стремительность хищника
--81292 - Cимвол пронзания разума
--87160 - Наступление тьмы
--114255 - Пробуждение света
--124430 - Божественная мудрость
function TrGCDEventBuffHandler(self,event, ...) -- launched by the event changing buffs / debuffs of the character
	if (TrGCDEnable) then
		local who = ... ;
		local i,t = TrGCDPlayerDetect(who)
		local tt = true
		if (t) then
			for k=1,16 do
				local k = select(11,UnitBuff(who, k))
				if (k == 48108) then TrGCDInsSp["spell"][i] = 48108 tt = false
				elseif (k == 34936) then TrGCDInsSp["spell"][i] = 34936 tt = false
				elseif (k == 93400) then TrGCDInsSp["spell"][i] = 93400 tt = false
				elseif (k == 69369) then TrGCDInsSp["spell"][i] = 69369 tt = false
				elseif (k == 81292) then TrGCDInsSp["spell"][i] = 81292 tt = false
				elseif (k == 87160) then TrGCDInsSp["spell"][i] = 87160 tt = false
				elseif (k == 114255) then TrGCDInsSp["spell"][i] = 114255 tt = false
				elseif (k == 124430) then TrGCDInsSp["spell"][i] = 124430 tt = false end
			end
			if (((GetTime()-TrGCDInsSp["time"][i]) <0.1) and (tt)) then TrGCDInsSp["spell"][i] = 0 end
		end
	end
end

local function TrGCDAddGcdSpell(texture, i, spellid) -- adding a new spell to the queue
	if (TrGCDi[i] == 10) then
		TrGCDi[i] = 1
	end

	TrGCDAddSpQueue(TrGCDi[i], i)
	TrGCDIcon[i][TrGCDi[i]].x = 0;
	TrGCDIcon[i][TrGCDi[i]].texture:SetTexture(texture)
	TrGCDIcon[i][TrGCDi[i]].show = false
	TrGCDIcon[i][TrGCDi[i]]:SetAlpha(0)
	TrGCDIcon[i][TrGCDi[i]]:Hide()
	TrGCDIcon[i][TrGCDi[i]].spellID = spellid
	TrGCDi[i] = TrGCDi[i] + 1
end

function TrGCDUnitChannelInfo(unit)
	if not isClassic then
	  return UnitChannelInfo(unit)
	elseif UnitIsUnit(unit, "player") then
	  return ChannelInfo()
	else
	  return false
	end
end

function TrGCDEventHandler(self, event, who, _, spellId)
	local spellicon = select(3, GetSpellInfo(spellId))
	local casttime = select(4, GetSpellInfo(spellId)) / 1000
	local spellname = GetSpellInfo(spellId)
	local i,t = TrGCDPlayerDetect(who) -- i - user number, t = true - if someone from the party or in the arena
	if (TrGCDEnable and t and TrGCDQueueOpt[i].enable) then
		--print(spellId .. " - " .. spellname)
		local blt = true -- for an open blacklist
		local sblt = true -- for a closed blacklist (inside by ID)
		TrGCDInsSp["time"][i] = GetTime()
		for l=1, #TrGCDBL do if ((TrGCDBL[l] == spellname) or (GetSpellInfo(TrGCDBL[l]) == spellname)) then blt = false end end -- blacklist check
		for l=1, #InnerBL do if (InnerBL[l] == spellId) then sblt = false end end -- closed blacklist check
		if ((spellicon ~= nil) and t and blt and sblt and (GetSpellLink(spellId) ~= nil)) then
			if (spellId == 42292) then spellicon = trinket end -- replacing the pvp trinket texture
			local IsChannel = TrGCDUnitChannelInfo(who) -- check for channeling spell
			if (event == "UNIT_SPELLCAST_START") then
				--print("cast " .. spellname)
				TrGCDAddGcdSpell(spellicon, i, spellId)
				TrGCDCastSp[i] = 0 -- 0 - каст идет, 1 - каст прошел и не идет
				TrGCDCastSpBanTime[i] = GetTime()

			elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
				if (TrGCDCastSp[i] == 0) then
					--print("succeeded then " .. spellname)
					if (IsChannel == nil) then TrGCDCastSp[i] = 1 end
				else
					local b = false --висит ли багнутый бафф инстант каста
					if ((TrGCDInsSp["spell"][i] == 48108) and (spellId == 11366)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 48108) and (spellId == 2120)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 34936) and (spellId == 29722)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 93400) and (spellId == 78674)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 69369) and ((spellId == 339) or (spellId == 33786) or (spellId == 5185) or (spellId == 2637) or (spellId == 20484)))then b = true
					elseif ((TrGCDInsSp["spell"][i] == 81292) and (spellId == 8092)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 87160) and (spellId == 73510)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 114255) and (spellId == 2061)) then b = true
					elseif ((TrGCDInsSp["spell"][i] == 124430) and (spellId == 8092)) then b = true end
					TrGCDCastSpBanTime[i] = GetTime()
					if (IsChannel ~= nil) then TrGCDCastSp[i] = 0 end
					if (((GetTime()-TrGCDSpStopTime[i]) < 1) and (TrGCDSpStopName[i] == spellname) and (b == false)) then
						TrGCDIcon[i][TrGCDSpStop[i]].texture2:Hide()
						TrGCDIcon[i][TrGCDSpStop[i]].texture2.show = false
					end
					if ((casttime <= 0) or b) then TrGCDAddGcdSpell(spellicon, i, spellId) end
					--print("succeeded " .. spellname .. " - " ..TrGCDCastSp[i])
				end
			elseif ((event == "UNIT_SPELLCAST_STOP") and (TrGCDCastSp[i] == 0)) then
				-- print("stop " .. spellname)
				TrGCDCastSp[i] = 1
				TrGCDIcon[i][TrGCDi[i]-1].texture2:Show()
				TrGCDIcon[i][TrGCDi[i]-1].texture2.show = true
				TrGCDSpStop[i] = TrGCDi[i]-1
				TrGCDSpStopName[i] = spellname
				TrGCDSpStopTime[i] = GetTime()
			elseif (event == "UNIT_SPELLCAST_CHANNEL_STOP") then
				TrGCDCastSp[i] = 1
				--print("channel stop " .. spellname .. " - " .. TrGCDCastSp[i])
			end
		end
	end
end

function TrGCDUpdate(self)
	if ((GetTime() - TimeReset)> TimeDelay) then
		for i=1,12 do
			if (TrGCDQueueOpt[i].enable and TrGCDIconOnEnter[i]) then
				if (TrGCDSizeQueue(i) > 0) then -- push to queue
					if ((TrGCDQueueOpt[i].size - TrGCDBufferIcon[i]) <= 0) then
						local k = TrGCDQueueFirst[i][TrGCDQueueFirstIndex[i]]
						TrGCDIcon[i][k].show = true
						TrGCDIcon[i][k]:Show()
						TrGCDIcon[i][k]:SetAlpha(1)
						TrGCDQueueFirstIndex[i] = TrGCDQueueFirstIndex[i] + 1
						TrGCDBufferIcon[i] = 0
						TrGCDIcon[i][k].TimeStart = GetTime()
					end
				end
				if ((GetTime() - TrGCDCastSpBanTime[i]) > 10) then
					TrGCDCastSp[i] = 1
				end
				local fastspeed = TrGCDQueueOpt[i].speed * SpMod * (TrGCDSizeQueue(i) + 1)
				if (TrGCDSizeQueue(i) > 0) then DurTimeImprove = (TrGCDQueueOpt[i].size - TrGCDBufferIcon[i])/fastspeed -- 计算平滑速度
				else DurTimeImprove = 0.0 end
				if (DurTimeImprove > (GetTime()-TimeReset)) then DurTimeImprove = GetTime()-TimeReset end

				for k = 1,10 do
					if (TrGCDIcon[i][k].show) then
						local width = TrGCDQueueOpt[i].width * TrGCDQueueOpt[i].size
						if (TrufiGCDChSave["ModScroll"] == false) then
							if (DurTimeImprove ~= 0) then
								TrGCDIcon[i][k].x = TrGCDIcon[i][k].x - (GetTime()-TimeReset-DurTimeImprove)*TrGCDQueueOpt[i].speed*TrGCDCastSp[i] - DurTimeImprove*fastspeed
							end
						else
							TrGCDIcon[i][k].x = TrGCDIcon[i][k].x - (GetTime()-TimeReset-DurTimeImprove)*TrGCDQueueOpt[i].speed*TrGCDCastSp[i] - DurTimeImprove*fastspeed
						end
						if (TrGCDQueueOpt[i].fade == "Left") then TrGCDIcon[i][k]:SetPoint("RIGHT", TrGCDQueueFrame[i], "RIGHT",TrGCDIcon[i][k].x,0)
						elseif (TrGCDQueueOpt[i].fade == "Right") then TrGCDIcon[i][k]:SetPoint("LEFT", TrGCDQueueFrame[i], "LEFT",-TrGCDIcon[i][k].x,0)
						elseif (TrGCDQueueOpt[i].fade == "Up") then TrGCDIcon[i][k]:SetPoint("BOTTOM", TrGCDQueueFrame[i], "BOTTOM",0,-TrGCDIcon[i][k].x)
						elseif (TrGCDQueueOpt[i].fade == "Down") then TrGCDIcon[i][k]:SetPoint("TOP", TrGCDQueueFrame[i], "TOP",0,TrGCDIcon[i][k].x) end
						if (TrufiGCDChSave["ModScroll"] == false) then
							if ((GetTime() - TrGCDIcon[i][k].TimeStart) > (ModTimeVanish + ModTimeIndent)) then
								TrGCDIcon[i][k].show = false
								TrGCDIcon[i][k]:Hide()
								TrGCDIcon[i][k]:SetAlpha(0)
								TrGCDIcon[i][k].x = 0
								TrGCDIcon[i][k].texture2:Hide()
								TrGCDIcon[i][k].texture2.show = false
							elseif ((GetTime() - TrGCDIcon[i][k].TimeStart) > ModTimeIndent) then
								TrGCDIcon[i][k]:SetAlpha((1-(GetTime() - TrGCDIcon[i][k].TimeStart - ModTimeIndent)/ModTimeVanish)) end
						end
						if (abs(TrGCDIcon[i][k].x) > width) then
							if ((1-(abs(TrGCDIcon[i][k].x) - width)/10) < 0) then
								TrGCDIcon[i][k].show = false
								TrGCDIcon[i][k]:Hide()
								TrGCDIcon[i][k]:SetAlpha(0)
								TrGCDIcon[i][k].x = 0
								TrGCDIcon[i][k].texture2:Hide()
								TrGCDIcon[i][k].texture2.show = false
							elseif (TrufiGCDChSave["ModScroll"] == true) then
								TrGCDIcon[i][k]:SetAlpha((1-(abs(TrGCDIcon[i][k].x) - width)/10))
							end
						end
					end
				end

				if (TrufiGCDChSave["ModScroll"] == false) then
					if (DurTimeImprove ~= 0) then
						TrGCDBufferIcon[i] = TrGCDBufferIcon[i] + (GetTime()-TimeReset-DurTimeImprove)*TrGCDQueueOpt[i].speed*TrGCDCastSp[i] + DurTimeImprove *fastspeed
					end
				else
					TrGCDBufferIcon[i] = TrGCDBufferIcon[i] + (GetTime()-TimeReset-DurTimeImprove)*TrGCDQueueOpt[i].speed*TrGCDCastSp[i] + DurTimeImprove *fastspeed
				end
			end
		end
		TimeReset = GetTime()
	end
end
