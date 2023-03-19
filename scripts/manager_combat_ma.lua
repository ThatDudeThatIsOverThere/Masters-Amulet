-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local parseNPCPowerOriginal;

function onInit()
	parseNPCPowerOriginal = CombatManager2.parseNPCPower;
	CombatManager2.parseNPCPower = parseNPCPower;
end

function parseNPCPower(rActor, nodePower, aEffects, bAllowSpellDataOverride)
	local sDisplay = DB.getValue(nodePower, "name", "");
	local aDisplayOptions = {};
	
	local sName = StringManager.trim(sDisplay:lower());
	if sName == "bound" then
		table.insert(aEffects, "Guardian");
	end
	parseNPCPowerOriginal(rActor, nodePower, aEffects, bAllowSpellDataOverride);
end