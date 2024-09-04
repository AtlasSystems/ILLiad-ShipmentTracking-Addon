-- About TrackShipping.lua
-- Author: Atlas Systems, Inc.
--
-- TrackShipping.lua checks the value of the transaction field specified by the ConstIlliadField variable. If it contains a 
-- value, it then does a very basic comparison to determine if it is a UPS or Fedex tracking number and searchings the tracking number
-- on the appropriate tracking form.

local settings = {};
settings.AutoSearch = GetSetting("AutoSearch");
settings.ShippingOptions_USPS = GetSetting("ShippingOptions_USPS");
settings.ShippingOptions_Fedex = GetSetting("ShippingOptions_Fedex");
settings.ShippingOptions_UPS = GetSetting("ShippingOptions_UPS");

local interfaceMngr = nil;
local trackingForm = {};
trackingForm.Form = nil;
trackingForm.Browser = nil;
trackingForm.RibbonPage = nil;

-- Constants
local ConstTypeFedex = "Fedex";
local ConstTypeUps = "UPS";
local ConstTypeUsps = "USPS";

local ConstFedexAddress = "http://www.fedex.com/Tracking?cntry_code=us&tracknumbers=";
local ConstUpsAddress = "http://wwwapps.ups.com/WebTracking/track?loc=en_US&track.x=Track&trackNums=";
local ConstUspsAddress = "http://trkcnfrm1.smi.usps.com/PTSInternetWeb/InterLabelInquiry.do?trackGo.x=10&trackGo.y=7&strOrigTrackNum=";

local ConstIlliadField = GetSetting("ILLiadField");
local debugEnabled = false;

require "Atlas.AtlasHelpers";

function Init()
	if IsValidTransaction() then
		Log("TrackShipping Init");
		
		interfaceMngr = GetInterfaceManager();
		
		-- Create a form
		trackingForm.Form = interfaceMngr:CreateForm("Shipments", "Script");

		-- Add a browser
		trackingForm.Browser = trackingForm.Form:CreateBrowser("Shipments", "Shipments Browser", "Shipments");

		-- Hide the text label
		trackingForm.Browser.TextVisible = false;

		-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  We can retrieve that one and add our buttons to it.
		trackingForm.RibbonPage = trackingForm.Form:GetRibbonPage("Shipments");

		-- Create the search button
		trackingForm.RibbonPage:CreateButton("Smart Search", GetClientImage("Search32"), "Search", "Tracking Number");
		trackingForm.RibbonPage:CreateButton("Search Fedex", GetClientImage("Search32"), "SearchFedex", "Tracking Number");
		trackingForm.RibbonPage:CreateButton("Search USPS", GetClientImage("Search32"), "SearchUSPS", "Tracking Number");
		trackingForm.RibbonPage:CreateButton("Search UPS", GetClientImage("Search32"), "SearchUPS", "Tracking Number");

		-- After we add all of our buttons and form elements, we can show the form.
		trackingForm.Form:Show();
        
		-- Search when opened if autoSearch is true
		if settings.AutoSearch  then
			Search();
		end
	end
end

function Search()
	Log("Search");
	local trackingType = GetTrackingNumberType(GetFieldValue("Transaction", ConstIlliadField));
	
	Log("Tracking Type = " .. trackingType);
	if trackingType == ConstTypeUps then
		SearchUPS();
	elseif trackingType == ConstTypeFedex then
		SearchFedex();
	elseif trackingType == ConstTypeUsps then
		SearchUSPS();
	end;
end

function SearchFedex()
	trackingForm.Browser:Navigate(ConstFedexAddress .. GetSearchableTrackingNumber());	
end

function SearchUSPS()
	trackingForm.Browser:Navigate(ConstUspsAddress .. GetSearchableTrackingNumber());
end

function SearchUPS()
	trackingForm.Browser:Navigate(ConstUpsAddress .. GetSearchableTrackingNumber());	
end

function GetSearchableTrackingNumber()
	local trackingNumber = GetFieldValue("Transaction", ConstIlliadField);
	
	local separatorIndex = string.find(trackingNumber, ":", 1, true);	
	
	if (separatorIndex ~= nil) then
		trackingNumber = string.sub(trackingNumber, separatorIndex + 1);
	end
	
	return AtlasHelpers.UrlEncode(trackingNumber);
end

function IsValidTransaction()
	Log("IsValidTransaction()");
	
	return (GetFieldValue("Transaction", "ProcessType") == "Lending" 
					  and GetFieldValue("Transaction", "TransactionStatus") == "Item Shipped");
end

function GetTrackingNumberType(trackingNumString)
	Log("Getting Tracking Number Type");
		
	trackingNumString = trackingNumString:gsub(" ", "");
	
	local trackingType = GetServiceFromNumberPrefix(trackingNumString);
	
	if (trackingType ~= nil) then
		return trackingType;
	else	
		trackingType = GetServiceFromShippingMethod();
		
		if (trackingType ~= nil) then
			return trackingType;
		else
			trackingType = GetServiceFromNumber(trackingNumString);
			return trackingType;
		end
	end
end

function GetServiceFromShippingMethod()
	local shippingOptions = GetFieldValue("Transaction", "ShippingOptions");
	
	if (shippingOptions == nil) then
		return nil;
	end
	
	shippingOptions = string.lower(shippingOptions);
	
	if(ShippingOptionMatches(shippingOptions, settings.ShippingOptions_UPS, ConstTypeUps)) then
		return ConstTypeUps;
	elseif(ShippingOptionMatches(shippingOptions, settings.ShippingOptions_Fedex, ConstTypeFedex)) then
		return ConstTypeFedex;
	elseif(ShippingOptionMatches(shippingOptions, settings.ShippingOptions_USPS, ConstTypeUsps)) then
		return ConstTypeUsps;
	end
end

function ShippingOptionMatches(optionString, keywordString, shippingType)
	if (shippingType == ConstTypeUsps and string.find(optionString, "usps") ~= nil) then
		return true;
	elseif (shippingType == ConstTypeFedex and string.find(optionString, "fedex") ~= nil) then
		return true;
	elseif (shippingType == ConstTypeUps and string.find(optionString, "ups") ~= nil) then
		return true;
	else
		local keywords = AtlasHelpers.StringSplit(',', keywordString);
		
		for i = 1, table.getn(keywords) do
			if (string.lower(keywords[i]) == optionString) then
				return true;
			end
		end
		
		return false;
	end	
end

function GetServiceFromNumberPrefix(trackingNumString)
	local seperatorIndex = string.find(trackingNumString, ":", 1, true);
	
	if (seperatorIndex == nil) then
		return nil;
	end;

	local prefix = string.lower(string.sub(trackingNumString, 1, seperatorIndex  - 1));
	
	if (string.find(prefix, "usps") ~= nil) then
		return ConstTypeUsps;
	elseif (string.find(prefix, "fedex") ~= nil) then
		return ConstTypeFedex;
	elseif (string.find(prefix, "ups") ~= nil) then
		return ConstTypeUps;
	else
		return nil;
	end
end

function GetServiceFromNumber(trackingNumString)
	if debugEnabled then
		Log("Tracking Number Length = " .. string.len(trackingNumString));
	end
	local trackingType = nil;
	
	if string.len(trackingNumString) == 0 then
		trackingType = "UNKNOWN";
	elseif string.len(trackingNumString) < 18 then	
		trackingType = ConstTypeFedex;
	elseif string.len(trackingNumString) < 20 then
		trackingType = ConstTypeUps;
	else
		trackingType = ConstTypeUsps;
	end
	
	Log("Returning " .. trackingType .. " from GetTrackingNumberType");
	
	return trackingType;
end

function Log(entry)
	if debugEnabled then
		LogDebug("----- " .. entry .. " -----");
	end
end