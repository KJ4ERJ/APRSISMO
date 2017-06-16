local symbols = { version = 0.1 }

function symbols:IsValidOverlay(c)
	if type(c) ~= 'string' or #c ~= 1 then return false end
	if c == '/' then return true end
	if c == '\\' then return true end
	if c >= '0' and c <= '9' then return true end
	if c >= 'A' and c <= 'Z' then return true end
	if c >= 'a' and c <= 'j' then return true end	-- Compressed only!
	return false
end

--[[
typedef struct OVERLAY_DEFINITION_S
{	char overlay;		-- 0 for end of list */
	char *Description;	-- NULL for end of list */
} OVERLAY_DEFINITION_S;
]]

--	From: http://www.aprs.org/symbols/symbols-new.txt Dated: 04 Jan 2010

-- ATM Machine or CURRENCY:  #$ 
-- /$ = original primary Phone
-- \$ = Bank or ATM (generic)
local OverATM = { { 'U', "US Dollars" },
												{ 'L', "Brittish Pound" },
												{ 'Y', "Japanese Yen" },
												};

-- POWER PLANT: #%
local OverPowerPlant = { { 'C', "Coal Power" }, { 'G', "Geothermal Plant" }, 
												{ 'H', "Hydroelectric" }, { 'N', "Nuclear Power" }, 
												{ 'S', "Solar Power" }, { 'T', "Turbine Power" },
												{ 'W', "Wind Power" },
												};

-- GATEWAYS: #&
local OverGateway = { { 'I', "IGate (deprec)" }, { 'R', "RO IGate" }, 
												{ 'T', "1 Hop TX Gate" }, { '2', "2 Hop TX Gate" } };

-- INCIDENT SITES: #' 
local OverIncidentSites = { { 'A', "Car Crash" }, { 'H', "Haz Incident" },
												{ 'M', "Multi-Vehicle" }, { 'P', "Pileup" },
												{ 'T', "Truck Wreck" },
												};

--local OverFirenet = {0};

local OverPortable = { { 'F', "Field Day" }, { 'I', "IOTA" },
											{ 'S', "SOTA" }, { 'W', "WOTA" } };

--local OverAdvisory = {0};

-- APRStt or DTMF or RFID gated users: #= (was BOX symbol) 
local OverDTMF = { { 'M', "Mobile DTMF" }, { 'H', "HT DTMF" },
											{ 'Q', "QTH DTMF" }, { 'E', "EchoLink DTMF" },
											{ 'I', "IRLP DTMF" }, { 'R', "RFID Report" },
											{ 'E', "Event DTMF" },
											};

-- HAZARDS: #H
-- /H = hotel
-- \H = Haze 
local OverHazards = { { 'R', "Radiation Detector" },
											{ 'W', "Hazardous Waste" },
											{ 'X', "Skull&Crossbones" },
											};

--local OverMARS = {0};

-- HUMAN SYMBOL: #[
-- /[ = Human
-- \[ = Wall Cloud (the original definition)
local OverHuman = { { 'B', "Baby on Board" },	-- stroller, pram, etc */
											{ 'S', "Skier" }, { 'R', "Runner" },
											{ 'H', "Hiker" },
											};

-- HOUSE: #-
-- /- = House
-- \- = (was HF) 
local OverHome = { { '5', "50hz Power" }, { '6', "60hz Power" },
									{ 'B', "Backup Power" }, { 'E', "Emergency Power" },
									{ 'G', "Geothermal House" }, { 'H', "HF" },
									{ 'O', "Operator Present" }, { 'S', "Solar Powered" },
									{ 'W', "Wind Powered" },
									};
-- CARS: #>
-- /> = normal car (side view)
-- \> = Top view and symbol POINTS in direction of travel
local OverCar = { { 'E', "Electric" }, { 'H', "Hybrid" },
											{ 'S', "Solar" }, { 'V', "GM Volt" },
											};

-- NUMBERED CIRCLES: #0
local OverNodes = { { 'E', "Echolink Node" },
									{ 'I', "IRLP Repeater" },
									{ 'S', "Staging Area" }, { 'W', "WIRES (Yaesu VOIP)" },
									};

-- NETWORK NODES: #8
local OverNetwork = { { '8', "802.11 Node" }, { 'G', "802.11G" },
												};


-- BOX SYMBOL: #A
-- /A = Aid station
-- \A = numbered box
-- #A = all others for DTMF or RFID
local OverBox = { { 'X', "OLPC laptop XO" },
									{ 'H', "RFID HotSpot" },
									{ 'R', "RFID Beacon" },
									};

-- RESTAURANTS: #R 
-- \R = Restaurant (generic)
local OverRestaurant = { { '7', "7/11" }, { 'K', "KFC" },
											{ 'M', "McDonalds" }, { 'T', "Taco Bell" },
											};

--RADIOS and APRS DEVICES: #Y
-- /Y = Yacht  <= the original primary symbol
-- \Y =        <= the original alternate was undefined
local OverRadios = { { 'A', "Alinco" },
											{ 'B', "Byonics" }, 
											{ 'I', "Icom" },
											{ 'K', "Kenwood Radio" },
											{ 'Y', "Yaesu/Standard" },
											};

-- GPS devices: #\
-- /\ = Triangle DF primary symbol
-- \\ = was undefined alternate symbol
local OverGPS = { { 'A', "Avmap G5" },
											};

-- ARRL or DIAMOND: #a
-- /a = Ambulance
local OverARRL = { { 'A', "ARES" }, { 'D', "DARES" },
											{ 'G', "RSGB" }, { 'R', "RACES a" },
											{ 'S', "SATERN a" }, { 'W', "WinLink" },
											};

-- CIVIL DEFENSE or TRIANGLE: #c
-- /c = Incident Command Post
-- \c = Civil Defense
local OverCivil = { { 'R', "RACES c" }, { 'S', "SATERN c" },
											};

-- BUILDINGS: #h
-- /h = Hospital
-- \h = Ham Store       ** <= now used for HAMFESTS
local OverStore = { { 'H', "Home Depot" },
											};

-- SPECIAL VEHICLES: #k
-- /k = truck
-- \k = SUV
local OverVehicle = { { '4', "4x4" }, {'A', "ATV k" },
											};

-- TRUCKS: #u
-- /u = Truck (18 wheeler)
-- \u = truck with overlay
local OverTruck = { { 'G', "Gas" }, { 'T', "Tanker" },
										{ 'C', "Chlorine Tanker" }, { 'H', "Hazardous" },
										};

local SSIDSymbols = "aUfbYX\'s><OjRkv";
--[[
{ "-15", 'v' },	-- Van */
{ "-14", 'k' },	-- Truck */
{ "-13", 'R' },	-- Recreational Vehicle */
{ "-12", 'j' },	-- Jeep */
{ "-11", 'O' },	-- Balloon */
{ "-10", '<' },	-- Motorcycle */
{ "-9", '>' },	-- Car */
{ "-8", 's' },	-- Ship (power boat) */
{ "-7", '\'' },	-- Small Aircraft */
{ "-6", 'X' },	-- Helicopter */
{ "-5", 'Y' },	-- Yacht */
{ "-4", 'b' },	-- Bicycle */
{ "-3", 'f' },	-- Fire Truck */
{ "-2", 'U' },	-- Bus */
{ "-1", 'a' },	-- Ambulance */
]]

--[[
static struct
{	char symbol;
	char pxy[2];
	char axy[2];
	char *Primary;
	char *Alternate;
	OVERLAY_DEFINITION_S *Overlays;
}]]

local tMarker = "Marker"
local tHuman = "Human"
local tFlying = "Flying"
local tFloat = "Floating"
local tMobile = "Mobile"
local tFixed = "Fixed"
local tAmenity = "Amenity"
local tInfra = "Infrastructure"
local tUndefined = "Undefined"
local tSpecial = "Special"
local tWeather = "Weather"
local tBrand = "Branded"

local SymbolNames = {
{ '!', "BB", "OB", tAmenity, "Police Stn", tSpecial, "Emergency"},
{ '"', "BC", "OC", tUndefined, "No Symbol p", tUndefined, "No Symbol a"},
{ '#', "BD", "OD", tInfra, "Digi", tInfra, "No. Digi" },
{ '$', "BE", "OE", tMobile, "Phone", tAmenity, "Bank", OverATM },
{ '%', "BF", "OF", tInfra, "DX Cluster", tAmenity, "Power Plant", OverPowerPlant },
{ '&', "BG", "OG", tInfra, "HF Gateway", tInfra, "No. Gateway", OverGateway },
{ '\'',"BH", "OH", tFlying, "Plane Sm", tSpecial, "Crash site", OverIncidentSites },
{ '(', "BI", "OI", tMobile, "Mob Sat Stn", tWeather, "Cloudy"},
{ ')', "BJ", "OJ", tHuman, "WheelChair", tInfra, "Firenet MEO" },	-- , &OverFirenet
{ '*', "BK", "OK", tMobile, "Snowmobile", tWeather, "Snow"},
{ '+', "BL", "OL", tMarker, "Red Cross", tAmenity, "Church"},
{ ',', "BM", "OM", tHuman, "Boy Scout", tHuman, "Girl Scout"},
{ '-', "BN", "ON", tFixed, "Home", tFixed, "Home (HF)", OverHome },
{ '.', "BO", "OO", tMarker, "X", tSpecial, "UnknownPos"},
{ '/', "BP", "OP", tMarker, "Red Dot", tSpecial, "Destination"},

{ '0', "P0", "A0", tMarker, "Circle (0)", tMarker, "No. Circle", OverNodes, tInfra },
{ '1', "P1", "A1", tMarker, "Circle (1)", tUndefined, "No Symbol 1"},
{ '2', "P2", "A2", tMarker, "Circle (2)", tUndefined, "No Symbol 2"},
{ '3', "P3", "A3", tMarker, "Circle (3)", tUndefined, "No Symbol 3"},
{ '4', "P4", "A4", tMarker, "Circle (4)", tUndefined, "No Symbol 4"},
{ '5', "P5", "A5", tMarker, "Circle (5)", tUndefined, "No Symbol 5"},
{ '6', "P6", "A6", tMarker, "Circle (6)", tUndefined, "No Symbol 6"},
{ '7', "P7", "A7", tMarker, "Circle (7)", tUndefined, "No Symbol 7"},
{ '8', "P8", "A8", tMarker, "Circle (8)", tUndefined, "No Symbol 8", OverNetwork, tInfra },
{ '9', "P9", "A9", tMarker, "Circle (9)", tAmenity, "Petrol Stn"},

{ ':', "MR", "NR", tSpecial, "Fire", tWeather, "Hail"},
{ ';', "MS", "NS", tAmenity, "Campground", tAmenity, "Park", OverPortable },
{ '<', "MT", "NT", tMobile, "Motorcycle", tWeather, "Advisory" },	-- , &OverAdvisory
{ '=', "MU", "NU", tMobile, "Rail Eng.", tSpecial, "APRStt (DTMF)", OverDTMF },
{ '>', "MV", "NV", tMobile, "Car", tMobile, "No. Car", OverCar },
{ '?', "MW", "NW", tFixed, "File svr", tSpecial, "Info Kiosk"},
{ '@', "MX", "NX", tWeather, "HC Future", tWeather, "Hurricane"},

{ 'A', "PA", "AA", tFixed, "Aid Stn", tMarker, "No. Box", OverBox },
{ 'B', "PB", "AB", tInfra, "BBS", tWeather, "Snow blwng"},
{ 'C', "PC", "AC", tFloat, "Canoe", tFixed, "Coast G'rd"},
{ 'D', "PD", "AD", tUndefined, "No Symbol D", tWeather, "Drizzle"},
{ 'E', "PE", "AE", tMarker, "Eyeball", tWeather, "Smoke"},
{ 'F', "PF", "AF", tMobile, "Tractor", tWeather, "Fr'ze Rain"},
{ 'G', "PG", "AG", tSpecial, "Grid Squ.", tWeather, "Snow Shwr"},
{ 'H', "PH", "AH", tAmenity, "Hotel", tWeather, "Haze/Hazard", OverHazards },
{ 'I', "PI", "AI", tInfra, "Tcp/ip", tWeather, "Rain Shwr"},
{ 'J', "PJ", "AJ", tUndefined, "No Symbol J", tWeather, "Lightning"},
{ 'K', "PK", "AK", tAmenity, "School", tBrand, "Kenwood"},
{ 'L', "PL", "AL", tInfra, "Usr Log-ON", tFixed, "Lighthouse"},
{ 'M', "PM", "AM", tBrand, "MacAPRS", tFixed, "MARS" },	-- , &OverMARS
{ 'N', "PN", "AN", tInfra, "NTS Stn", tInfra, "Nav Buoy"},
{ 'O', "PO", "AO", tFlying, "Balloon", tFlying, "Rocket"},
{ 'P', "PP", "AP", tMobile, "Police", tMarker, "Parking  "},
{ 'Q', "PQ", "AQ", tMarker, "TBD/Bullseye", tWeather, "Quake"},
{ 'R', "PR", "AR", tMobile, "Rec Veh'le", tAmenity, "Restaurant", OverRestaurant, tBrand },
{ 'S', "PS", "AS", tFlying, "Shuttle", tInfra, "Sat/Pacsat"},
{ 'T', "PT", "AT", tInfra, "SSTV", tWeather, "T'storm"},
{ 'U', "PU", "AU", tMobile, "Bus", tWeather, "Sunny"},
{ 'V', "PV", "AV", tMobile, "ATV", tInfra, "VORTAC"},
{ 'W', "PW", "AW", tWeather, "WX Station", tWeather, "No. WXS" },
{ 'X', "PX", "AX", tFlying, "Helo", tAmenity, "Pharmacy"},
{ 'Y', "PY", "AY", tFloat, "Yacht", tBrand, "Radio or GPS", OverRadios },
{ 'Z', "PZ", "AZ", tBrand, "WinAPRS", tUndefined, "No Symbol Z"},

{ '[', "HS", "DS", tHuman, "Jogger", tWeather, "Wall Cloud", OverHuman, tHuman },
{ '\\',"HT", "DT", tSpecial, "DF Triangle", tBrand, "GPS Symbol", OverGPS },
{ ']', "HU", "DU", tInfra, "PBBS", tUndefined, "No Symbol ]"},
{ '^', "HV", "DV", tFlying, "Plane Lrge", tFlying, "No. Plane"},
{ '_', "HW", "DW", tWeather, "WX Service", tWeather, "No. WX Site" },
{ '`', "HX", "DX", tFixed, "Dish Ant.", tWeather, "Rain"},

{ 'a', "LA", "SA", tMobile, "Ambulance", tMarker, "No. Diamond", OverARRL, tFixed },
{ 'b', "LB", "SB", tHuman, "Bike", tWeather, "Dust blwng"},
{ 'c', "LC", "SC", tMarker, "ICP", tFixed, "No CivDef", OverCivil },
{ 'd', "LD", "SD", tFixed, "Fire Station", tInfra, "DX Spot"},
{ 'e', "LE", "SE", tHuman, "Horse", tWeather, "Sleet"},
{ 'f', "LF", "SF", tMobile, "Fire Truck", tWeather, "Funnel Cld"},
{ 'g', "LG", "SG", tFlying, "Glider", tWeather, "Gale"},
{ 'h', "LH", "SH", tFixed, "Hospital", tFixed, "(HAM) Store", OverStore, tBrand },
{ 'i', "LI", "SI", tFixed, "Island", tMarker, "No. Blk Box"},
{ 'j', "LJ", "SJ", tMobile, "Jeep", tSpecial, "WorkZone"},
{ 'k', "LK", "SK", tMobile, "Truck", tMobile, "Vehicle (SUV)", OverVehicle},
{ 'l', "LL", "SL", tMobile, "Laptop", tSpecial, "Area Objs"},
{ 'm', "LM", "SM", tInfra, "Mic-E Rptr", tSpecial, "Milepost"},
{ 'n', "LN", "SN", tInfra, "Node", tMarker, "No. Triang"},
{ 'o', "LO", "SO", tFixed, "EOC", tMarker, "Circle sm"},
{ 'p', "LP", "SP", tHuman, "Rover", tWeather, "Part Cloud"},
{ 'q', "LQ", "SQ", tSpecial, "Grid squ.", tUndefined, "No Symbol q"},
{ 'r', "LR", "SR", tInfra, "Antenna", tAmenity, "Restrooms"},
{ 's', "LS", "SS", tFloat, "Power Boat", tFloat, "No. Boat" },
{ 't', "LT", "ST", tFixed, "Truck Stop", tWeather, "Tornado"},
{ 'u', "LU", "SU", tMobile, "Truck 18wh", tMobile, "No. Truck", OverTruck },
{ 'v', "LV", "SV", tMobile, "Van", tMobile, "No. Van"},
{ 'w', "LW", "SW", tWeather, "Water Stn", tWeather, "Flooding"},
{ 'x', "LX", "SX", tBrand, "XAPRS", tUndefined, "No Symbol x"},
{ 'y', "LY", "SY", tInfra, "Yagi", tWeather, "Sky Warn"},
{ 'z', "LZ", "SZ", tFixed, "Shelter", tFixed, "No Shelter"},

{ '{', "J1", "Q1", tUndefined, "No Symbol {", tWeather, "Fog"},
{ '|', "J2", "Q2", tSpecial, "TNC Stream Sw p", tSpecial, "TNC Stream SW a"},
{ '}', "J3", "Q3", tUndefined, "No Symbol p}", tUndefined, "No Symbol a}"},
{ '~', "J4", "Q4", tSpecial, "Telemetry", tSpecial, "TNC Stream SW"} };

local SymbolGroups = {}
local SymbolsByName = {}

function symbols:getSymbolGroups()
	return SymbolGroups
end

local function addSymbolToGroup(g, s, d)	-- Group, Table/Symbol, Description
	if not SymbolGroups[g] then
		SymbolGroups[g] = {}
	end
	local group = SymbolGroups[g]
	group[s] = d
	if SymbolsByName[d] then
		print("Duplicate "..tostring(d).." is "..tostring(s).." vs "..tostring(SymbolsByName[d]))
	else SymbolsByName[d] = s
	end
end

for i, t in ipairs(SymbolNames) do
	if type(t) ~= "table" then
		print("Invalid Symbol["..i.."] type:"..type(t))
	elseif #t ~= 7 and #t ~= 8 and #t ~= 9 then
		print("Invalid Symbol["..i.."]("..tostring(t[1]).." Definition("..#t..") Needs 7, 8, or 9 elements")
	elseif t[4] == nil or t[6] == nil then
		print("Invalid Symbol["..i.."]("..tostring(t[1])..") Missing Group Name(s)")
	else
		addSymbolToGroup(t[4], "/"..t[1], t[5])
		addSymbolToGroup(t[6], "\\"..t[1], t[7])
		if type(t[8]) == 'table' then
			for i,e in ipairs(t[8]) do
				addSymbolToGroup(t[9] or t[6], e[1]..t[1], e[2])
			end
		end
		SymbolNames[t[1]] = t	-- Index by symbol for hashed access
	end
end

do
local total = 0
for g, t in pairs(SymbolGroups) do
	local c = 0
	for s,d in pairs(t) do
		c = c + 1
	end
	print("Group["..g.."] has "..c.." symbols")
	total = total + c
end
print("Total grouped symbols:"..total.." defined:"..#SymbolNames)
end

--[[
struct
{	int	Table;
	char Symbol;
	char *Desc;
}]]
local GPXSymbols = {
{ 2, '!', "Airport" },
{ 2, '"', "Amusement Park" },
{ 2, '#', "Ball Park" },
{ 2, '$', "Bank" },
{ 2, '%', "Bar" },
{ 2, '&', "Beach" },
{ 2, '\'', "Bell" },
{ 2, '(', "Boat Ramp" },
{ 2, ')', "Bowling" },
{ 2, '*', "Bridge" },
{ 2, '+', "Building" },
{ 2, ',', "Campground" },
{ 2, '-', "Car" },
{ 2, '.', "Car Rental" },
{ 2, '/', "Car Repair" },
{ 2, '0', "Cemetery" },
{ 2, '1', "Church" },
{ 2, '2', "Circle with X" },
{ 2, '3', "City (Capitol)" },
{ 2, '4', "City (Large)" },
{ 2, '5', "City (Medium)" },
{ 2, '6', "City (Small)" },
{ 2, '7', "Civil" },
{ 2, '8', "Contact, Afro" },
{ 2, '9', "Contact, Alien" },
{ 2, ':', "Contact, Ball Cap" },
{ 2, ';', "Contact, Big Ears" },
{ 2, '<', "Contact, Biker" },
{ 2, '=', "Contact, Bug" },
{ 2, '>', "Contact, Cat" },
{ 2, '?', "Contact, Dog" },
{ 2, '@', "Contact, Dreadlocks" },
{ 2, 'A', "Contact, Female1" },
{ 2, 'B', "Contact, Female2" },
{ 2, 'C', "Contact, Female3" },
{ 3, '!', "Contact, Goatee" },
{ 3, '"', "Contact, Kung-Fu" },
{ 3, '#', "Contact, Pig" },
{ 3, '$', "Contact, Pirate" },
{ 3, '%', "Contact, Ranger" },
{ 3, '&', "Contact, Smiley" },
{ 3, '\'', "Contact, Spike" },
{ 3, '(', "Contact, Sumo" },
{ 3, ')', "Controlled Area" },
{ 3, '*', "Convenience Store" },
{ 3, '+', "Crossing" },
{ 3, ',', "Dam" },
{ 3, '-', "Danger Area" },
{ 3, '.', "Department Store" },
{ 3, '/', "Diver Down Flag 1" },
{ 3, '0', "Diver Down Flag 2" },
{ 3, '1', "Drinking Water" },
{ 3, '2', "Exit" },
{ 3, '3', "Fast Food" },
{ 3, '4', "Fishing Area" },
{ 3, '5', "Fitness Center" },
{ 3, '6', "Flag" },
{ 3, '7', "Forest" },
{ 3, '8', "Gas Station" },
{ 3, '9', "Geocache" },
{ 3, ':', "Geocache Found" },
{ 3, ';', "Ghost Town" },
{ 3, '<', "Glider Area" },
{ 3, '=', "Golf Course" },
{ 3, '>', "Green Diamond" },
{ 3, '?', "Green Square" },
{ 3, '@', "Heliport" },
{ 3, 'A', "Horn" },
{ 3, 'B', "Hunting Area" },
{ 3, 'C', "Information" },
{ 4, '!', "Levee" },
{ 4, '"', "Light" },
{ 4, '#', "Live Theater" },
{ 4, '$', "Lodging" },
{ 4, '%', "Man Overboard" },
{ 4, '&', "Marina" },
{ 4, '\'', "Medical Facility" },
{ 4, '(', "Mile Marker" },
{ 4, ')', "Military" },
{ 4, '*', "Mine" },
{ 4, '+', "Movie Theater" },
{ 4, ',', "Museum" },
{ 4, '-', "Navaid, Amber" },
{ 4, '.', "Navaid, Black" },
{ 4, '/', "Navaid, Blue" },
{ 4, '0', "Navaid, Green" },
{ 4, '1', "Navaid, Green/Red" },
{ 4, '2', "Navaid, Green/White" },
{ 4, '3', "Navaid, Orange" },
{ 4, '4', "Navaid, Red" },
{ 4, '5', "Navaid, Red/Green" },
{ 4, '6', "Navaid, Red/White" },
{ 4, '7', "Navaid, Violet" },
{ 4, '8', "Navaid, White" },
{ 4, '9', "Navaid, White/Green" },
{ 4, ':', "Navaid, White/Red" },
{ 4, ';', "Oil Field" },
{ 4, '<', "Parachute Area" },
{ 4, '=', "Park" },
{ 4, '>', "Parking Area" },
{ 4, '?', "Pharmacy" },
{ 4, '@', "Picnic Area" },
{ 4, 'A', "Pizza" },
{ 4, 'B', "Post Office" },
{ 4, 'C', "Private Field" },
{ 5, '!', "Radio Beacon" },
{ 5, '"', "Red Diamond" },
{ 5, '#', "Red Square" },
{ 5, '$', "Residence" },
{ 5, '%', "Restaurant" },
{ 5, '&', "Restricted Area" },
{ 5, '\'', "Restroom" },
{ 5, '(', "RV Park" },
{ 5, ')', "Scales" },
{ 5, '*', "Scenic Area" },
{ 5, '+', "School" },
{ 5, ',', "Seaplane Base" },
{ 5, '-', "Shipwreck" },
{ 5, '.', "Shopping Center" },
{ 5, '/', "Short Tower" },
{ 5, '0', "Shower" },
{ 5, '1', "Skiing Area" },
{ 5, '2', "Skull and Crossbones" },
{ 5, '3', "Soft Field" },
{ 5, '4', "Stadium" },
{ 5, '5', "Summit" },
{ 5, '6', "Swimming Area" },
{ 5, '7', "Tall Tower" },
{ 5, '8', "Telephone" },
{ 5, '9', "Toll Booth" },
{ 5, ':', "TracBack Point" },
{ 5, ';', "Trail Head" },
{ 5, '<', "Truck Stop" },
{ 5, '=', "Tunnel" },
{ 5, '>', "Ultralight Area" },
{ 5, '?', "Water Hydrant" },
{ 5, '@', "Waypoint" },
{ 5, 'A', "White Buoy" },
{ 5, 'B', "White Dot" },
{ 5, 'C', "Zoo" },
};

--[[
int GetSymbolByName(char *Name)
{	int s;
	for (s=0; s<ARRAYSIZE(SymbolNames); s++)
	{	if (!_stricmp(SymbolNames[s].Primary, Name))
		{	return SymbolInt('/', SymbolNames[s].symbol);
		} else if (!_stricmp(SymbolNames[s].Alternate, Name))
		{	return SymbolInt('\\', SymbolNames[s].symbol);
		} else if (SymbolNames[s].Overlays)
		{	OVERLAY_DEFINITION_S *o;
			for (o=SymbolNames[s].Overlays;
				o && o->overlay && o->Description; o++)
			{	if (!_stricmp(o->Description, Name))
				{	return SymbolInt(o->overlay, SymbolNames[s].symbol);
				}
			}
		}
	}
	for (s=0; s<ARRAYSIZE(GPXSymbols); s++)
	{	if (!_stricmp(GPXSymbols[s].Desc, Name))
			return SymbolInt(GPXSymbols[s].Table, GPXSymbols[s].Symbol);
	}
	return 0;
}
]]

function symbols:getSymbolName(s)
	if type(s) ~= "string" then return "*NotString*" end
	if #s ~= 2 then return "*LengthError*" end
	local t, s = s:sub(1,1), s:sub(2,2)
	if t == '/' then t = 5 else t = 7 end	-- Primary[5] Alternate [7]
	if not SymbolNames[s] then return "*nilSymbolName*" end
	return SymbolNames[s][t]
end
--[[
	if (Page > 1 && Page < '!')	-- 0 and 1 are APRS symbols */
	{	int s;
		for (s=0; s<ARRAYSIZE(GPXSymbols); s++)
			if (GPXSymbols[s].Table==Page && GPXSymbols[s].Symbol==(Symbol&0xff))
				return GPXSymbols[s].Desc;
		return "*Unknown*";
	}
]]
--[[
	{	OVERLAY_DEFINITION_S *o = SymbolNames[SymIndex].Overlays;
		for (o=SymbolNames[SymIndex].Overlays; o && o->overlay && o->Description; o++)
		{	if (o->overlay == Overlay)
				return o->Description;
		}
		return SymbolNames[SymIndex].Alternate;
	}
]]
--[[
char *GetDisplayableSymbol(int Symbol)
{	int SymIndex = (Symbol & 0xff) - SymbolNames[0].symbol;
	int Page = (Symbol >> 8) & 0xff;
	int Overlay = (Symbol >> 16) & 0xff;

	if (Page > 1 && Page < '!')	-- 0 and 1 are APRS symbols */
	{	int s;
		for (s=0; s<ARRAYSIZE(GPXSymbols); s++)
			if (GPXSymbols[s].Table==Page && GPXSymbols[s].Symbol==(Symbol&0xff))
				return _strdup(GPXSymbols[s].Desc);
		return _strdup("*Unknown*");
	}

	if (SymIndex < 0 || SymIndex >= ARRAYSIZE(SymbolNames))			-- Out of range */
		return _strdup("*Unknown*");
	else if (!Page) return _strdup(SymbolNames[SymIndex].Primary);	-- Primary Table */
	else if (!Overlay) return _strdup(SymbolNames[SymIndex].Alternate);	-- Alternate Table */
--	Alternate with overlay, see if it is explicit */
	else
	{	OVERLAY_DEFINITION_S *o = SymbolNames[SymIndex].Overlays;
		for (o=SymbolNames[SymIndex].Overlays; o && o->overlay && o->Description; o++)
			if (o->overlay == Overlay)
				return _strdup(o->Description);
		{	char *symName = SymbolNames[SymIndex].Alternate;
			char *symBuf = (char*)malloc(strlen(symName)+8);
			sprintf(symBuf,"%s %c",symName, isprint(Overlay&0xff)?Overlay:'?');
			return symBuf;
		}
	}
}
]]

return symbols
