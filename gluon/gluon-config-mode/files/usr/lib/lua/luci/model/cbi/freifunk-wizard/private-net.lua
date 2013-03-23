local private_net_name = "lan"

local uci = luci.model.uci.cursor()
local nav = require "luci.tools.freifunk-wizard.nav"
local network = luci.model.network

network.init(uci)

local form = SimpleForm("private-net", "Private-Net", "<p>Hier kannst du deinen Router so konfigurieren, dass er auch ein seperates WLAN zur rein privaten Nutzung erstellt.</p>\
<p>Der Datenverkehr wird direkt ueber die Verbindung am WAN Port des Routers geleitet.</p>\
<p>Dieses Netz und das Freifunk Netz sind komplett voneinander getrennt.</p>")
form.template = "freifunk-wizard/wizardform"

private_net = form:field(Flag, "private_net", "Privates WLAN aktivieren?")
private_net.default = string.format()
private_net.rmempty = false

ssid = form:field("ssid", "Name des privaten Netzwerks")
ssid.value = uci:get_first("wireless", "", "", "private-net")

key = form:field("key", "WLAN Schluessel")
key.value = uci:get_first("wireless", "", "", "")

ipaddr = form:field("ipaddr", "Router IP")
ipaddr.value = uci:get_first("network", private_net_name, "ipaddr", "192.168.2.1")

netmask = form:field("netmask", "Router Netmask")
netmask.value = uci:get_first("network", private_net_name, "netmask", "255.255.255.0")

function form.handle(self, state, data)
    if state == FORM_VALID then
        if data.private_net == "1" then
            configure_dhcp()
            configure_firewall()
            configure_network(data.ipaddr, data.netmask)
            configure_wireless(data.ssid, data.key)

            luci.sys.call("/etc/init.d/dnsmasq enable")

            luci.http.redirect(luci.dispatcher.build_url()
        else
            nav.maybe_redirect_to_successor()
        end
    end

    return true
end

function configure_dhcp()
    local dhcp_name = string.format("dhcp %s", private_net_name)
    uci:set_list("dhcp", "dnsmasq", "interface", private_net_name)
    uci:set("dhcp", dhcp_name, "interface", private_net_name)
    uci:set("dhcp", dhcp_name, "start", "100")
    uci:set("dhcp", dhcp_name, "limit", "150")
    uci:set("dhcp", dhcp_name, "leasetime", "12h")

    uci:save("dhcp")
    uci:commit("dhcp")
end

function configure_firewall()
    --TODO check if section exists and get pointer if so
    local firewall_section_name = uci:add("firewall", "zone")
    uci:set("firewall", firewall_section_name, "network", private_net_name)
    uci:set("firewall", firewall_section_name, "input", "ACCEPT")
    uci:set("firewall", firewall_section_name, "output", "ACCEPT")
    uci:set("firewall", firewall_section_name, "forward", "REJECT")
    uci:set("firewall", firewall_section_name, "name", private_net_name)

    --TODO check if section exists and get pointer if so
    firewall_section_name = uci:add("firewall", "forwarding")
    uci:set("firewall", firewall_section_name, "src", private_net_name)
    uci:set("firewall", firewall_section_name, "dst", "wan")

    --TODO check if section exists and get pointer if so
    firewall_section_name = uci:add("firewall", "rule")
    uci:set("firewall", firewall_section_name, "src", "freifunk")
    uci:set("firewall", firewall_section_name, "dst", "wan")
    uci:set("firewall", firewall_section_name, "target", "DROP")

    --TODO check if section exists and get pointer if so
    firewall_section_name = uci:add("firewall", "rule")
    uci:set("firewall", firewall_section_name, "src", "wan")
    uci:set("firewall", firewall_section_name, "dst", "freifunk")
    uci:set("firewall", firewall_section_name, "target", "DROP")

    --TODO check if section exists and get pointer if so
    firewall_section_name = uci:add("firewall", "rule")
    uci:set("firewall", firewall_section_name, "src", "freifunk")
    uci:set("firewall", firewall_section_name, "dst", private_net_name)
    uci:set("firewall", firewall_section_name, "target", "DROP")

    --TODO check if section exists and get pointer if so
    firewall_section_name = uci:add("firewall", "rule")
    uci:set("firewall", firewall_section_name, "src", private_net_name)
    uci:set("firewall", firewall_section_name, "dst", "freifunk")
    uci:set("firewall", firewall_section_name, "target", "DROP")

    uci:save("firewall")
    uci:commit("firewall")
end

function configure_network(ipaddr, netmask)
    local net = network:get_network(private_net_name)
    local options = {"proto" = "static",
                     "type", "bridge",
                     "ipaddr", ipaddr,
                     "netmask", netmask}
    if net then
        network:del_network(private_net_name)
    end
--    uci:set("network", private_net_name, "proto", "static")
--    uci:set("network", private_net_name, "type", "bridge")
--    uci:set("network", private_net_name, "ipaddr", ipaddr)
--    uci:set("network", private_net_name, "netmask", netmask)
    network:add_network(private_net_name, options)

    --network:get_network("wan").set("masq", "1")
    uci:set("network", "wan", "masq", "1")

    network:save()
    network:commit()

    uci:save("network")
    uci:commit("network")
end

function configure_wireless(ssid, key)
    local wifi_devs = network:get_wifidevs()
    local options = {"network", private_net_name,
                     "mode", "ap",
                     "ssid", ssid,
                     "encryption", "psk2",
                     "key", key}
    for wifi_dev in wifi_devs do
        local wireless_iface_name = string.format("wifi_%s_%s",
                                                  private_net_name,
                                                  wifi_dev.name)
        options["device"] = wifi_dev.name
        network:add_wifinet(wireless_iface_name, options)
    end
    network:save()
    network:commit()
--    local wireless_iface_name = string.format("wifi_%s", private_net_name)
--    uci:set("wireless", wireless_iface_name, "device", "radio0")
--    uci:set("wireless", wireless_iface_name, "network", private_net_name)
--    uci:set("wireless", wireless_iface_name, "mode", "ap")
--    uci:set("wireless", wireless_iface_name, "ssid", ssid)
--    uci:set("wireless", wireless_iface_name, "encryption", "psk2")
--    uci:set("wireless", wireless_iface_name, "key", key)
--
--    uci:save("wireless")
--    uci:commit("wireless")
end

return form
