(*
 * Copyright (c) 2012 Sebastian Probst Eide <sebastian.probst.eide@gmail.com>
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

type sp_msg = {
  src_ip : int32;
  src_port : int;
  cmd : Sp_rpc.t option;
}

val echo_port: int64

module type HandlerSig = sig
  val handle_request : Lwt_unix.file_descr -> int32 ->  Sp_rpc.command ->
    Sp_rpc.arg list -> Sp.request_response Lwt.t
  val handle_notification : Lwt_unix.file_descr -> int32 -> 
    Sp_rpc.command -> Sp_rpc.arg list -> unit Lwt.t
end

module type Functor = sig
  val thread_client : address:Sp.ip -> port:Sp.port -> (unit -> unit Lwt.t) -> unit Lwt.t 
  val thread_server : address:Sp.ip -> port:Sp.port -> unit Lwt.t
end

module Make (Handler : HandlerSig) : Functor 
