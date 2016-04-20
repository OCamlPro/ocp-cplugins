(**************************************************************************)
(*                                                                        *)
(*                        OCamlPro Typerex                                *)
(*                                                                        *)
(*   Copyright OCamlPro 2011-2016. All rights reserved.                   *)
(*   This file is distributed under the terms of the GPL v3.0             *)
(*   (GNU General Public Licence version 3.0).                            *)
(*                                                                        *)
(*     Contact: <typerex@ocamlpro.com> (http://www.ocamlpro.com/)         *)
(*                                                                        *)
(*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *)
(*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       *)
(*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              *)
(*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   *)
(*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    *)
(*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     *)
(*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      *)
(*  SOFTWARE.                                                             *)
(**************************************************************************)


(* SOCKETS *)


type 'info connection

val info : 'info connection -> 'info

(* [send_message sock msg_id msg_content] *)
val send_message : 'info connection -> string -> unit

(* create sockets either as server or as client *)
module MakeSocket(S : sig
  type server_info
  type info

  val connection_info : server_info -> Unix.sockaddr -> info

  (* [connection_handler sock ] *)
  val connection_handler : info connection -> unit

  (* [message_handler conn_id sock msg_id msg_content] *)
  val message_handler : info connection -> string -> unit

  (* [disconnection_handler conn_id] *)
  val disconnection_handler : info -> unit

end) : sig

  (* [create ~loopback ~port] returns the [port] *)
  val create : loopback:bool -> ?port:int -> S.server_info -> int

  (* [connect conn_id sockaddr] connects to the given sockaddr.
     handlers are called with the conn_id. *)
  val connect : S.info -> Unix.sockaddr -> S.info connection

end

(* create sockets as server only *)
module MakeServer(S : sig
  type server_info
  type info

  val connection_info : server_info -> Unix.sockaddr -> info

  (* [connection_handler sock ] *)
  val connection_handler : info connection -> unit

  (* [message_handler conn_id sock msg_id msg_content] *)
  val message_handler : info connection -> string -> unit

  (* [disconnection_handler conn_id] *)
  val disconnection_handler : info -> unit

end) : sig

  (* [create ~loopback ~port] returns the [port] *)
  val create : loopback:bool -> ?port:int -> S.server_info -> int

end

(* create sockets as client only *)
module MakeClient(S : sig

  type info

  (* [connection_handler sock ] *)
  val connection_handler : info connection -> unit

  (* [message_handler conn_id sock msg_id msg_content] *)
  val message_handler : info connection -> string -> unit

  (* [disconnection_handler conn_id] *)
  val disconnection_handler : info -> unit

end) : sig

  (* [connect conn_id sockaddr] connects to the given sockaddr.
     handlers are called with the conn_id. *)
  val connect : S.info -> Unix.sockaddr -> S.info connection

end


(* PROCESSES *)



(* [system command exit_handler] *)
val system : string -> (Unix.process_status -> unit) -> unit

(* [exec exe_name args exit_handler] *)
val exec : string -> string array -> (Unix.process_status -> unit) -> unit

(* [exec exe_name args exit_handler], filenames can be specified to be
   read for stdin, and written for stdout/stderr. Can raise an error if
   stdin file does not exist/not readable, or stdout/stderr files cannot
   be created/written to. *)
val exec : string -> string array ->
  ?stdin:string -> ?stdout:string -> ?stderr:string ->
  (Unix.process_status -> unit) -> unit




(* MAIN LOOP *)




(* force exit from Lwt loop (can be delayed by 0.1s) *)
val exit : unit -> unit

(* loop in Lwt until [exit] is called *)
val main : unit -> unit
