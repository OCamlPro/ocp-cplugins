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

open MonitorProtocol

(* wait for (1) the program to terminate + (2) each connection to close *)
let wait = ref 1

let only_commands = ref true
let log = ref stderr
let close_log_on_exit = ref true

let should_exit () =
  decr wait;
  if !wait = 0 then begin
    if !close_log_on_exit then close_out !log;
    LwtWrapper.exit ()
  end

module Server = LwtWrapper.MakeServer(struct

  type server_info = unit
  type info = { mutable pid : int;
                mutable synchronous_mode: bool }

  let connection_info server_info sockaddr =
    { pid = 0;
      synchronous_mode = false;
    }

  let connection_handler con =
    incr wait;
  (* Printf.eprintf "\tConnected\n%!"; *)
    ()

  let message_handler con msg =
    let info = LwtWrapper.info con in
    try
      (*      Printf.eprintf "\tMessage received %d %d\n%!"
              msg_id (String.length msg); *)
      let msg = MonitorProtocol.C2S.parse_msg msg in

      begin
        match msg with
        | C2S.MSG_INIT t ->
          info.pid <- t.C2S.MSG_INIT.pid;
          info.synchronous_mode <- t.C2S.MSG_INIT.synchronous_mode <> 0;
        | _ -> ()
      end;

      if info.synchronous_mode then
        LwtWrapper.send_message con (
          MonitorProtocol.S2C.marshal S2C.MSG_ACK);

      begin
        if !only_commands then
          match msg with
          | C2S.MSG_INIT t ->
            Printf.fprintf !log "-- in %s --\n%!" t.C2S.MSG_INIT.curdir;
            Printf.fprintf !log "%s\n%!" (String.concat " " t.C2S.MSG_INIT.args)
          | _ -> ()
        else
          Printf.fprintf !log "%d: %s\n%!" info.pid
            (MonitorProtocol.C2S.msg_to_string msg)
      end;
    with exn ->
      Printf.eprintf "message_handler: exception %s\n%!"
        (Printexc.to_string exn)

  let disconnection_handler conn_id =
    (*    Printf.eprintf "\tDisconnected\n%!"; *)
    should_exit ()

end)

let main args =
  let loopback = true in
  let port = Server.create ~loopback () in

  Unix.putenv "OCP_WATCHER_PORT" ((string_of_int port) ^ "s");

  LwtWrapper.exec args.(0)  args
    (function
    | Unix.WEXITED n->
      should_exit ()
    | _ ->
      should_exit ()

  );
  LwtWrapper.main ()

let args = ref []

let arg_anon s = args := s :: !args
let arg_list = Arg.align [
  "-o", Arg.String (fun filename ->
    let oc = open_out filename in
    log := oc;
    close_log_on_exit := true
  ), "FILE Store results in FILE";
  "--all", Arg.Clear only_commands, " Print all messages";
  "--", Arg.Rest arg_anon, "COMMAND Command to call";
]
let arg_usage = String.concat "\n"
  [ "ocp-show-build [OPTIONS] COMMAND";
      "";
    "ocp-show-build can be used to display the OCaml commands called during";
    "a build. The OCaml runtime must support use of CAML_CPLUGINS, and";
    "especially the central_monitor.so plugin must be in use.";
    "";
    "Available options:";
  ]
let  () =
  begin
    try ignore (Sys.getenv "CAML_CPLUGINS") with
      Not_found ->
        let dirname = Filename.dirname Sys.executable_name in
        let plugin = Filename.concat dirname "central_monitor.so" in
        if Sys.file_exists plugin then
          Unix.putenv "CAML_CPLUGINS" plugin
        else begin

          Printf.eprintf "Error: CAML_CPLUGINS should be set with the absolute path to central_monitor.so\n%!";
          exit 2
        end
  end;
  Arg.parse arg_list arg_anon arg_usage;
  match !args with
  | [] ->
    Printf.eprintf "Error: you must specify a command to call\n\n%!";
    Arg.usage arg_list arg_usage;
    exit 2
  | args ->
    main (Array.of_list(List.rev args))
