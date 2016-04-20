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

let debug = false

type 'info connection = {
  info : 'info;
  fd : Lwt_unix.file_descr;
  mutable writer: unit Lwt.t;
}

let info con = con.info

(* TODO: use let (t,u) = Lwt.wait() in Lwt.run t; ... Lwt.wakeup u *)
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

let rec iter_write fd s pos len =
  if debug then Printf.eprintf "iter_write...\n%!";
  Lwt.bind (Lwt_unix.write fd s pos len)
    (fun nw ->
      if debug then Printf.eprintf "written %d\n%!" nw;
      if nw > 0 then
        let len = len - nw in
        if len > 0 then
          iter_write fd s (pos+nw) len
        else
          Lwt.return ()
      else Lwt.return ()
    )

let send_message con msg =
  if debug then Printf.eprintf "send_message...\n%!";
  let msg_len = String.length msg in
  let total_msg_len = 4+msg_len in
  let b = Bytes.create total_msg_len in
  EndianString.LittleEndian.set_int32 b 0 (Int32.of_int msg_len);
  Bytes.blit msg 0 b 4 msg_len;
  con.writer <-
    (Lwt.bind con.writer (fun () ->
      iter_write con.fd b 0 total_msg_len));
  Lwt.async (fun () -> con.writer)

module MakeSocket(S : sig

  type server_info
  type info

  val connection_info : server_info -> Unix.sockaddr -> info

  val connection_handler : info connection -> unit
  val message_handler : info connection -> string -> unit
  val disconnection_handler : info -> unit

end) = (struct

  let rec iter_read con b pos =
    (* Printf.eprintf "\titer_read %d...\n%!" pos; *)
    Lwt.bind (Lwt_unix.read con.fd b pos (Bytes.length b - pos))
      (fun nr ->
        (* Printf.eprintf "\titer_read %d/%d...\n%!" nr pos; *)
        if nr > 0 then
          iter_parse con b nr pos
        else begin
          S.disconnection_handler con.info;
          Lwt.return ()
        end)

  and iter_parse con b nr pos =
    (* Printf.eprintf "\titer_parse %d %d\n%!" nr pos; *)
    let pos = pos + nr in
    if pos > 4 then
      let msg_len = Int32.to_int
        (EndianString.LittleEndian.get_int32 b 0) in
      (* Printf.eprintf "\tmsg_len=%d\n" msg_len; *)
      let total_msg_len = msg_len + 4 in
      if total_msg_len > pos then
        iter_read con b pos
      else
        let msg = Bytes.sub b 4 msg_len in
        S.message_handler con msg;
        let nr = pos - total_msg_len in
        if nr > 0 then begin
          Bytes.blit b total_msg_len b 0 nr;
          iter_parse con b nr 0
        end else
        iter_read con b 0
    else
      iter_read con b pos

  let create ~loopback ?(port=0) context =
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
          let b = Bytes.create 65636 in
          let writer = Lwt.return () in
          let info = S.connection_info context sock_addr in
          let con = { info; fd; writer } in
          Lwt.async (fun () -> con.writer);
          S.connection_handler con;
          Lwt.async iter_accept;
          iter_read con b 0
        )

    in
    let port = match Unix.getsockname (Lwt_unix.unix_file_descr sock) with
        Unix.ADDR_INET(_, port) -> port
      | _ -> assert false in
    Lwt.async iter_accept;
    port

  let connect info sockaddr =
    let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    let writer = Lwt.return () in
    let con = { info; fd; writer } in
    con.writer <-
      (Lwt.bind (Lwt_unix.connect fd sockaddr)
         (fun () ->
           if debug then Printf.eprintf "Connected\n%!";
           S.connection_handler con;
           let b = Bytes.create 65636 in
           Lwt.async (fun () -> iter_read con b 0);
           Lwt.return ()
         ));
    con


end : sig

  val create : loopback:bool -> ?port:int -> S.server_info -> int
  val connect : S.info -> Lwt_unix.sockaddr -> S.info connection

end)


(* create sockets as server *)
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

end) = MakeSocket(S)

(* create sockets as client *)
module MakeClient(S : sig

  type info

  (* [connection_handler sock ] *)
  val connection_handler : info connection -> unit

  (* [message_handler conn_id sock msg_id msg_content] *)
  val message_handler : info connection -> string -> unit

  (* [disconnection_handler conn_id] *)
  val disconnection_handler : info -> unit

end) = MakeSocket(struct
  type server_info = S.info
  include S
  let connection_info _sockaddr = assert false
end
)



let system cmd cont =
  Lwt.async (fun () ->
    Lwt.bind (Lwt_process.exec (Lwt_process.shell cmd))
      (fun s -> cont s; Lwt.return ()))

let exec cmd args ?stdin ?stdout  ?stderr cont =
  let stdin = match stdin with
    | None -> None
    | Some filename ->
      let fd = Unix.openfile filename [Unix.O_RDONLY] 0o644 in
      Some (`FD_move fd)
  in
  let stdout = match stdout with
    | None -> None
    | Some filename ->
      let fd = Unix.openfile filename
        [Unix.O_TRUNC; Unix.O_CREAT; Unix.O_WRONLY] 0o644 in
      Some (`FD_move fd)
  in
  let stderr = match stderr with
    | None -> None
    | Some filename ->
      let fd = Unix.openfile filename
        [Unix.O_TRUNC; Unix.O_CREAT; Unix.O_WRONLY] 0o644 in
      Some (`FD_move fd)
  in
  Lwt.async (fun () ->
    Lwt.bind (
      Lwt.catch
        (fun () -> Lwt_process.exec ?stdin ?stdout ?stderr (cmd, args))
        (fun exn -> Lwt.return (Unix.WEXITED 99))
    )
      (fun s -> cont s; Lwt.return ()))
