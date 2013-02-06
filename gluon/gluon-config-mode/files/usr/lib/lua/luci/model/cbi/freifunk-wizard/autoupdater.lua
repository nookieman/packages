local nav = require "luci.tools.freifunk-wizard.nav"

m = Map("autoupdater", translate("Automatische Updates"))

s = m:section(TypedSection, "autoupdater", "")
s.anonymous = true
s.addremove = false

s:option(Flag, "enabled", translate("automatische Updates aktivieren"))
s:option(Value, "url", translate("URL"))
s:option(Value, "probability", translate("Updatewahrscheinlichkeit (1 - stündlich, 0.5 - im Mittel alle zwei Stunden)"))
s:option(Value, "good_signatures", translate("Anzahl der erforderlichen gültigen Signaturen"))

s:option(DynamicList, "pubkey", translate("Öffentliche Schlüssel"))

function m.on_commit(self)
  nav.maybe_redirect_to_successor()
end

return m
