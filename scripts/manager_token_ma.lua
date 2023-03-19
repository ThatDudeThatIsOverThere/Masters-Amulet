-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	condcomps = {
	["Bound"] = "cond_bound",
	["Guardian"] = "cond_guardian",
	};
	
	TokenManager.addEffectConditionIcon(TokenManagerMA.condcomps);
	
end