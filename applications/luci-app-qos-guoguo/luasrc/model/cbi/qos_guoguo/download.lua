--[[
luci for QoS by GuoGuo
Based on luci-app-qos-gargoyle.
]]--

local wa = require "luci.tools.webadmin"
local fs = require "nixio.fs"
local sys = require "luci.sys"

m = Map("qos_guoguo", translate("Download Settings"))


s = m:section(TypedSection, "download_class", translate("Service Classes"), 
		translate("Each service class is specified by four parameters: percent bandwidth at capacity, realtime bandwidth and maximum bandwidth and the minimimze round trip time flag.") .. "<br />" ..
		translate("<em>Percent bandwidth at capacity</em> is the percentage of the total available bandwidth that should be allocated to this class when all available bandwidth is being used. If unused bandwidth is available, more can (and will) be allocated. The percentages can be configured to equal more (or less) than 100, but when the settings are applied the percentages will be adjusted proportionally so that they add to 100. This setting only comes into effect when the WAN link is saturated.").. "<br />" ..
		translate("<em>Minimum bandwidth</em> specifies the minimum service this class will be allocated when the link is at capacity. Classes which specify minimum service are known as realtime classes by the active congestion controller. Streaming video, VoIP and interactive online gaming are all examples of applications that must have a minimum bandwith to function. To determine what to enter use the application on an unloaded LAN and observe how much bandwidth it uses. Then enter a number only slightly higher than this into this field. QoS will satisfiy the minimum service of all classes first before allocating to other waiting classes so be careful to use minimum bandwidths sparingly.") .. "<br />" ..
		translate("<em>Maximum bandwidth</em> specifies an absolute maximum amount of bandwidth this class will be allocated in kbit/s. Even if unused bandwidth is available, this service class will never be permitted to use more than this amount of bandwidth.") .. "<br />" ..
		translate("<em>Minimize RTT</em> indicates to the active congestion controller that you wish to minimize round trip times (RTT) when this class is active. Use this setting for online gaming or VoIP applications that need low round trip times (ping times). Minimizing RTT comes at the expense of efficient WAN throughput so while these class are active your WAN throughput will decline (usually around 20%).")
	)
s.addremove = true
s.template = "cbi/tblsection"


name = s:option(Value, "name", translate("Class Name"))

pb = s:option(Value, "percent_bandwidth", translate("Percent bandwidth at capacity"))

minb = s:option(Value, "min_bandwidth", translate("Minimum bandwidth"))
minb.datatype = "and(uinteger,min(0))"

maxb = s:option(Value, "max_bandwidth", translate("Maximum bandwidth"))
maxb.datatype = "and(uinteger,min(0))"

minRTT = s:option(ListValue, "minRTT", translate("Minimize RTT"))
minRTT:value("Yes")
minRTT:value("No")
minRTT.default = "No"

s = m:section(TypedSection, "download_rule", translate("Classification Rules"),
	translate("Packets are tested against the rules in the order specified -- rules toward the top have priority. As soon as a packet matches a rule it is classified, and the rest of the rules are ignored. The order of the rules can be altered using the arrow controls.")
	)
s.addremove = true
s.sortable = true
s.anonymous = true
s.template = "cbi/tblsection"

class = s:option(Value, "class", translate("Service Class"))
for l in io.lines("/etc/config/qos_guoguo") do
	local s = l
	l = string.gsub(l, "config ['\"]*download_class['\"]* ", "")
	if s ~= l then
		l = string.gsub(l, "^'", "")
		l = string.gsub(l, "^\"", "")
		l = string.gsub(l, "'$", "")
		l = string.gsub(l, "\"$", "")
		class:value(l, m.uci:get("qos_guoguo", l, "name"))
	end
end

pr = s:option(Value, "proto", translate("Application Protocol"))
pr:value("tcp")
pr:value("udp")
pr:value("icmp")
pr:value("gre")
pr.rmempty = "true"

sip = s:option(Value, "source", translate("Source IP"))
wa.cbi_add_knownips(sip)
sip.datatype = "and(ipaddr)"

dip = s:option(Value, "destination", translate("Destination IP"))
wa.cbi_add_knownips(dip)
dip.datatype = "and(ipaddr)"

s:option(Value, "dstport", translate("Destination Port")).datatype = "and(uinteger,max(65536),min(1))"

s:option(Value, "srcport", translate("Source Port")).datatype = "and(uinteger,max(65536),min(1))"

min_pkt_size = s:option(Value, "min_pkt_size", translate("Minimum Packet Length"))
min_pkt_size.datatype = "and(uinteger,min(1))"

max_pkt_size = s:option(Value, "max_pkt_size", translate("Maximum Packet Length"))
max_pkt_size.datatype = "and(uinteger,min(1))"

connbytes_kb = s:option(Value, "connbytes_kb", translate("Connection bytes reach"))
connbytes_kb.datatype = "and(uinteger,min(0))"

if (tonumber(sys.exec("lsmod | cut -d ' ' -f 1 | grep -c 'xt_ndpi'"))) > 0 then
	ndpi = s:option(Value, "ndpi", translate("DPI protocol"))
	local pats = io.popen("iptables -m ndpi --help | grep -e '^--'")
	if pats then
		local l,s,e,_,prt_v,prt_d
		while true do
			l = pats:read("*l")
			if not l then break end
			s,e = l:find("%-%-[^%s]+")
			if s and e then
				prt_v=l:sub(s+2,e)
			end
			s,e = l:find("for [^%s]+ protocol")
				if s and e then
				prt_d=l:sub(s+3,e-9)
			end
			ndpi:value(prt_v,prt_d)
			end
			pats:close()
	end
end
return m

