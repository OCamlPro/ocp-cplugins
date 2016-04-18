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


type connection

(* [send_message sock msg_id msg_content] *)
val send_message : connection -> int -> bytes -> unit

(* create sockets either as server or as client *)
module MakeSocket(S : sig

  (* [connection_handler conn_id sock sock_addr] *)
  val connection_handler : int -> connection -> Unix.sockaddr -> unit

  (* [message_handler conn_id sock msg_id msg_content] *)
  val message_handler : int -> connection -> int -> string -> unit

  (* [disconnection_handler conn_id] *)
  val disconnection_handler : int -> unit

end) : sig

  (* [create_server ~loopback ~port] returns the [port] *)
  val create_server : loopback:bool -> port:int -> int

  (* [connect conn_id sockaddr] connects to the given sockaddr.
     handlers are called with the conn_id. *)
  val connect : int -> Unix.sockaddr -> unit
end


(* PROCESSES *)



(* [system command exit_handler] *)
val system : string -> (Unix.process_status -> unit) -> unit

(* [exec exe_name args exit_handler] *)
val exec : string -> string array -> (Unix.process_status -> unit) -> unit




(* MAIN LOOP *)




(* force exit from Lwt loop (can be delayed by 0.1s) *)
val exit : unit -> unit

(* loop in Lwt until [exit] is called *)
val main : unit -> unit
