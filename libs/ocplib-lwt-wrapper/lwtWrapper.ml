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

(* A simple client-server *)

type connection = Lwt_unix.file_descr

  let should_exit = ref false
  let main () =
    let rec sleep () =
      (* Printf.eprintf "_%!"; *)
      Lwt.bind (Lwt_unix.sleep 0.1)
        (fun () ->
          if not !should_exit then sleep () else Lwt.return ())
    in
    Lwt_main.run (sleep ())

  let exit () =
    (* Printf.eprintf "should exit\n%!"; *)
    should_exit := true

  let send_message fd msg_id msg =
    let len = String.length msg in
    let s = Bytes.create (8+len) in
    EndianString.LittleEndian.set_int32 s 0 (Int32.of_int len);
    EndianString.LittleEndian.set_int32 s 4 (Int32.of_int msg_id);
    Bytes.blit_string s 8 msg 0 len;
    Lwt.async (fun () -> Lwt_unix.write fd s 0 (8+len))

module MakeSocket(S : sig

  val connection_handler : int -> Lwt_unix.file_descr -> Unix.sockaddr -> unit
  val message_handler : int -> Lwt_unix.file_descr -> int -> string -> unit
  val disconnection_handler : int -> unit

end) = (struct

  let rec iter_read id fd b pos =
    (* Printf.eprintf "\titer_read %d...\n%!" pos; *)
    Lwt.bind (Lwt_unix.read fd b pos (Bytes.length b - pos))
      (fun nr ->
        (* Printf.eprintf "\titer_read %d/%d...\n%!" nr pos; *)
        if nr > 0 then
          iter_parse id fd b nr pos
        else begin
          S.disconnection_handler id;
          Lwt.return ()
        end)

  and iter_parse id fd b nr pos =
    (* Printf.eprintf "\titer_parse %d %d\n%!" nr pos; *)
    let pos = pos + nr in
    if pos > 8 then
      let msg_len = Int32.to_int
        (EndianString.LittleEndian.get_int32 b 0) in
      (* Printf.eprintf "\tmsg_len=%d\n" msg_len; *)
      if msg_len + 8 > pos then
        iter_read id fd b pos
      else
        let msg_id = Int32.to_int
          (EndianString.LittleEndian.get_int32 b 4) in
        let msg = Bytes.sub b 8 msg_len in
        S.message_handler id fd msg_id msg;
        let nr = pos - (msg_len+8) in
        if nr > 0 then begin
          Bytes.blit b (msg_len+8) b 0 nr;
          iter_parse id fd b nr 0
        end else
        iter_read id fd b 0
    else
      iter_read id fd b pos

  let create_server ~loopback ~port =
    let counter = ref 0 in
    let sock = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    let sockaddr = Unix.ADDR_INET(
      (if loopback then
          Unix.inet_addr_of_string "127.0.0.1"
       else
          Unix.inet_addr_any),
      port) in
    Lwt_unix.set_close_on_exec sock;
    Lwt_unix.setsockopt sock Unix.SO_REUSEADDR true;
    Lwt_unix.bind sock sockaddr;
    Lwt_unix.listen sock 20;

    let rec iter_accept () =
      (* Printf.eprintf "\titer_accept...\n%!"; *)
      Lwt.bind (Lwt_unix.accept sock)
        (fun (fd, sock_addr) ->
          (* Printf.eprintf "\tServer received connection...\n%!"; *)
          incr counter;
          let id = !counter in
          let b = Bytes.create 65636 in
          S.connection_handler id fd sock_addr;
          Lwt.async iter_accept;
          iter_read id fd b 0
        )

    in
    let port = match Unix.getsockname (Lwt_unix.unix_file_descr sock) with
        Unix.ADDR_INET(_, port) -> port
      | _ -> assert false in
    Lwt.async iter_accept;
    port

  let connect conn_id sockaddr =
    let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    Lwt.async (fun () ->
      Lwt.bind (Lwt_unix.connect fd sockaddr)
        (fun () ->
          S.connection_handler conn_id fd sockaddr;
          let b = Bytes.create 65636 in
          iter_read conn_id fd b 0))


end : sig

  val create_server : loopback:bool -> port:int -> int
  val connect : int -> Lwt_unix.sockaddr -> unit

end)

let system cmd cont =
  Lwt.async (fun () ->
    Lwt.bind (Lwt_process.exec (Lwt_process.shell cmd))
      (fun s -> cont s; Lwt.return ()))

let exec cmd args cont =
  Lwt.async (fun () ->
    Lwt.bind (Lwt_process.exec (cmd, args))
      (fun s -> cont s; Lwt.return ()))
