--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

local applyDamageOriginal;
local messageDamageOriginal;

function onInit()
	table.insert(DataCommon.conditions, "bound");
	table.insert(DataCommon.conditions, "Guardian");

	applyDamageOriginal = ActionDamage.applyDamage;
	ActionDamage.applyDamage = applyDamage;
	
	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
end

function applyDamage(rSource, rTarget, rRoll)
	local nAmuletOddCheck = 0; --To apply +1 damage to a Shield Guardian if the damage to their Bound PC is odd.
	local bGuardianCheck = false; --To check if damage is being split.
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	local nAdjustedDamage = 0;
	if not nodeTarget then
		return;
	end
	
	local rDamageOutput = ActionDamage.decodeDamageText(rRoll.nTotal, rRoll.sDesc);
	if rRoll then
		rRoll.aDamageTypes = rDamageOutput.aDamageTypes;
	end
	--make tNotifications into a table
	if not rDamageOutput.tNotifications then
		rDamageOutput.tNotifications = {};
	end
	if (rRoll.sType == "damage") then
		local nDamageAdjust, bVulnerable, bResist = ActionDamage.getDamageAdjust(rSource, rTarget, rDamageOutput.nVal, rDamageOutput);
		nAdjustedDamage = rDamageOutput.nVal + nDamageAdjust;
		
		if nAdjustedDamage < 0 then
			nAdjustedDamage = 0;
		end
		
		if (EffectManager5E.hasEffectCondition(rTarget, "Bound") and (rDamageOutput.sType == "damage")) then
			for _,v in ipairs(DB.getChildList(ActorManager.getCTNode(rTarget), "effects")) do
				local sLabel = DB.getValue(v, "label", "");
				-- Get the source of the effect
				local sSource = DB.getValue(v, "source_name", "");
				local rEffectSource = ActorManager.resolveActor(sSource);
				if rEffectSource then 
					if (EffectManager5E.hasEffectCondition(rEffectSource, "Guardian")) then
						bGuardianCheck = true;
					end
				end
			end
		end
		
		if (bGuardianCheck) then	
			nAmuletOddCheck = (nAdjustedDamage % 2);
			nAdjustedDamage = math.floor(nAdjustedDamage / 2);

			--Making the math actually apply to the damage total.
			rRoll.nTotal = nAdjustedDamage;
			-- Also update the sDesc to get rid of the damage type warning.
			local sNewDesc = "";
			
			-- finding the start of the sections to be added to sNewDesc and adding everything before that to the base variable.
			local sDescIndex = (tonumber((string.find(rRoll.sDesc, "TYPE")) - 3))
			sNewDesc = (string.sub(rRoll.sDesc, 1, sDescIndex));
			
			-- adding a counter to swap between floor and ceil
			local countOddDamageValues = 1;
			
			local sNewDamageSubTotal = ""; -- Have to declare this up here to fix the nil problem
			
			for sDamageType, sDamageDice, sDamageSubTotal in string.gmatch(rRoll.sDesc, "%[TYPE: ([^(]*) %(([%d%+%-dD]+)%=(%d+)%)%]") do
				if(((countOddDamageValues % 2) == 1) and ((tonumber(sDamageSubTotal) % 2) == 1)) then
					sNewDamageSubTotal = tostring(math.floor(tonumber(sDamageSubTotal) / 2));
					countOddDamageValues = countOddDamageValues + 1;
				elseif(((countOddDamageValues % 2) == 0) and ((tonumber(sDamageSubTotal) % 2) == 1)) then
					sNewDamageSubTotal = tostring(math.ceil(tonumber(sDamageSubTotal) / 2));
					countOddDamageValues = countOddDamageValues + 1;
				else
					sNewDamageSubTotal = tostring(math.floor(tonumber(sDamageSubTotal) / 2));
				end
				
				sNewDesc = sNewDesc .. " " .. "[TYPE: " .. sDamageType .. "(" .. sDamageDice .. " Split With Guardian =" .. tostring(sNewDamageSubTotal) .. ")]";  -- not sure if this tostring should stay. Currently nothing bad happens if nil, was breaking for me without it when nil even though it exists on 98 and 100
			end
			
			rRoll.sDesc = sNewDesc;
			rRoll.sDesc = rRoll.sDesc .. " [AMULET]";	
		end
	end
		
	EffectManager.startDelayedUpdates();
	applyDamageOriginal(rSource, rTarget, rRoll);
		--apply damage to Shield Guardian *after* original damage is done.
		if ((bGuardianCheck) and (rRoll.sType == "damage")) then
			local rGuardianRoll = {};
			for key, value in pairs(rRoll) do
				rGuardianRoll[key] = value;
			end
			rGuardianRoll.nTotal =  nAdjustedDamage + nAmuletOddCheck;
			rGuardianRoll.sDesc = "[TYPE: amulet=" .. rGuardianRoll.nTotal .. "]";
			-- Loop through the effects, looking for the bound effect being applied by a shield guardian
			for _,v in ipairs(DB.getChildList(ActorManager.getCTNode(rTarget), "effects")) do
				local sLabel = DB.getValue(v, "label", "");
				if (sLabel == "Bound") then
					-- Get the name of the source of the effect
					local sSource = DB.getValue(v, "source_name", "");
					local rEffectSource = ActorManager.resolveActor(sSource);
					if rEffectSource then 
						--Make sure the source of the effect is actually a Shield Guardian
						if (EffectManager5E.hasEffectCondition(rEffectSource, "Guardian")) then
							-- Apply damage to the Guardian
							rGuardianRoll.sDesc = rGuardianRoll.sDesc .. " [GUARDIAN]";
							applyDamageOriginal(rSource, rEffectSource, rGuardianRoll);
						end
					end
				end
			end
		end
	bGuardianCheck = false;
	EffectManager.endDelayedUpdates();
end

function messageDamage(rSource, rTarget, rRoll)
	if rRoll.sType == "damage" then
		if ((string.match(rRoll.sDesc, "%[AMULET%]")) and not (string.match(rRoll.sDesc, "%[GUARDIAN%]"))) then
			rRoll.sResults = rRoll.sResults .. "[AMULET]";
		elseif string.match(rRoll.sDesc, "%[GUARDIAN%]") then
			rRoll.sResults = rRoll.sResults .. "[GUARDIAN]";
		end
	end
	messageDamageOriginal(rSource, rTarget, rRoll);
end