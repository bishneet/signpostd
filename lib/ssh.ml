(*
 * Copyright (c) 2012 Charalampos Rotsos <cr409@cl.cam.ac.uk>
 *
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


open Lwt
open Lwt_unix
open Lwt_list

let ssh_port = 10000

module Manager = struct
  exception SshError of string
  exception MissingSshArgumentError

  (**************************************************
   *         Tactic state
   **************************************************)
  (* storing all required informations to rebuild 
   * known_hosts file and destroy the connection *)
  type server_det = {
    ip : string;
    port : int;
    dev_id : int;
    mutable pid : int;
    cl_key : string;
  }

  (* storing all required informations to rebuild 
   * authorized_keys file and destroy the connection *)
  type client_det = {
    s_key: string;
    local_dev: int;
  }

  type conn_db_type = {
    conns_server: (string, server_det) Hashtbl.t;
    conns_client: (string, client_det) Hashtbl.t;
    mutable max_dev_id : int;
    mutable server_pid: int option;
  }

  let conn_db = {conns_server=(Hashtbl.create 32); 
                 conns_client=(Hashtbl.create 32); max_dev_id=0; 
                 server_pid=None;}


  (*********************************************************
   *       Testing methods
   *********************************************************)

  (* start the sshd server *)
  let run_server () =
    (* TODO: Check if pid is still running *)
    match conn_db.server_pid with
    | None ->(
      try
        let cmd = Unix.getcwd () ^ "/client_tactics/ssh/server" in
        let _ = Unix.create_process cmd [| cmd; Config.conf_dir |] 
        Unix.stdin Unix.stdout Unix.stderr in
        lwt _ = Lwt_unix.sleep 2.0 in 
        let buf = String.create 100 in
        let fd = Unix.openfile "/tmp/signpost_sshd.pid" [Unix.O_RDONLY]  0o640 in
        let len = Unix.read fd buf 0 100 in 
        conn_db.server_pid <- Some(int_of_string (String.sub buf 0 (len-1)));
        Printf.printf "[ssh] process created with pid %s...\n" (String.sub buf 0 (len-1));
        return("OK")
      with err ->
        Printf.eprintf "[ssh] error : %s\n%!" (Printexc.to_string err);
        failwith  (Printexc.to_string err)
        )
      | Some(_) -> 
          Printf.printf "[ssh] ssh server already started...\n%!";
          return("OK")

  (*TODO:
   * - timeout connect 
   * - if all tests fail how do I notify the server? 
   * - remove ips that match local ips *)
  let run_client port ips =
    (* check if I can connect to ssh port on a remote ip *)
    let send_pkt_to port ip = 
      let buf = String.create 1500 in
      let sock = (Lwt_unix.socket Lwt_unix.PF_INET Lwt_unix.SOCK_STREAM
                    ((Unix.getprotobyname "tcp").Unix.p_proto)) in        
      let ipaddr = (Unix.gethostbyname ip).Unix.h_addr_list.(0) in
      let portaddr = Unix.ADDR_INET (ipaddr, port) in
        try_lwt 
          lwt _ = Lwt_unix.connect sock portaddr in 
      lwt len = Lwt_unix.recv sock buf 0 1500 [] in  
    Printf.printf "[ssh] Received (%s) from ipaddr %s\n%!" (String.sub buf
                                                              0 len) ip;
    lwt _ = Lwt_unix.close sock in
    return (ip) 
      with ex ->
        Printf.eprintf "[ssh] error in client test %s\n%!" (Printexc.to_string ex);
        (* hopefully within 10 seconds someone else will have waken up to
         * provide a response *)
        Lwt_unix.sleep 10.0;
        return("")
  in
    (* Run client test for all remote ips and return the ip that reasponded first *)
    Lwt.choose (List.map (send_pkt_to port) ips )

  let test kind args =
    match kind with
      (* start ssh server *)
      | "server_start" -> run_server ()

      (* test tcp connectivity *)
      | "client" -> (
          let port :: ips = args in 
            lwt ip = run_client ssh_port ips in
    return (ip))
      | _ -> (
          Printf.printf "Action %s not supported in test" kind;
          return ("OK"))

  (*******************************************************************
   *    connection functions     
   *******************************************************************)

  let setup_dev dev_id ip =
    lwt _ = Lwt_unix.system 
              (Printf.sprintf "tunctl -t tap%d" dev_id) in
    lwt _ = Lwt_unix.system 
              (Printf.sprintf "ifconfig tap%d up" dev_id) in
    lwt _ = Lwt_unix.system 
              (Printf.sprintf "ifconfig tap%d %s netmask 255.255.255.0" 
                 dev_id ip) in
      return (ip)

  let server_add_client domain dev_id = 
    Printf.printf "[ssh] Adding new permitted key from domain %s\n%!" domain;
    lwt _ = run_server () in 
    (* Dump keys in authorized_key file *)
    let update_authorized_keys () = 
      let file = open_out "/root/.ssh/signpost_tunnel" in 
        Hashtbl.iter (fun domain client -> 
                        output_string file (client.s_key ^ "\n") 
        ) conn_db.conns_client; 
        close_out file
    in
      (* if the domain is not in the cache, add it and update the authorized
       * key file *)
      lwt _ = 
        if(Hashtbl.mem conn_db.conns_client domain) then (
          Printf.eprintf "[ssh] A connection the specific domain already exists\n%!";
          return ()
        ) else (
          lwt key = Key.ssh_pub_key_of_domain ~server:(Config.iodine_node_ip) 
                      ~port:5354 domain in
    match key with 
      | Some(key) -> 
          Hashtbl.add conn_db.conns_client domain 
            {s_key=(List.hd key);local_dev=dev_id;};
          return (update_authorized_keys ())
      | None ->
          return (Printf.printf "[ssh] Couldn't find a valid dnskey record\n%!")
        )
                 in
                   return ("OK")

  let client_add_server domain ip port local_dev = 
    Printf.printf "[ssh] Adding new know_host from domain %s\n%!" domain;
    (* Dump keys in authorized_key file *)
    let update_known_hosts () = 
      let file = open_out (Config.conf_dir ^ "/known_hosts") in 
        Hashtbl.iter (fun domain server ->
                      output_string file (
                        Printf.sprintf "[%s]:%d %s\n" 
                          server.ip server.port                    
                          server.cl_key)) conn_db.conns_server; 
        close_out file
    in
      (* if the domain is not in the cache, add it and update the authorized
       * key file *)    
      lwt _ = 
        if(Hashtbl.mem conn_db.conns_server domain) then (
          Printf.eprintf "[ssh] A connection the specific domain already exists\n%!";
          return ()
        ) else (
          lwt key = Key.ssh_pub_key_of_domain ~server:(Config.iodine_node_ip) ~port:5354 domain in
    match key with 
      | Some(key) -> 
          Hashtbl.add conn_db.conns_server domain 
            {cl_key=(List.hd key);port;ip; dev_id=local_dev;pid=0;};
          return (update_known_hosts ())
      | None ->
          return (Printf.printf "[ssh] Couldn't find a valid dnskey record\n%!")
        )
                 in
                   return ("OK")

  let client_connect server_ip server_port local_dev remote_dev subnet = 
    let cmd = Unix.getcwd () ^ "/client_tactics/ssh/client" in
    (* TODO: add pid in client state. *)
    let pid = Unix.create_process cmd [|cmd; Config.conf_dir; server_ip;
                                        (string_of_int server_port);
                                        local_dev;remote_dev; |] 
                Unix.stdin Unix.stdout Unix.stderr in
      return (Printf.sprintf "10.2.%s.2" remote_dev)


  let connect kind args =
    match kind with
      | "server" ->
          conn_db.max_dev_id <- conn_db.max_dev_id + 1;
          let dev_id = conn_db.max_dev_id in 
            server_add_client (List.hd args) dev_id;
            let dev_id = conn_db.max_dev_id in 
            let ip = Printf.sprintf "10.2.%d.1" dev_id in 
              setup_dev dev_id ip
      | "client" ->
          let server_ip = List.nth args 0 in 
          let server_port = (int_of_string (List.nth args 1)) in 
          let domain = List.nth args 2 in 
          let subnet = List.nth args 3 in 
            conn_db.max_dev_id <- conn_db.max_dev_id + 1;
            let local_dev = conn_db.max_dev_id in        
            lwt _ = client_add_server domain server_ip server_port local_dev in 
  (* Ip address is constructed using the dev number in the 3 
   * octet *)
            let remote_dev = List.nth 
                     (Re_str.split (Re_str.regexp "\\.") subnet) 3 in 
            let ip = Printf.sprintf "10.2.%s.2" remote_dev in 
            lwt _ = setup_dev local_dev ip in                 
              client_connect server_ip server_port 
                (string_of_int local_dev) remote_dev subnet  
      | _ -> 
          Printf.eprintf "[ssh] Invalid connect kind %s\n%!" kind;
          raise (SshError "Invalid connect kind")

  (*************************************************************************
   *             TEARDOWN methods of tactic
   * ***********************************************************************)

  let teardown args =
    true

  let pkt_in_cb controlleri dpid evt = 
    return ()

end