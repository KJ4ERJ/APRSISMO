--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]
--[[  Latitude/longitude spherical geodesy formulae & scripts (c) Chris Veness 2002-2011            ]]
--[[   - www.movable-type.co.uk/scripts/latlong.html                                                ]]
--[[                                                                                                ]]
--[[  Sample usage:                                                                                 ]]
--[[    var p1 = new LatLon(51.5136, -0.0983);                                                      ]]
--[[    var p2 = new LatLon(51.4778, -0.0015);                                                      ]]
--[[    var dist = p1.distanceTo(p2);          // in km                                             ]]
--[[    var brng = p1.bearingTo(p2);           // in degrees clockwise from north                   ]]
--[[    ... etc                                                                                     ]]
--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]

--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]
--[[  Note that minimal error checking is performed in this example code!                           ]]
--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]


--[[*
 * Creates a point on the earth's surface at the supplied latitude / longitude
 *
 * @constructor
 * @param {Number} lat: latitude in numeric degrees
 * @param {Number} lon: longitude in numeric degrees
 * @param {Number} [rad=6371]: radius of earth if different value is required from standard 6,371km
 ]]
 
local LatLon = {} -- The "Class" 

LatLon.new = function(lat, lon, radius)

	local self = {}	-- Object to return
	lat = lat or 0	-- Default if nill
	lon = lon or 0	-- Default if nil
	radius = radius or 6371	-- Radius of the earth in km

	-- #Getters
	self.getlat = function() return lat end
	self.getlon = function() return lon end
	self.getradius = function() return radius end
	
	-- #Setters
	self.setlat = function(arg) lat = arg end
	self.setlon = function(arg) lon = arg end
	self.setradius = function(arg) radius = arg end

--[[*
 * Returns the distance from this point to the supplied point, in km 
 * (using Haversine formula)
 *
 * from: Haversine formula - R. W. Sinnott, "Virtues of the Haversine",
 *       Sky and Telescope, vol 68, no 2, 1984
 *
 * @param   {LatLon} point: Latitude/longitude of destination point
 * @param   {Number} [precision=4]: no of significant digits to use for returned value
 * @returns {Number} Distance in km between this point and destination point
 ]]
 
self.distanceTo = function(point, precision)

	precision = precision or 4	-- default 4 sig figs reflects typical 0.3% accuracy of spherical model
  
	local R = radius
	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)
	local lat2 = math.rad(point.getlat())
	local lon2 = math.rad(point.getlon())
	local dLat = lat2 - lat1
	local dLon = lon2 - lon1

	local a = math.sin(dLat/2) * math.sin(dLat/2) +
          math.cos(lat1) * math.cos(lat2) * 
          math.sin(dLon/2) * math.sin(dLon/2)
	local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
	local d = R * c;
	-- return d.toPrecisionFixed(precision);
	return d
end

--[[*
 * Returns the (initial) bearing from this point to the supplied point, in degrees
 *   see http://williams.best.vwh.net/avform.htm#Crs
 *
 * @param   {LatLon} point: Latitude/longitude of destination point
 * @returns {Number} Initial bearing in degrees from North
 ]]

self.bearingTo = function(point)

	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)
	local lat2 = math.rad(point.getlat())
	local lon2 = math.rad(point.getlon())
	local dLon = lon2 - lon1

	local y = math.sin(dLon) * math.cos(lat2)
	local x = math.cos(lat1)*math.sin(lat2) -
          math.sin(lat1)*math.cos(lat2)*math.cos(dLon);
	local brng = math.atan2(y, x)
  
	return (math.deg(brng)+360) % 360
end

--[[*
 * Returns final bearing arriving at supplied destination point from this point; the final bearing 
 * will differ from the initial bearing by varying degrees according to distance and latitude
 *
 * @param   {LatLon} point: Latitude/longitude of destination point
 * @returns {Number} Final bearing in degrees from North
 ]]
 
self.finalBearingTo = function(point)

	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)
	local lat2 = math.rad(point.getlat())
	local lon2 = math.rad(point.getlon())
	local dLon = lon2 - lon1

	local y = math.sin(dLon) * math.cos(lat2)
	local x = math.cos(lat1)*math.sin(lat2) -
          math.sin(lat1)*math.cos(lat2)*math.cos(dLon)
	local brng = math.atan2(y, x)
          
  -- ... & reverse it by adding 180°
  return (brng.toDeg()+180) % 360
end


--[[*
 * Returns the midpoint between this point and the supplied point.
 *   see http://mathforum.org/library/drmath/view/51822.html for derivation
 *
 * @param   {LatLon} point: Latitude/longitude of destination point
 * @returns {LatLon} Midpoint between this point and the supplied point
 ]]
self.midpointTo = function(point)

	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)
	local lat2 = math.rad(point.getlat())
	local lon2 = math.rad(point.getlon())
	local dLon = lon2 - lon1

	local Bx = math.cos(lat2) * math.cos(dLon)
	local By = math.cos(lat2) * math.sin(dLon)

	local lat3 = math.atan2(math.sin(lat1)+math.sin(lat2),
                    math.sqrt( (math.cos(lat1)+Bx)*(math.cos(lat1)+Bx) + By*By) )
	lon3 = lon1 + math.atan2(By, math.cos(lat1) + Bx)
	lon3 = (lon3+3*math.pi) % (2*math.pi) - math.pi  -- normalise to -180..+180º
  
  return LatLon.new(math.deg(lat3), math.deg(lon3))
end


--[[*
 * Returns the destination point from this point having travelled the given distance (in km) on the 
 * given initial bearing (bearing may vary before destination is reached)
 *
 *   see http://williams.best.vwh.net/avform.htm#LL
 *
 * @param   {Number} brng: Initial bearing in degrees
 * @param   {Number} dist: Distance in km
 * @returns {LatLon} Destination point
 ]]

self.destinationPoint = function(brng, dist)
  dist = dist/radius  -- convert dist to angular distance in radians
  brng = math.rad(brng)  -- 
	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)

	local lat2 = math.asin( math.sin(lat1)*math.cos(dist) + 
                        math.cos(lat1)*math.sin(dist)*math.cos(brng) )
	local lon2 = lon1 + math.atan2(math.sin(brng)*math.sin(dist)*math.cos(lat1), 
                               math.cos(dist)-math.sin(lat1)*math.sin(lat2))
	lon2 = (lon2+3*math.pi) % (2*math.pi) - math.pi;  -- normalise to -180..+180º

  return LatLon.new(math.deg(lat2), math.deg(lon2))
end


--[[*
 * Returns the point of intersection of two paths defined by point and bearing
 *
 *   see http://williams.best.vwh.net/avform.htm#Intersection
 *
 * @param   {LatLon} p1: First point
 * @param   {Number} brng1: Initial bearing from first point
 * @param   {LatLon} p2: Second point
 * @param   {Number} brng2: Initial bearing from second point
 * @returns {LatLon} Destination point (null if no unique intersection defined)
 ]]
self.intersection = function(p1, brng1, p2, brng2)
	local lat1 = math.rad(p1.getlat())
	local lon1 = math.rad(p1.getlon())
	local lat2 = math.rad(p2.getlat())
	local lon2 = math.rad(p2.getlon())
	local brng13 = math.rad(brng1)
	local brng23 = math.rad(brng2)
	local dLat = lat2-lat1
	local dLon = lon2-lon1

	local dist12 = 2*math.asin( math.sqrt( math.sin(dLat/2)*math.sin(dLat/2) + 
		math.cos(lat1)*math.cos(lat2)*math.sin(dLon/2)*math.sin(dLon/2) ) );
	if (dist12 == 0) then return nil end
  
  -- initial/final bearings between points
	local brngA = math.acos( ( math.sin(lat2) - math.sin(lat1)*math.cos(dist12) ) / 
					( math.sin(dist12)*math.cos(lat1) ) );
	if (isNaN(brngA)) then brngA = 0 end  -- protect against rounding
	local brngB = math.acos( ( math.sin(lat1) - math.sin(lat2)*math.cos(dist12) ) / 
					( math.sin(dist12)*math.cos(lat2) ) );
  
  if (math.sin(lon2-lon1) > 0) then
    brng12 = brngA;
    brng21 = 2*math.pi - brngB;
  else
    brng12 = 2*math.pi - brngA;
    brng21 = brngB;
  end
  
  local alpha1 = (brng13 - brng12 + math.pi) % (2*math.pi) - math.pi;  -- angle 2-1-3
  local alpha2 = (brng21 - brng23 + math.pi) % (2*math.pi) - math.pi;  -- angle 1-2-3
  
  if (math.sin(alpha1)==0 and math.sin(alpha2)==0) then return nil end  -- infinite intersections
  if (math.sin(alpha1)*math.sin(alpha2) < 0) then return nil end       -- ambiguous intersection
  
  --alpha1 = math.abs(alpha1);
  --alpha2 = math.abs(alpha2);
  -- ... Ed Williams takes abs of alpha1/alpha2, but seems to break calculation?
  
  local alpha3 = math.acos( -math.cos(alpha1)*math.cos(alpha2) + 
                       math.sin(alpha1)*math.sin(alpha2)*math.cos(dist12) );
  local dist13 = math.atan2( math.sin(dist12)*math.sin(alpha1)*math.sin(alpha2), 
                       math.cos(alpha2)+math.cos(alpha1)*math.cos(alpha3) )
  local lat3 = math.asin( math.sin(lat1)*math.cos(dist13) + 
                    math.cos(lat1)*math.sin(dist13)*math.cos(brng13) );
  local dLon13 = math.atan2( math.sin(brng13)*math.sin(dist13)*math.cos(lat1), 
                       math.cos(dist13)-math.sin(lat1)*math.sin(lat3) );
  local lon3 = lon1+dLon13;
  local lon3 = (lon3+3*math.pi) % (2*math.pi) - math.pi;  -- normalise to -180..+180º
  
  return LatLon.new(math.deg(lat3), math.deg(lon3))
end


--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]

--[[*
 * Returns the distance from this point to the supplied point, in km, travelling along a rhumb line
 *
 *   see http://williams.best.vwh.net/avform.htm#Rhumb
 *
 * @param   {LatLon} point: Latitude/longitude of destination point
 * @returns {Number} Distance in km between this point and destination point
 ]]
self.rhumbDistanceTo = function(point)
	local R = this._radius;
	local lat1 = math.rad(lat)
	local lat2 = math.rad(point.getlat());
	local dLat = math.rad(point.getlat()-lat)
	local dLon = math.rad(math.abs(point.getlon()-lon))

	local dPhi = math.log(math.tan(lat2/2+math.pi/4)/math.tan(lat1/2+math.pi/4))
	local q -- = (!isNaN(dLat/dPhi)) ? dLat/dPhi : math.cos(lat1);  -- E-W line gives dPhi=0
	if (dPhi ~= 0) then q = dLat/dPhi else q = math.cos(lat1) end  -- E-W line gives dPhi=0
  -- if dLon over 180° take shorter rhumb across 180° meridian:
	if (dLon > math.pi) then dLon = 2*math.pi - dLon end
	local dist = math.sqrt(dLat*dLat + q*q*dLon*dLon) * R; 
  
  return dist.toPrecisionFixed(4);  -- 4 sig figs reflects typical 0.3% accuracy of spherical model
end

--[[*
 * Returns the bearing from this point to the supplied point along a rhumb line, in degrees
 *
 * @param   {LatLon} point: Latitude/longitude of destination point
 * @returns {Number} Bearing in degrees from North
 ]]
self.rhumbBearingTo = function(point)
	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)
	local dLon = math.rad(point.getlon()-lon)
  
	local dPhi = math.log(math.tan(lat2/2+math.pi/4)/math.tan(lat1/2+math.pi/4));
	if (math.abs(dLon) > math.pi) then
		if (dLon>0) then dLon = -(2*math.pi-dLon)
		else dlon = (2*math.pi+dLon)
		end
	end
	local brng = math.atan2(dLon, dPhi);
  
  return (brng.toDeg()+360) % 360
end

--[[*
 * Returns the destination point from this point having travelled the given distance (in km) on the 
 * given bearing along a rhumb line
 *
 * @param   {Number} brng: Bearing in degrees from North
 * @param   {Number} dist: Distance in km
 * @returns {LatLon} Destination point
 ]]
self.rhumbDestinationPoint = function(brng, dist)
	local R = this._radius;
	local d = parseFloat(dist)/R;  -- d = angular distance covered on earth's surface
	local lat1 = math.rad(lat)
	local lon1 = math.rad(lon)
	brng = brng.toRad();

	local lat2 = lat1 + d*math.cos(brng);
	local dLat = lat2-lat1;
	local dPhi = math.log(math.tan(lat2/2+math.pi/4)/math.tan(lat1/2+math.pi/4));
	local q -- = (!isNaN(dLat/dPhi)) ? dLat/dPhi : math.cos(lat1);  -- E-W line gives dPhi=0
	if (dPhi ~= 0) then q = dLat/dPhi else q = math.cos(lat1) end  -- E-W line gives dPhi=0
	local dLon = d*math.sin(brng)/q;
  -- check for some daft bugger going past the pole
	if (math.abs(lat2) > math.pi/2) then
		if (lat2>0) then lat2 = math.pi-lat2
		else lat2 = -math.pi-lat2
		end
	end
	lon2 = (lon1+dLon+3*math.pi)%(2*math.pi) - math.pi;
 
  return LatLon.new(math.deg(lat2), math.deg(lon2))
end

	--#### PREVENT READ AND WRITE ACCESS TO THE RETURNED TABLE
	local mt = self

	-- PREVENT WRITE ACCESS AND ABORT APPROPRIATELY
	mt.__newindex = function(table, key, value)
		local msg = string.format("%s %s %s %s %s",
			"Attempt to illegally set LatLon object key",
			tostring(key), 
			"to value",
			tostring(value),
			", aborting...\n\n"
			)
		io.stderr:write(msg)
		os.exit(1)
	end

	-- PREVENT READ ACCESS AND ABORT APPROPRIATELY
	mt.__index = function(table, key)
		if type(key) ~= "function" then
		io.stderr:write("Attempt to illegally read attribute " ..
			tostring(key) .. " from LatLon object, aborting...\n\n")
		os.exit(1)
		end
	end

	-- WRITE NEW __index AND __newindex TO METATABLE
	setmetatable(self, mt)

	return self         --VERY IMPORTANT, RETURN ALL THE METHODS!
end
--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]


--[[*
 * Returns the latitude of this point; signed numeric degrees if no format, otherwise format & dp 
 * as per Geo.toLat()
 *
 * @param   {String} [format]: Return value as 'd', 'dm', 'dms'
 * @param   {Number} [dp=0|2|4]: No of decimal places to display
 * @returns {Number|String} Numeric degrees if no format specified, otherwise deg/min/sec
 *
 * @requires Geo
 ]]
--[[
LatLon.prototype.lat = function(format, dp)
  if (typeof format == 'undefined') return this._lat;
  
  return Geo.toLat(this._lat, format, dp);
end
]]

--[[*
 * Returns the longitude of this point; signed numeric degrees if no format, otherwise format & dp 
 * as per Geo.toLon()
 *
 * @param   {String} [format]: Return value as 'd', 'dm', 'dms'
 * @param   {Number} [dp=0|2|4]: No of decimal places to display
 * @returns {Number|String} Numeric degrees if no format specified, otherwise deg/min/sec
 *
 * @requires Geo
 ]]
--[[
LatLon.prototype.lon = function(format, dp) {
  if (typeof format == 'undefined') return this._lon;
  
  return Geo.toLon(this._lon, format, dp);
}
]]

--[[*
 * Returns a string representation of this point; format and dp as per lat()/lon()
 *
 * @param   {String} [format]: Return value as 'd', 'dm', 'dms'
 * @param   {Number} [dp=0|2|4]: No of decimal places to display
 * @returns {String} Comma-separated latitude/longitude
 *
 * @requires Geo
 ]]
--[[
LatLon.prototype.toString = function(format, dp) {
  if (typeof format == 'undefined') format = 'dms';
  
  if (isNaN(this._lat) || isNaN(this._lon)) return '-,-';
  
  return Geo.toLat(this._lat, format, dp) + ', ' + Geo.toLon(this._lon, format, dp);
}
]]

--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]

-- ---- extend Number object with methods for converting degrees/radians

--[[* Converts numeric degrees to radians ]]
--[[
if (typeof(Number.prototype.toRad) === "undefined") {
  Number.prototype.toRad = function() {
    return this * math.pi / 180;
  }
}
]]

--[[* Converts radians to numeric (signed) degrees ]]
--[[if (typeof(Number.prototype.toDeg) === "undefined") {
  Number.prototype.toDeg = function() {
    return this * 180 / math.pi;
  }
}
]]

--[[* 
 * Formats the significant digits of a number, using only fixed-point notation (no exponential)
 * 
 * @param   {Number} precision: Number of significant digits to appear in the returned string
 * @returns {String} A string representation of number which contains precision significant digits
 ]]
--[[
if (typeof(Number.prototype.toPrecisionFixed) === "undefined") {
  Number.prototype.toPrecisionFixed = function(precision) {
    if (isNaN(this)) return 'NaN';
  	local numb = this < 0 ? -this : this;  -- can't take log of -ve number...
  	local sign = this < 0 ? '-' : '';
    
    if (numb == 0) {  -- can't take log of zero, just format with precision zeros
    	local n = '0.'; 
      while (precision--) n += '0'; 
      return n 
    }
  
  	local scale = math.ceil(math.log(numb)*math.LOG10E);  -- no of digits before decimal
  	local n = String(math.round(numb * math.pow(10, precision-scale)));
    if (scale > 0) {  -- add trailing zeros & insert decimal as required
      l = scale - n.length;
      while (l-- > 0) n = n + '0';
      if (scale < n.length) n = n.slice(0,scale) + '.' + n.slice(scale);
    } else {          -- prefix decimal and leading zeros if required
      while (scale++ < 0) n = '0' + n;
      n = '0.' + n;
    }
    return sign + n;
  }
}
]]

--[[* Trims whitespace from string (q.v. blog.stevenlevithan.com/archives/faster-trim-javascript) ]]
--[[
if (typeof(String.prototype.trim) === "undefined") {
  String.prototype.trim = function() {
    return String(this).replace(/^\s\s*/, '').replace(/\s\s*$/, '');
  }
}
]]

--[[ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  ]]

return LatLon
