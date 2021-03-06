if myHero.charName ~= "Ashe" then return end

keybindings = { [ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6}


local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
function SetMovement(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
		EOW:SetAttacks(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
		_G.SDK.Orbwalker:SetAttack(bool)
	else
		GOS.BlockMovement = not bool
		GOS.BlockAttack = not bool
	end
	if bool then
		castSpell.state = 0
	end
end


function CurrentModes()
	local combomodeactive, harassactive, canmove, canattack, currenttarget
	if _G.SDK then -- ic orbwalker
		combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
		harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
		canmove = _G.SDK.Orbwalker:CanMove()
		canattack = _G.SDK.Orbwalker:CanAttack()
		currenttarget = _G.SDK.Orbwalker:GetTarget()
	elseif _G.EOW then -- eternal orbwalker
		combomodeactive = _G.EOW:Mode() == 1
		harassactive = _G.EOW:Mode() == 2
		canmove = _G.EOW:CanMove() 
		canattack = _G.EOW:CanAttack()
		currenttarget = _G.EOW:GetTarget()
	else -- default orbwalker
		combomodeactive = _G.GOS:GetMode() == "Combo"
		harassactive = _G.GOS:GetMode() == "Harass"
		canmove = _G.GOS:CanMove()
		canattack = _G.GOS:CanAttack()
		currenttarget = _G.GOS:GetTarget()
	end
	return combomodeactive, harassactive, canmove, canattack, currenttarget
end

function GetInventorySlotItem(itemID)
	assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
	for _, j in pairs({ ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
		if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
	end
	return nil
end

function UseBotrk()
	local target = (_G.SDK and _G.SDK.TargetSelector:GetTarget(300, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(300,"AD"))
	if target then 
		local botrkitem = GetInventorySlotItem(3153) or GetInventorySlotItem(3144)
		if botrkitem then
			Control.CastSpell(keybindings[botrkitem],target.pos)
		end
	end
end

local Ashe = {}
Ashe.__index = Ashe
local Scriptname,Version,Author,LVersion = "TRUSt in my Ashe","v1.5","TRUS","8.1"
function Ashe:GetBuffs(unit)
	self.T = {}
	for i = 0, unit.buffCount do
		local Buff = unit:GetBuff(i)
		if Buff.count > 0 then
			table.insert(self.T, Buff)
		end
	end
	return self.T
end

function Ashe:QBuff(buffname)
	for K, Buff in pairs(self:GetBuffs(myHero)) do
		if Buff.name:lower() == "asheqcastready" then
			return true
		end
	end
	return false
end

function Ashe:__init()
	if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	
	local orbwalkername = ""
	if _G.SDK then
		orbwalkername = "IC'S orbwalker"	
		_G.SDK.Orbwalker:OnPostAttack(function() 
			local combomodeactive = (_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO])
			local currenttarget = _G.SDK.Orbwalker:GetTarget()
			if (combomodeactive) and self.Menu.UseQCombo:Value() and self:QBuff() then
				self:CastQ()
			end
		end)
	elseif _G.EOW then
		orbwalkername = "EOW"	
		_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
			local combomodeactive = _G.EOW:Mode() == 1
			local currenttarget = _G.EOW:GetTarget()
			if (combomodeactive) and self.Menu.UseQCombo:Value() and self:QBuff() then
				self:CastQ()
			end
		end)
	elseif _G.GOS then
		orbwalkername = "Noddy orbwalker"
		
		_G.GOS:OnAttackComplete(function() 
			local combomodeactive = _G.GOS:GetMode() == "Combo"
			local currenttarget = _G.GOS:GetTarget()
			if (combomodeactive) and currenttarget and self.Menu.UseQCombo:Value() and self:QBuff() and currenttarget then
				self:CastQ()
			end
		end)
		
	else
		orbwalkername = "Orbwalker not found"
		
	end
	PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
end

--[[Spells]]
function Ashe:LoadSpells()
	W = {Range = 1200, width = nil, Delay = 0.25, Radius = 30, Speed = 900}
end


function GetConeAOECastPosition(unit, delay, angle, range, speed, from)
	range = range and range - 4 or 20000
	radius = 1
	from = from and Vector(from) or Vector(myHero.pos)
	angle = angle * math.pi / 180
	
	local CastPosition = unit:GetPrediction(speed,delay)
	local points = {}
	local mainCastPosition = CastPosition
	
	table.insert(points, Vector(CastPosition) - Vector(from))
	
	local function CountVectorsBetween(V1, V2, points)
		local result = 0	
		local hitpoints = {} 
		for i, test in ipairs(points) do
			local NVector = Vector(V1):CrossP(test)
			local NVector2 = Vector(test):CrossP(V2)
			if NVector.y >= 0 and NVector2.y >= 0 then
				result = result + 1
				table.insert(hitpoints, test)
			elseif i == 1 then
				return -1 --doesnt hit the main target
			end
		end
		return result, hitpoints
	end
	
	local function CheckHit(position, angle, points)
		local direction = Vector(position):Normalized()
		local v1 = position:Rotated(0, -angle / 2, 0)
		local v2 = position:Rotated(0, angle / 2, 0)
		return CountVectorsBetween(v1, v2, points)
	end
	local enemyheroestable = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(range)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
	for i, target in ipairs(enemyheroestable) do
		if target.networkID ~= unit.networkID and myHero.pos:DistanceTo(target.pos) < range then
			CastPosition = target:GetPrediction(speed,delay)
			if from:DistanceTo(CastPosition) < range then
				table.insert(points, Vector(CastPosition) - Vector(from))
			end
		end
	end
	
	local MaxHitPos
	local MaxHit = 1
	local MaxHitPoints = {}
	
	if #points > 1 then
		
		for i, point in ipairs(points) do
			local pos1 = Vector(point):Rotated(0, angle / 2, 0)
			local pos2 = Vector(point):Rotated(0, - angle / 2, 0)
			
			local hits, points1 = CountVectorsBetween(pos1, pos2, points)
			--
			if hits >= MaxHit then
				
				MaxHitPos = C1
				MaxHit = hits
				MaxHitPoints = points1
			end
			
		end
	end
	
	if MaxHit > 1 then
		--Center the cone
		local maxangle = -1
		local p1
		local p2
		for i, hitp in ipairs(MaxHitPoints) do
			for o, hitp2 in ipairs(MaxHitPoints) do
				local cangle = Vector():AngleBetween(hitp2, hitp) 
				if cangle > maxangle then
					maxangle = cangle
					p1 = hitp
					p2 = hitp2
				end
			end
		end
		
		
		return Vector(from) + range * (((p1 + p2) / 2)):Normalized(), MaxHit
	else
		return unit.pos, 1
	end
end



function Ashe:LoadMenu()
	self.Menu = MenuElement({type = MENU, id = "TRUStinymyAshe", name = Scriptname})
	self.Menu:MenuElement({id = "UseWCombo", name = "UseW in combo", value = true})
	self.Menu:MenuElement({id = "UseQCombo", name = "UseQ in combo", value = true})
	self.Menu:MenuElement({id = "UseQAfterAA", name = "UseQ only afterattack", value = true})
	self.Menu:MenuElement({id = "UseWHarass", name = "UseW in Harass", value = true})
	self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
	self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
	self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
	
	self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
	self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
	self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
end

function Ashe:Tick()
	if myHero.dead or (not _G.SDK and not _G.GOS) then return end
	
	if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "Volley" then 
		SetMovement(true)
	end
	local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
	if combomodeactive and self.Menu.UseBOTRK:Value() then
		UseBotrk()
	end
	
	if combomodeactive and self.Menu.UseWCombo:Value() and canmove and not canattack then
		self:CastW(currenttarget)
	end
	if combomodeactive and self:QBuff() and self.Menu.UseQCombo:Value() and (not self.Menu.UseQAfterAA:Value()) and currenttarget and canmove and not canattack then
		self:CastQ()
	end
	if harassactive and self.Menu.UseWHarass:Value() and ((canmove and not canattack) or not currenttarget) then
		self:CastW(currenttarget)
	end
end

function ReturnCursor(pos)
	Control.SetCursorPos(pos)
	SetMovement(true)
end

function LeftClick(pos)
	Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
	Control.mouse_event(MOUSEEVENTF_LEFTUP)
	DelayAction(ReturnCursor,0.05,{pos})
end

function Ashe:CastSpell(spell,pos)
	local customcast = self.Menu.CustomSpellCast:Value()
	if not customcast then
		Control.CastSpell(spell, pos)
		return
	else
		local delay = self.Menu.delay:Value()
		local ticker = GetTickCount()
		if castSpell.state == 0 and ticker > castSpell.casting then
			castSpell.state = 1
			castSpell.mouse = mousePos
			castSpell.tick = ticker
			if ticker - castSpell.tick < Game.Latency() then
				--block movement
				SetMovement(false)
				Control.SetCursorPos(pos)
				Control.KeyDown(spell)
				Control.KeyUp(spell)
				DelayAction(LeftClick,delay/1000,{castSpell.mouse})
				castSpell.casting = ticker + 500
			end
		end
	end
end


function Ashe:CastQ()
	if self:CanCast(_Q) then
		Control.CastSpell(HK_Q)
	end
end


function Ashe:CastW(target)
	local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(W.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(W.Range,"AD"))
	if target and self:CanCast(_W) and target:GetCollision(W.Radius,W.Speed,W.Delay) == 0 then
		local getposition = self:GetWPos(target)
		if getposition then
			self:CastSpell(HK_W,getposition)
		end
	end
end


function Ashe:GetWPos(unit)
	if unit then
		local temppos = GetConeAOECastPosition(unit, W.Delay, 45, W.Range, W.Speed)
		if temppos then 
			local newpos = myHero.pos:Extended(temppos,math.random(100,300))
			return newpos
		end
	end
	
	return false
end

function Ashe:IsReady(spellSlot)
	return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
end

function Ashe:CheckMana(spellSlot)
	return myHero:GetSpellData(spellSlot).mana < myHero.mana
end

function Ashe:CanCast(spellSlot)
	return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
end

function OnLoad()
	Ashe:__init()
end