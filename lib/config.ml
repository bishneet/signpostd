(*
 * Copyright (c) 2012 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)


let user = "sebastian"
let signpost_number = 1
let domain = "signpo.st"
let ip_slash_24 = "172.16.11."
(* This is the ip of the local test machine *)
let external_ip = "23.23.179.30"
let external_dns = "23.23.179.30" 

let dir = "/root/signpostd/"
let conf_dir = dir ^ "/conf/"
let tmp_dir = dir ^ "/tmp/"
let iodine_node_ip = "172.16.11.1"
let iodine_node_ip = "23.23.179.30" 
let ns_server="8.8.8.8"
(* for testing *)

let signal_port = 3456
let dns_port = 5354

(* RPCs timeout after 5 minutes *)
let rpc_timeout = 5 * 6
let monitor_timeout = 5.0
let monitor_interval = 10.0
let tunnel_check_interval = 30.0 

let net_intf = "eth0"
let bridge_intf = "br0"
let ovs = "/ovs-vsctl"
let root_dir="/root/"
