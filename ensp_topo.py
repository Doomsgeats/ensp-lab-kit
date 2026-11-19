# -*- coding: utf-8 -*-
"""Generate a Huawei eNSP .topo file from a JSON description.

Why this exists: hand-placing devices in eNSP is slow and unrepeatable, and the
.topo format is undocumented XML. With this you keep the lab in a text file you
can diff, and regenerate the topology whenever you need a clean one.

Usage:
    python ensp_topo.py demo/ring4.json out.topo

JSON shape:
{
  "version": "1.3.00.200T",
  "mac_prefix": "4C-1F-CC-11-00",
  "devices": [
    {"name": "SD", "model": "S5700", "cx": 300, "cy": 170, "com_port": 2001},
    {"name": "Source1", "model": "PC", "cx": 300, "cy": 610,
     "ip": "10.10.8.2", "gw": "10.10.8.1", "igmp": 2,
     "group_start": "232.1.1.1", "group_num": 2, "group_step": 2}
  ],
  "links": [["SD", 1, "Source1", 1]]
}

Notes that cost real time to learn:
  * com_port is the port the device's console listens on (eNSP opens
    127.0.0.1:<com_port>). Do not assume ordering: read it back from the file
    you generated, or you will configure the wrong switch.
  * Port numbers in "links" are 1-based like the label (GE0/0/1 -> 1); the
    interfacePair index stored in the file is 0-based.
  * S5700 devices need no VirtualBox. Only routers/APs do, and VBox has been
    broken on recent Windows 11 builds (RTLdrOpenWithReader failed, 0xfffffd8e).
"""
import json
import os
import sys
import uuid

PC_SETTINGS = (
    " -simpc_ip {ip}  -simpc_mask 255.255.255.0  -simpc_gateway {gw} "
    "-simpc_mac {mac}  -simpc_mc_dstip 0.0.0.0  -simpc_mc_dstmac 00-00-00-00-00-00 "
    " -simpc_dns1 0.0.0.0  -simpc_dns2 0.0.0.0  -simpc_ipv6 ::  -simpc_prefix 128 "
    " -simpc_gatewayv6 ::  -simpc_dhcp_state 0  -simpc_dhcpv6_state 0  -simpc_dns_auto_state 0 "
    " -simpc_igmp_version {igmp}  -simpc_group_ip_start {gstart}  -simpc_src_ip_start {sstart} "
    " -simpc_group_num {gnum}  -simpc_group_step {gstep}  -simpc_src_num {snum}  "
    "-simpc_src_step {sstep}  -simpc_type MODE_IS_INCLUDE "
)


def fmt(value):
    return "%.6f" % float(value)


def build(spec):
    mac_prefix = spec.get("mac_prefix", "4C-1F-CC-11-00")
    version = spec.get("version", "1.3.00.200T")

    devices = []
    ids = {}
    for raw in spec["devices"]:
        device_id = str(uuid.uuid4()).upper()
        ids[raw["name"]] = device_id
        index = len(devices) + 1
        devices.append(
            dict(
                id=device_id,
                name=raw["name"],
                model=raw.get("model", "S5700"),
                cx=raw.get("cx", 300),
                cy=raw.get("cy", 300),
                com_port=str(raw.get("com_port", 0)),
                mac="%s-%02X" % (mac_prefix, index),
                settings="",
            )
        )
        if raw.get("model", "S5700") == "PC":
            devices[-1]["settings"] = PC_SETTINGS.format(
                ip=raw.get("ip", "0.0.0.0"),
                gw=raw.get("gw", "0.0.0.0"),
                mac=devices[-1]["mac"],
                igmp=raw.get("igmp", 2),
                gstart=raw.get("group_start", "0.0.0.0"),
                sstart=raw.get("source_start", "0.0.0.0"),
                gnum=raw.get("group_num", 0),
                gstep=raw.get("group_step", 0),
                snum=raw.get("source_num", 0),
                sstep=raw.get("source_step", 0),
            )

    parts = ['<?xml version="1.0" encoding="UNICODE" ?>', '<topo version="%s">' % version, "    <devices>"]
    for d in devices:
        if d["model"] == "PC":
            parts.append(
                '        <dev id="%s" name="%s" poe="0" model="PC" settings="%s" system_mac="%s" '
                'com_port="0" bootmode="0" cx="%s" cy="%s" edit_left="%d" edit_top="%d">'
                % (d["id"], d["name"], d["settings"], d["mac"], fmt(d["cx"]), fmt(d["cy"]),
                   d["cx"] + 29, d["cy"] + 54)
            )
            iface = ('                <interface sztype="Ethernet" interfacename="Ethernet" count="1" />')
        else:
            parts.append(
                '        <dev id="%s" name="%s" poe="0" model="%s" settings="" system_mac="%s" '
                'com_port="%s" bootmode="0" cx="%s" cy="%s" edit_left="%d" edit_top="%d">'
                % (d["id"], d["name"], d["model"], d["mac"], d["com_port"],
                   fmt(d["cx"]), fmt(d["cy"]), d["cx"] + 29, d["cy"] + 54)
            )
            iface = ('                <interface sztype="Ethernet" interfacename="GE" count="24" />')
        parts.append('            <slot number="slot17" isMainBoard="1">')
        parts.append(iface)
        parts.append("            </slot>")
        parts.append("        </dev>")
    parts.append("    </devices>")

    position = {d["id"]: (d["cx"], d["cy"]) for d in devices}
    parts.append("    <lines>")
    for a, pa, b, pb in spec.get("links", []):
        sid, did = ids[a], ids[b]
        sx, sy = position[sid]
        dx, dy = position[did]
        parts.append('        <line srcDeviceID="%s" destDeviceID="%s">' % (sid, did))
        parts.append(
            '            <interfacePair lineName="Copper" srcIndex="%d" srcBoundRectIsMoved="0" '
            'srcBoundRect_X="%s" srcBoundRect_Y="%s" srcOffset_X="0.000000" srcOffset_Y="0.000000" '
            'tarIndex="%d" tarBoundRectIsMoved="0" tarBoundRect_X="%s" tarBoundRect_Y="%s" '
            'tarOffset_X="0.000000" tarOffset_Y="0.000000" />'
            % (pa - 1, fmt(sx), fmt(sy), pb - 1, fmt(dx), fmt(dy))
        )
        parts.append("        </line>")
    parts.append("    </lines>")
    parts.append("    <shapes>")
    parts.append("    </shapes>")
    parts.append("    <txttips>")
    parts.append("    </txttips>")
    parts.append("</topo>")
    return "\n".join(parts) + "\n", devices


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    spec_path = argv[1]
    out_path = argv[2] if len(argv) > 2 else os.path.splitext(spec_path)[0] + ".topo"

    with open(spec_path, "r", encoding="utf-8") as fh:
        spec = json.load(fh)

    text, devices = build(spec)
    out_dir = os.path.dirname(os.path.abspath(out_path))
    os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)

    print("written %s (%d bytes)" % (out_path, len(text.encode("utf-8"))))
    for d in devices:
        if d["com_port"] != "0":
            print("  console  %-8s %s  (127.0.0.1:%s)" % (d["model"], d["name"], d["com_port"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))